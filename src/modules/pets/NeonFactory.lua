-- ASTRAL Neon Factory v1 planner.
-- Read-only production intelligence: groups inventory by species/variant,
-- identifies fusions that are ready now, ranks the closest next Neon/Mega,
-- and stores per-species production targets. Fusion execution comes later.
return function(ASTRAL)
    local Pets = assert(ASTRAL.Pets, "PetAPI must load before Neon Factory")

    local Factory = {
        Id = "neon_factory",
        Name = "Neon Factory",
        Page = "Neon Factory",
        Description = "See ready/closest Neon and Mega pets and choose production targets.",
        Version = "0.1.0-dev.6.10-planner",
        Implemented = true,
        Enabled = false,
        Busy = false,
        Species = {},
        Ready = {},
        ClosestNeon = {},
        ClosestMega = {},
        Targets = {},
        LastScan = 0,
        ScanInterval = 8,
        LastMessage = "Planner ready",
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
        }
    end

    function Factory:SetEnabled(enabled)
        self.Enabled = enabled == true
        self.LastMessage = self.Enabled
            and "Targets armed; automatic fusion not enabled in planner v1"
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
            task.wait(1)
        end
    end)

    ASTRAL.Modules:Register(Factory)
    return Factory
end
