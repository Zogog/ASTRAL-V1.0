-- ASTRAL dev.6.9 Egg Manager v1.
-- Single active-slot Hatch All manager. The normal ailment Autofarm remains
-- shared; Egg Manager and Pet Queue are mutually exclusive owners of the
-- equipped pet/egg slot.
return function(ASTRAL)
    local Pets = assert(ASTRAL.Pets, "PetAPI must load before Egg Manager")

    local Eggs = {
        Id = "eggs",
        Name = "Egg Manager",
        Page = "Eggs",
        Description = "Hatch owned eggs automatically using the shared ailment Autofarm.",
        Version = "0.1.0-dev.6.9-hatch-all",
        Implemented = true,
        Enabled = false,
        Busy = false,
        Mode = "hatch_all",
        LastSwitch = 0,
        SwitchCooldown = 3,
        ActiveUnique = nil,
        ActiveEggKind = nil,
        ActiveEggName = nil,
        Current = nil,
        EggList = {},
        EggKinds = {},
        TotalEggs = 0,
        SessionHatched = 0,
        SessionByKind = {},
        History = {},
        LastMessage = "Off",
    }

    local function log(message)
        print("[ASTRAL EGGS] " .. tostring(message))
        if ASTRAL.State then
            pcall(function() ASTRAL.State:Log("Egg Manager: " .. tostring(message)) end)
        end
    end

    local function copyEgg(egg)
        if not egg then return nil end
        return {
            unique = egg.unique,
            kind = egg.kind,
            name = egg.name,
            xp = egg.xp,
            targetXP = egg.targetXP,
        }
    end

    local function copyList(source)
        local out = {}
        for i, value in ipairs(source or {}) do
            out[i] = copyEgg(value)
        end
        return out
    end

    function Eggs:Snapshot()
        local penAssigned = Pets:GetPenAssigned()
        local list = {}
        local kinds = {}

        for _, pet in ipairs(Pets:GetPets()) do
            if pet.unique and pet.isEgg and not penAssigned[pet.unique] then
                local egg = {
                    unique = pet.unique,
                    kind = pet.kind,
                    name = pet.name,
                    xp = tonumber(pet.xp) or 0,
                    targetXP = tonumber(pet.targetXP),
                }
                table.insert(list, egg)

                local key = tostring(pet.kind or pet.name or "Unknown Egg")
                local entry = kinds[key]
                if not entry then
                    entry = {
                        kind = pet.kind,
                        name = pet.name,
                        count = 0,
                    }
                    kinds[key] = entry
                end
                entry.count += 1
            end
        end

        table.sort(list, function(a, b)
            local an = tostring(a.name or a.kind or "")
            local bn = tostring(b.name or b.kind or "")
            if an ~= bn then return an < bn end
            return tostring(a.unique) < tostring(b.unique)
        end)

        local kindList = {}
        for _, entry in pairs(kinds) do table.insert(kindList, entry) end
        table.sort(kindList, function(a, b)
            return tostring(a.name or a.kind or "") < tostring(b.name or b.kind or "")
        end)

        self.EggList = list
        self.EggKinds = kindList
        self.TotalEggs = #list

        local current = Pets:GetCurrent()
        self.Current = current and current.isEgg and {
            unique = current.unique,
            kind = current.kind,
            name = current.name,
            xp = tonumber(current.xp) or 0,
            targetXP = tonumber(current.targetXP),
        } or nil

        return self.Current, list
    end

    function Eggs:GetEggs()
        return copyList(self.EggList)
    end

    function Eggs:GetEggKinds()
        local out = {}
        for i, entry in ipairs(self.EggKinds or {}) do
            out[i] = {
                kind = entry.kind,
                name = entry.name,
                count = entry.count,
            }
        end
        return out
    end

    function Eggs:GetHistory()
        local out = {}
        for i, entry in ipairs(self.History or {}) do
            out[i] = {
                eggKind = entry.eggKind,
                eggName = entry.eggName,
                petKind = entry.petKind,
                petName = entry.petName,
            }
        end
        return out
    end

    function Eggs:GetStatus()
        local current = self.Current
        local progress
        if current and current.targetXP and current.targetXP > 0 then
            progress = math.clamp((current.xp or 0) / current.targetXP * 100, 0, 100)
        end

        return {
            enabled = self.Enabled,
            implemented = true,
            busy = self.Busy,
            message = self.LastMessage,
            mode = self.Mode,
            current = copyEgg(current),
            progress = progress,
            totalEggs = self.TotalEggs,
            sessionHatched = self.SessionHatched,
        }
    end

    function Eggs:SetEnabled(enabled, reason)
        enabled = enabled == true
        if self.Enabled == enabled then return true end

        self.Enabled = enabled
        if enabled then
            -- Egg hatching owns the active slot. Pet Queue must never compete
            -- for it. The ailment Autofarm is deliberately NOT disabled: it is
            -- the shared engine that actually completes the egg's needs.
            local queue = ASTRAL.Modules:Get("pet_queue")
            if queue and queue.Enabled then
                queue:SetEnabled(false, "Egg Manager took active slot ownership")
            end

            self.LastMessage = "Scanning egg inventory"
            log("enabled; Pet Queue disabled for egg-slot ownership")
        else
            self.LastMessage = reason and ("Off - " .. tostring(reason)) or "Off"
            self.ActiveUnique = nil
            self.ActiveEggKind = nil
            self.ActiveEggName = nil
            log(reason and ("disabled - " .. tostring(reason)) or "disabled")
        end
        return true
    end

    function Eggs:RecordHatch(item)
        local pet = item and Pets:Describe(item) or nil
        local petName = pet and pet.name or (item and item.kind) or "Unknown Pet"
        local petKind = pet and pet.kind or (item and item.kind) or nil
        local eggKind = self.ActiveEggKind
        local eggName = self.ActiveEggName or eggKind or "Egg"

        self.SessionHatched += 1
        if eggKind then
            self.SessionByKind[eggKind] = (self.SessionByKind[eggKind] or 0) + 1
        end

        table.insert(self.History, 1, {
            eggKind = eggKind,
            eggName = eggName,
            petKind = petKind,
            petName = petName,
        })
        while #self.History > 8 do table.remove(self.History) end

        log(string.format(
            "hatched %s -> %s | session %d",
            tostring(eggName),
            tostring(petName),
            self.SessionHatched
        ))

        self.ActiveUnique = nil
        self.ActiveEggKind = nil
        self.ActiveEggName = nil
        self.LastMessage = "Hatched " .. tostring(petName)
    end

    function Eggs:TryAdvance()
        if not self.Enabled or self.Busy then return false end

        -- D&S 4.1.3 observes the same inventory UID changing from an egg
        -- definition into the hatched pet. Use that exact transition rather
        -- than guessing from inventory additions/removals.
        if self.ActiveUnique then
            local item = Pets:GetItem(self.ActiveUnique)
            if item then
                local described = Pets:Describe(item)
                if described and not described.isEgg then
                    self:RecordHatch(item)
                elseif described and described.isEgg then
                    self.Current = {
                        unique = described.unique,
                        kind = described.kind,
                        name = described.name,
                        xp = tonumber(described.xp) or 0,
                        targetXP = tonumber(described.targetXP),
                    }
                    self.LastMessage = "Hatching " .. tostring(described.name)
                    return false
                end
            else
                -- A missing UID can be transient during inventory replication.
                self.LastMessage = "Waiting for hatch inventory update"
                return false
            end
        end

        local farm = ASTRAL.Modules:Get("pet_farm")
        if farm and farm.Busy then
            self.LastMessage = "Waiting for current ailment"
            return false
        end

        local pens = ASTRAL.Modules:Get("pet_pens")
        if pens and pens.Busy then
            self.LastMessage = "Waiting for Pet Pens"
            return false
        end

        if os.clock() - self.LastSwitch < self.SwitchCooldown then return false end

        local current, candidates = self:Snapshot()

        -- If an eligible egg is already equipped when Egg Manager starts,
        -- adopt it instead of unnecessarily unequipping/re-equipping it.
        if current then
            self.ActiveUnique = current.unique
            self.ActiveEggKind = current.kind
            self.ActiveEggName = current.name
            self.LastMessage = "Hatching " .. tostring(current.name)
            log("adopted equipped egg " .. tostring(current.name))
            return false
        end

        local nextEgg = candidates[1]
        if not nextEgg then
            self.Enabled = false
            self.LastMessage = "No eligible owned eggs; stopped"
            log("stopped - no eligible owned eggs")
            return false
        end

        self.Busy = true
        self.LastSwitch = os.clock()
        self.LastMessage = "Equipping " .. tostring(nextEgg.name)
        log(string.format(
            "equipping %s (%s)",
            tostring(nextEgg.name),
            tostring(nextEgg.unique)
        ))

        local ok, reason = Pets:Equip(nextEgg.unique)
        if ok then
            self.ActiveUnique = nextEgg.unique
            self.ActiveEggKind = nextEgg.kind
            self.ActiveEggName = nextEgg.name
            self.Current = copyEgg(nextEgg)
            self.LastMessage = "Hatching " .. tostring(nextEgg.name)
            log("equipped " .. tostring(nextEgg.name))
            task.wait(1)
            self:Snapshot()
        else
            self.LastMessage = "Egg equip failed: " .. tostring(reason)
            warn("[ASTRAL EGGS] " .. self.LastMessage)
        end

        self.Busy = false
        return ok, reason
    end

    task.spawn(function()
        while not ASTRAL.Runtime.Destroyed do
            if Eggs.Enabled then
                local ok, err = pcall(function() Eggs:TryAdvance() end)
                if not ok then
                    Eggs.Busy = false
                    Eggs.LastMessage = "Error: " .. tostring(err)
                    warn("[ASTRAL EGGS] Cycle error:", err)
                end
            end
            task.wait(1)
        end
    end)

    ASTRAL.Modules:Register(Eggs)
    return Eggs
end
