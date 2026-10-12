-- ASTRAL Neon Factory v1 planner.
-- Read-only production intelligence: groups inventory by species/variant,
-- identifies fusions that are ready now, ranks the closest next Neon/Mega,
-- and stores per-species production targets. Fusion execution comes later.
return function(ASTRAL)
    local Pets = assert(ASTRAL.Pets, "PetAPI must load before Neon Factory")
    local env = (getgenv and getgenv()) or _G
    env.ASTRALNeonTargets = env.ASTRALNeonTargets or {}

    local Factory = {
        Id = "neon_factory",
        Name = "Neon Factory",
        Page = "Neon Factory",
        Description = "Plan Normal -> Neon -> Mega production and fuse selected ready targets.",
        Version = "0.3.0-dev.6.10.2-target-progression",
        Implemented = true,
        Enabled = false,
        Busy = false,
        Species = {},
        Ready = {},
        ClosestNeon = {},
        ClosestMega = {},
        Targets = env.ASTRALNeonTargets,
        LastScan = 0,
        ScanInterval = 8,
        LastMessage = "Planner ready",
        FusionCount = 0,
        LastFusion = nil,
        ActionCooldown = 4,
    }

    local function log(message)
        print("[ASTRAL NEON] " .. tostring(message))
        if ASTRAL.State then
            pcall(function() ASTRAL.State:Log("Neon Factory: " .. tostring(message)) end)
        end
    end

    local function copyEntry(entry)
        if not entry then return nil end
        return {
            kind = entry.kind,
            name = entry.name,
            normal = entry.normal,
            normalFullGrown = entry.normalFullGrown,
            neon = entry.neon,
            neonFullGrown = entry.neonFullGrown,
            mega = entry.mega,
            readyNeons = entry.readyNeons,
            readyMegas = entry.readyMegas,
            potentialNeons = entry.potentialNeons,
            potentialMegas = entry.potentialMegas,
            neonMissingPets = entry.neonMissingPets,
            megaMissingNeons = entry.megaMissingNeons,
            neonRemainingXP = entry.neonRemainingXP,
            megaRemainingXP = entry.megaRemainingXP,
            makeNeon = entry.makeNeon == true,
            makeMega = entry.makeMega == true,
        }
    end

    local function sumBestRemaining(list, count)
        local values = {}
        for _, value in ipairs(list or {}) do
            if value ~= nil then table.insert(values, math.max(0, tonumber(value) or 0)) end
        end
        table.sort(values)
        local total = 0
        for i = 1, math.min(count, #values) do total += values[i] end
        return total
    end

    function Factory:Snapshot()
        if self.Busy then return false end
        self.Busy = true

        local groups = {}
        local ok, err = pcall(function()
            for _, pet in ipairs(Pets:GetPets()) do
                if not pet.isEgg and pet.kind then
                    local group = groups[pet.kind]
                    if not group then
                        group = {
                            kind = pet.kind,
                            name = pet.name or pet.kind,
                            normal = 0,
                            normalFullGrown = 0,
                            neon = 0,
                            neonFullGrown = 0,
                            mega = 0,
                            normalRemaining = {},
                            neonRemaining = {},
                        }
                        groups[pet.kind] = group
                    end

                    if pet.isMega then
                        group.mega += 1
                    elseif pet.isNeon then
                        group.neon += 1
                        if pet.isFullGrown then group.neonFullGrown += 1 end
                        table.insert(group.neonRemaining, Pets:GetRemainingGrowthXP(pet) or 0)
                    else
                        group.normal += 1
                        if pet.isFullGrown then group.normalFullGrown += 1 end
                        table.insert(group.normalRemaining, Pets:GetRemainingGrowthXP(pet) or 0)
                    end
                end
            end
        end)

        if not ok then
            self.Busy = false
            self.LastMessage = "Scan failed: " .. tostring(err)
            warn("[ASTRAL NEON] " .. self.LastMessage)
            return false, err
        end

        local species = {}
        for kind, group in pairs(groups) do
            local targets = self.Targets[kind] or {}
            group.readyNeons = math.floor(group.normalFullGrown / 4)
            group.readyMegas = math.floor(group.neonFullGrown / 4)
            group.potentialNeons = math.floor(group.normal / 4)
            group.potentialMegas = math.floor((group.neon + group.potentialNeons) / 4)
            group.neonMissingPets = math.max(0, 4 - group.normal)
            group.megaMissingNeons = math.max(0, 4 - group.neon)
            group.neonRemainingXP = sumBestRemaining(group.normalRemaining, 4)
            group.megaRemainingXP = sumBestRemaining(group.neonRemaining, 4)
            group.makeNeon = targets.neon == true
            group.makeMega = targets.mega == true
            group.normalRemaining = nil
            group.neonRemaining = nil
            table.insert(species, group)
        end

        table.sort(species, function(a, b)
            if a.name == b.name then return tostring(a.kind) < tostring(b.kind) end
            return tostring(a.name) < tostring(b.name)
        end)

        local ready = {}
        for _, entry in ipairs(species) do
            if entry.readyNeons > 0 or entry.readyMegas > 0 then
                table.insert(ready, copyEntry(entry))
            end
        end
        table.sort(ready, function(a, b)
            local aMega, bMega = a.readyMegas > 0, b.readyMegas > 0
            if aMega ~= bMega then return aMega end
            local aReady = a.readyMegas * 100 + a.readyNeons
            local bReady = b.readyMegas * 100 + b.readyNeons
            if aReady ~= bReady then return aReady > bReady end
            return tostring(a.name) < tostring(b.name)
        end)

        local closestNeon, closestMega = {}, {}
        for _, entry in ipairs(species) do
            if entry.readyNeons == 0 and entry.normal > 0 then
                table.insert(closestNeon, copyEntry(entry))
            end
            if entry.readyMegas == 0 and (entry.neon > 0 or entry.normal >= 4) then
                table.insert(closestMega, copyEntry(entry))
            end
        end

        table.sort(closestNeon, function(a, b)
            local ac, bc = math.min(a.normal, 4), math.min(b.normal, 4)
            if ac ~= bc then return ac > bc end
            if a.normalFullGrown ~= b.normalFullGrown then
                return a.normalFullGrown > b.normalFullGrown
            end
            if a.neonRemainingXP ~= b.neonRemainingXP then
                return a.neonRemainingXP < b.neonRemainingXP
            end
            return tostring(a.name) < tostring(b.name)
        end)

        table.sort(closestMega, function(a, b)
            local ac, bc = math.min(a.neon, 4), math.min(b.neon, 4)
            if ac ~= bc then return ac > bc end
            if a.neonFullGrown ~= b.neonFullGrown then
                return a.neonFullGrown > b.neonFullGrown
            end
            if a.potentialMegas ~= b.potentialMegas then
                return a.potentialMegas > b.potentialMegas
            end
            if a.megaRemainingXP ~= b.megaRemainingXP then
                return a.megaRemainingXP < b.megaRemainingXP
            end
            return tostring(a.name) < tostring(b.name)
        end)

        self.Species = species
        self.Ready = ready
        self.ClosestNeon = closestNeon
        self.ClosestMega = closestMega
        self.LastScan = os.clock()
        self.LastMessage = string.format(
            "%d species | %d ready to fuse",
            #species, #ready
        )
        self.Busy = false
        return true
    end

    function Factory:SetTarget(kind, targetType, enabled)
        if not kind then return false, "Species kind missing" end
        if targetType ~= "neon" and targetType ~= "mega" then
            return false, "Target must be neon or mega"
        end
        self.Targets[kind] = self.Targets[kind] or {}
        self.Targets[kind][targetType] = enabled == true
        env.ASTRALNeonTargets = self.Targets

        -- Mega implies we are willing to create the intermediate Neons.
        if targetType == "mega" and enabled == true then
            self.Targets[kind].neon = true
        end
        -- Turning Neon off also turns Mega off because Mega requires Neon work.
        if targetType == "neon" and enabled ~= true then
            self.Targets[kind].mega = false
        end

        for _, collection in ipairs({self.Species, self.Ready, self.ClosestNeon, self.ClosestMega}) do
            for _, entry in ipairs(collection) do
                if entry.kind == kind then
                    entry.makeNeon = self.Targets[kind].neon == true
                    entry.makeMega = self.Targets[kind].mega == true
                end
            end
        end

        log(string.format(
            "%s target %s = %s",
            tostring(kind), string.upper(targetType), enabled == true and "ON" or "OFF"
        ))
        return true
    end

    function Factory:GetTarget(kind)
        local target = self.Targets[kind] or {}
        return { neon = target.neon == true, mega = target.mega == true }
    end

    local function copyList(source)
        local result = {}
        for i, entry in ipairs(source or {}) do result[i] = copyEntry(entry) end
        return result
    end

    function Factory:GetSpecies() return copyList(self.Species) end
    function Factory:GetReady() return copyList(self.Ready) end
    function Factory:GetClosestNeon() return copyList(self.ClosestNeon) end
    function Factory:GetClosestMega() return copyList(self.ClosestMega) end

    function Factory:GetStatus()
        local neonTargets, megaTargets = 0, 0
        for _, target in pairs(self.Targets) do
            if target.neon then neonTargets += 1 end
            if target.mega then megaTargets += 1 end
        end
        return {
            enabled = self.Enabled,
            implemented = true,
            busy = self.Busy,
            message = self.LastMessage,
            species = #self.Species,
            ready = #self.Ready,
            neonTargets = neonTargets,
            megaTargets = megaTargets,
            fusionCount = self.FusionCount,
            lastFusion = self.LastFusion and {
                kind = self.LastFusion.kind,
                name = self.LastFusion.name,
                result = self.LastFusion.result,
                at = self.LastFusion.at,
            } or nil,
        }
    end

    local function speciesByKind()
        local result = {}
        for _, entry in ipairs(Factory.Species or {}) do
            result[entry.kind] = entry
        end
        return result
    end

    -- Lower values are higher priority. This is intentionally exposed to the
    -- Pet Queue/Pet Pens workers so selected Neon Factory targets drive actual
    -- progression rather than only fusion.
    function Factory:GetGrowthPriority(pet)
        if not self.Enabled or type(pet) ~= "table" or pet.isEgg or pet.isMega then
            return nil
        end

        local target = self.Targets[pet.kind]
        if not target or (not target.neon and not target.mega) then return nil end

        local groups = speciesByKind()
        local group = groups[pet.kind] or {}
        local remaining = Pets:GetRemainingGrowthXP(pet) or 0

        if target.mega and pet.isNeon then
            -- Existing Neons are the shortest path to a requested Mega.
            return 0, tonumber(group.megaRemainingXP) or 0, remaining
        end

        if not pet.isNeon and (target.neon or target.mega) then
            -- Normals create requested Neons, including intermediate Neons for
            -- a Mega target. Prefer species closest to a completed set.
            local missing = math.max(0, 4 - math.min(tonumber(group.normal) or 0, 4))
            local work = tonumber(group.neonRemainingXP) or 0
            return target.mega and 1 or 2, missing, work, remaining
        end

        return nil
    end

    function Factory:PrioritizeGrowthCandidates(candidates)
        local result = {}
        for i, pet in ipairs(candidates or {}) do result[i] = pet end
        if not self.Enabled then return result end

        table.sort(result, function(a, b)
            local ap1, ap2, ap3, ap4 = self:GetGrowthPriority(a)
            local bp1, bp2, bp3, bp4 = self:GetGrowthPriority(b)
            local aTarget, bTarget = ap1 ~= nil, bp1 ~= nil
            if aTarget ~= bTarget then return aTarget end
            if aTarget then
                if ap1 ~= bp1 then return ap1 < bp1 end
                if (ap2 or 0) ~= (bp2 or 0) then return (ap2 or 0) < (bp2 or 0) end
                if (ap3 or 0) ~= (bp3 or 0) then return (ap3 or 0) < (bp3 or 0) end
                if (ap4 or 0) ~= (bp4 or 0) then return (ap4 or 0) < (bp4 or 0) end
            end

            -- Preserve the established normal -> Neon -> Mega fallback order
            -- for pets outside the selected production targets.
            local av = a.isMega and 2 or (a.isNeon and 1 or 0)
            local bv = b.isMega and 2 or (b.isNeon and 1 or 0)
            if av ~= bv then return av < bv end
            if (a.age or 0) ~= (b.age or 0) then return (a.age or 0) > (b.age or 0) end
            if (a.xp or 0) ~= (b.xp or 0) then return (a.xp or 0) > (b.xp or 0) end
            return tostring(a.unique) < tostring(b.unique)
        end)

        return result
    end

    local function actionBlocked()
        local queue = ASTRAL.Modules:Get("pet_queue")
        local pens = ASTRAL.Modules:Get("pet_pens")
        local eggs = ASTRAL.Modules:Get("eggs")
        local farm = ASTRAL.Modules:Get("pet_farm")

        if queue and queue.Busy then return true, "Pet Queue busy" end
        if pens and pens.Busy then return true, "Pet Pens busy" end
        if eggs and eggs.Busy then return true, "Egg Manager busy" end
        if farm and farm.Busy then return true, "Autofarm busy" end
        return false
    end

    local function fusionCandidates(kind, neon)
        local candidates = {}
        for _, pet in ipairs(Pets:GetPets()) do
            if pet.kind == kind
                and not pet.isEgg
                and pet.isFullGrown
                and not pet.isMega
                and ((neon and pet.isNeon) or (not neon and not pet.isNeon)) then
                table.insert(candidates, pet)
            end
        end

        -- Deterministic choice. Prefer unmodified pets first so valuable
        -- Fly/Ride variants are not consumed unless they are required.
        table.sort(candidates, function(a, b)
            local ap = (a.item and a.item.properties) or {}
            local bp = (b.item and b.item.properties) or {}
            local aSpecial = (ap.flyable or ap.is_flyable or ap.rideable or ap.is_rideable) and 1 or 0
            local bSpecial = (bp.flyable or bp.is_flyable or bp.rideable or bp.is_rideable) and 1 or 0
            if aSpecial ~= bSpecial then return aSpecial < bSpecial end
            return tostring(a.unique) < tostring(b.unique)
        end)

        if #candidates < 4 then return nil end
        return {candidates[1], candidates[2], candidates[3], candidates[4]}
    end

    function Factory:Fuse(kind, toMega)
        if self.Busy then return false, "Neon Factory busy" end
        local blocked, reason = actionBlocked()
        if blocked then return false, reason end

        local target = self.Targets[kind] or {}
        if toMega and not target.mega then return false, "Mega target is off" end
        if not toMega and not target.neon then return false, "Neon target is off" end

        local candidates = fusionCandidates(kind, toMega == true)
        if not candidates then
            return false, toMega and "Need four Luminous Neons" or "Need four Full Grown normals"
        end

        local remote = ASTRAL.Game:GetRemote("PetAPI/DoNeonFusion")
        if not remote then return false, "PetAPI/DoNeonFusion unavailable" end

        self.Busy = true
        local name = candidates[1].name or kind
        local before = {}
        for _, pet in ipairs(candidates) do before[pet.unique] = true end

        self.LastMessage = string.format(
            "Fusing %s -> %s...",
            tostring(name),
            toMega and "Mega" or "Neon"
        )
        log(self.LastMessage)

        local ok, err = pcall(function()
            remote:InvokeServer({
                candidates[1].unique,
                candidates[2].unique,
                candidates[3].unique,
                candidates[4].unique,
            })
        end)
        if not ok then
            self.Busy = false
            self.LastMessage = "Fusion remote failed: " .. tostring(err)
            warn("[ASTRAL NEON] " .. self.LastMessage)
            return false, err
        end

        -- D&S 4.1.3 waits four seconds after DoNeonFusion. We additionally
        -- verify inventory state before recording success.
        local deadline = os.clock() + 6
        local verified = false
        while os.clock() < deadline do
            task.wait(0.35)
            local consumed = 0
            local produced = false
            for _, pet in ipairs(Pets:GetPets()) do
                if before[pet.unique] then consumed += 1 end
                if pet.kind == kind then
                    if toMega and pet.isMega then produced = true end
                    if not toMega and pet.isNeon and not pet.isMega then produced = true end
                end
            end
            if consumed < 4 and produced then
                verified = true
                break
            end
        end

        self.Busy = false
        self.LastScan = 0
        self:Snapshot()

        if not verified then
            self.LastMessage = string.format(
                "%s fusion sent; inventory transition not confirmed",
                toMega and "Mega" or "Neon"
            )
            warn("[ASTRAL NEON] " .. self.LastMessage)
            return false, self.LastMessage
        end

        self.FusionCount += 1
        self.LastFusion = {
            kind = kind,
            name = name,
            result = toMega and "MEGA" or "NEON",
            at = os.time(),
        }
        self.LastMessage = string.format(
            "Created %s %s | session fusions %d",
            toMega and "Mega" or "Neon",
            tostring(name),
            self.FusionCount
        )
        log(self.LastMessage)
        return true
    end

    function Factory:RunOneFusion()
        if not self.Enabled or self.Busy then return false end
        local blocked = actionBlocked()
        if blocked then return false end

        -- Finish Mega-ready targets first, then create requested Neons.
        for _, entry in ipairs(self.Ready) do
            local target = self.Targets[entry.kind] or {}
            if target.mega and (entry.readyMegas or 0) > 0 then
                return self:Fuse(entry.kind, true)
            end
        end
        for _, entry in ipairs(self.Ready) do
            local target = self.Targets[entry.kind] or {}
            if target.neon and (entry.readyNeons or 0) > 0 then
                return self:Fuse(entry.kind, false)
            end
        end
        return false
    end

    function Factory:SetEnabled(enabled)
        self.Enabled = enabled == true
        self.LastMessage = self.Enabled
            and "Factory armed; selected ready targets will fuse automatically"
            or "Planner active; automatic fusion off"
        log(self.LastMessage)
        return true
    end

    -- Planner scanning stays active even when factory automation is OFF so the
    -- Neon Factory page is always useful. Only cached plain Lua reaches the UI.
    task.spawn(function()
        while not ASTRAL.Runtime.Destroyed do
            if not Factory.Busy
                and (Factory.LastScan == 0
                    or os.clock() - Factory.LastScan >= Factory.ScanInterval) then
                Factory:Snapshot()
            end
            if Factory.Enabled and not Factory.Busy then
                local acted = Factory:RunOneFusion()
                if acted then task.wait(Factory.ActionCooldown) end
            end
            task.wait(1)
        end
    end)

    ASTRAL.Modules:Register(Factory)
    return Factory
end
