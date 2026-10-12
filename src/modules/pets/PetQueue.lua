-- ASTRAL Pet Queue v2 foundation.
-- Preserve verified dev.6 auto-switch behaviour; add ordered queue snapshots,
-- inventory/progress visibility and manual queue operations without UI coupling.
return function(ASTRAL)
    local Pets = assert(ASTRAL.Pets, "PetAPI must load before Pet Queue")

    local Queue = {
        Id = "pet_queue",
        Name = "Pet Queue",
        Page = "Pets",
        Description = "Grow All or build a manual pet queue; switch after Full Grown.",
        Version = "0.3.0-dev.6.10.2-neon-targets",
        Implemented = true,
        Enabled = false,
        Busy = false,
        LastSwitch = 0,
        SwitchCooldown = 3,
        Current = nil,
        Next = nil,
        Remaining = 0,
        Mode = "grow_all",
        ManualOrder = {},
        QueueList = {},
        EligibleList = {},
        InventoryStats = {},
        LastMessage = "Off",
    }

    local function log(message)
        print("[ASTRAL PET QUEUE] " .. tostring(message))
        if ASTRAL.State then pcall(function() ASTRAL.State:Log("Pet Queue: " .. tostring(message)) end) end
    end

    -- Eligible pets are defined by PetAPI, including its established
    -- exclusions for eggs, Full Grown pets and Pet Pen assignments.
    -- Manual entries are revalidated against inventory every scan.
    function Queue:Snapshot()
        local current = Pets:GetCurrent()
        local eligible = Pets:GetGrowablePets({
            currentUnique = current and current.unique or nil,
        })
        local candidates = eligible

        -- In Grow All, an enabled Neon Factory may promote its selected
        -- species/variant targets ahead of generic progression.
        if self.Mode == "grow_all" then
            local factory = ASTRAL.Modules:Get("neon_factory")
            if factory and factory.Enabled and factory.PrioritizeGrowthCandidates then
                candidates = factory:PrioritizeGrowthCandidates(eligible)
            end
        end

        if self.Mode == "manual" then
            local byUnique = {}
            for _, pet in ipairs(eligible) do
                byUnique[pet.unique] = pet
            end
            candidates = {}
            for _, unique in ipairs(self.ManualOrder) do
                local pet = byUnique[unique]
                if pet then table.insert(candidates, pet) end
            end
        end

        local stats = {
            total = 0,
            growable = 0,
            fullGrown = 0,
            eggs = 0,
            penAssigned = 0,
        }
        local pen = Pets:GetPenAssigned()
        for _, pet in ipairs(Pets:GetPets()) do
            stats.total += 1
            if pet.isEgg then
                stats.eggs += 1
            elseif pet.isFullGrown then
                stats.fullGrown += 1
            elseif pen[pet.unique] then
                stats.penAssigned += 1
            elseif pet.age ~= nil and pet.age < 6 then
                stats.growable += 1
            end
        end

        self.Current = current
        self.EligibleList = eligible
        self.QueueList = candidates
        self.InventoryStats = stats
        self.Next = candidates[1]
        self.Remaining = #candidates
        return current, candidates
    end

    local function copyPetList(source)
        local result = {}
        for i, pet in ipairs(source or {}) do
            result[i] = {
                unique = pet.unique,
                name = pet.name,
                kind = pet.kind,
                age = pet.age,
                xp = pet.xp,
                targetXP = pet.targetXP,
                isNeon = pet.isNeon == true,
                isMega = pet.isMega == true,
                variant = pet.variant or "NORMAL",
            }
        end
        return result
    end

    -- UI-facing getters are cache-only by design. Calling Adopt Me/Fsys
    -- inventory APIs from the GUI refresh thread can alter executor thread
    -- capability and make subsequent Instance access fail.
    function Queue:GetQueue()
        return copyPetList(self.QueueList)
    end

    function Queue:GetEligiblePets()
        return copyPetList(self.EligibleList)
    end

    function Queue:SetMode(mode)
        if mode ~= "grow_all" and mode ~= "manual" then
            return false, "Mode must be grow_all or manual"
        end
        self.Mode = mode
        self:Snapshot()
        self.LastMessage = mode == "manual"
            and "Manual queue selected"
            or "Grow All selected"
        log("mode set to " .. mode)
        return true
    end

    function Queue:AddPet(unique)
        if not unique then return false, "Pet unique missing" end
        for _, queued in ipairs(self.ManualOrder) do
            if queued == unique then return false, "Pet already queued" end
        end
        local current = Pets:GetCurrent()
        local eligible = Pets:GetGrowablePets({
            currentUnique = current and current.unique or nil,
        })
        for _, pet in ipairs(eligible) do
            if pet.unique == unique then
                table.insert(self.ManualOrder, unique)
                self:Snapshot()
                return true
            end
        end
        return false, "Pet is not eligible (equipped, egg, Full Grown or in Pet Pen)"
    end

    function Queue:RemovePet(unique)
        for i, queued in ipairs(self.ManualOrder) do
            if queued == unique then
                table.remove(self.ManualOrder, i)
                self:Snapshot()
                return true
            end
        end
        return false, "Pet is not in the manual queue"
    end

    function Queue:MovePet(unique, direction)
        if direction ~= -1 and direction ~= 1 then
            return false, "Direction must be -1 or 1"
        end
        for i, queued in ipairs(self.ManualOrder) do
            if queued == unique then
                local newIndex = i + direction
                if newIndex < 1 or newIndex > #self.ManualOrder then
                    return false, "Already at queue boundary"
                end
                self.ManualOrder[i], self.ManualOrder[newIndex] =
                    self.ManualOrder[newIndex], self.ManualOrder[i]
                self:Snapshot()
                return true
            end
        end
        return false, "Pet is not in the manual queue"
    end

    function Queue:ClearManual()
        self.ManualOrder = {}
        self:Snapshot()
        return true
    end

    function Queue:GetStatus()
        local current = self.Current
        local message = self.LastMessage
        if self.Enabled then
            if current then
                local age = current.age ~= nil and tostring(current.age) or "?"
                message = string.format(
                    "%s | age %s%s | %d queued",
                    current.name,
                    age,
                    current.isFullGrown and " (Full Grown)" or "",
                    self.Remaining
                )
            else
                message = self.LastMessage
            end
        end
        if self.Enabled and current and current.targetXP and current.targetXP > 0
            and current.age ~= nil and current.age < 6 then
            local percent = math.clamp((current.xp or 0) / current.targetXP * 100, 0, 100)
            message ..= string.format(" | stage %.0f%%", percent)
        end
        if self.Enabled then
            message ..= " | " .. (self.Mode == "manual" and "Manual" or "Grow All")
        end
        return {
            enabled = self.Enabled,
            implemented = true,
            busy = self.Busy,
            message = message,
            mode = self.Mode,
            current = current,
            next = self.Next,
            remaining = self.Remaining,
            inventory = self.InventoryStats,
            queue = self.QueueList,
        }
    end

    function Queue:SetEnabled(enabled, reason)
        enabled = enabled == true
        if self.Enabled == enabled then return true end
        self.Enabled = enabled
        if enabled then
            -- Pet Queue and Egg Manager are mutually exclusive owners of the
            -- active equipped slot. The shared ailment Autofarm remains on.
            local eggs = ASTRAL.Modules:Get("eggs")
            if eggs and eggs.Enabled then
                eggs:SetEnabled(false, "Pet Queue took active slot ownership")
            end
            self.LastMessage = "Scanning pet inventory"
            log("enabled; Egg Manager disabled for pet-slot ownership")
            self:Snapshot()
        else
            self.LastMessage = reason and ("Off - " .. tostring(reason)) or "Off"
            log(reason and ("disabled - " .. tostring(reason)) or "disabled")
        end
        return true
    end

    function Queue:TryAdvance()
        if not self.Enabled or self.Busy then return false end
        if os.clock() - self.LastSwitch < self.SwitchCooldown then return false end

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

        local current, candidates = self:Snapshot()

        -- A growable equipped pet is normally already the correct target.
        -- In Grow All, however, generic progression should not consume Neon or
        -- Mega pets while a lower-tier variant is available. Those variants
        -- are reserved for the future Neon Factory unless normals are exhausted.
        if current and not current.isEgg and current.age ~= nil and current.age < 6 then
            local best = candidates[1]
            local factory = ASTRAL.Modules:Get("neon_factory")
            local currentTargetRank = factory and factory.Enabled
                and factory.GetGrowthPriority and select(1, factory:GetGrowthPriority(current)) or nil
            local bestTargetRank = best and factory and factory.Enabled
                and factory.GetGrowthPriority and select(1, factory:GetGrowthPriority(best)) or nil

            if self.Mode == "grow_all" and bestTargetRank ~= nil then
                local keepCurrent = false
                if currentTargetRank ~= nil and factory.PrioritizeGrowthCandidates then
                    local pair = factory:PrioritizeGrowthCandidates({current, best})
                    keepCurrent = pair[1] and pair[1].unique == current.unique
                end
                if keepCurrent then
                    self.LastMessage = "Growing Neon Factory target " .. current.name
                    return false
                end
                self.LastMessage = string.format(
                    "Neon Factory target -> switching %s to %s",
                    tostring(current.name),
                    tostring(best.name)
                )
                log(self.LastMessage)
            else
                local currentRank = current.isMega and 2 or (current.isNeon and 1 or 0)
                local bestRank = best and (best.isMega and 2 or (best.isNeon and 1 or 0)) or currentRank
                if self.Mode ~= "grow_all" or bestRank >= currentRank then
                    self.LastMessage = "Growing " .. current.name
                    return false
                end
                self.LastMessage = string.format(
                    "Preserving %s %s; switching to %s pet",
                    tostring(current.variant or "variant"),
                    tostring(current.name),
                    bestRank == 0 and "normal" or "lower-tier"
                )
                log(self.LastMessage)
            end
        end

        -- An equipped egg only blocks the queue while Egg Manager owns it.
        -- If Pet Queue is enabled, exclusivity guarantees Egg Manager is off,
        -- so continue below and replace the egg with the next growable pet.
        if current and current.isEgg then
            self.LastMessage = "Replacing equipped egg with Pet Queue target"
        end

        local nextPet = candidates[1]
        if not nextPet then
            self.LastMessage = self.Mode == "manual"
                and "Manual queue empty or all entries ineligible"
                or (current and current.isFullGrown
                    and "All eligible pets are Full Grown"
                    or "No eligible growable pets")
            return false
        end

        self.Busy = true
        self.LastSwitch = os.clock()
        local fromName = current and current.name or "No pet"
        log(string.format(
            "%s -> equipping %s [%s] (age %s, xp %s)",
            fromName,
            nextPet.name,
            tostring(nextPet.variant or "NORMAL"),
            tostring(nextPet.age),
            tostring(nextPet.xp)
        ))

        local ok, reason = Pets:Equip(nextPet.unique)
        if ok then
            self.LastMessage = "Growing " .. nextPet.name
            log("switched successfully to " .. nextPet.name)
            task.wait(1)
            self:Snapshot()
        else
            self.LastMessage = "Switch failed: " .. tostring(reason)
            warn("[ASTRAL PET QUEUE] " .. self.LastMessage)
        end

        self.Busy = false
        return ok, reason
    end

    task.spawn(function()
        while not ASTRAL.Runtime.Destroyed do
            if Queue.Enabled then
                local ok, err = pcall(function() Queue:TryAdvance() end)
                if not ok then
                    Queue.Busy = false
                    Queue.LastMessage = "Error: " .. tostring(err)
                    warn("[ASTRAL PET QUEUE] Cycle error:", err)
                end
            end
            task.wait(1)
        end
    end)

    ASTRAL.Modules:Register(Queue)
    return Queue
end
