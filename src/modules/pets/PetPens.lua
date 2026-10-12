-- ASTRAL dev.6.8 Pet Pens v2.
-- Verified idle-progression lifecycle:
-- claim -> measure -> refresh -> remove Full Grown -> refresh -> fill vacancies.
-- UI-facing state is cached as plain Lua data so Window.lua never needs to
-- touch Adopt Me/Fsys APIs from executor GUI callback threads.
return function(ASTRAL)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
    local ClientData = Fsys.load("ClientData")
    local Pets = assert(ASTRAL.Pets, "PetAPI must load before Pet Pens")
    local Game = assert(ASTRAL.Game, "GameAPI must load before Pet Pens")

    local Pens = {
        Id = "pet_pens",
        Name = "Pet Pens",
        Page = "Pet Pens",
        Description = "Claim idle progression, replace Full Grown pets and keep Pet Pens filled.",
        Version = "0.2.0-dev.6.8-ui-eta",
        Implemented = true,
        Enabled = false,
        Busy = false,
        Interval = 60,
        Capacity = 4,

        -- Approximate online Pet Pen rate established during our earlier
        -- research. Once ASTRAL has two committed samples for a pet, the UI
        -- switches to that pet's measured rolling rate instead.
        BaselineXPPerHour = 800,

        LastCycle = 0,
        LastMessage = "Off",
        LastSummary = "No cycle yet",
        Occupied = 0,
        LastClaim = 0,
        ForceCycle = false,

        SlotSnapshots = {},
        Measurements = {},
    }

    local function log(message)
        print("[ASTRAL PET PENS] " .. tostring(message))
        if ASTRAL.State then
            pcall(function() ASTRAL.State:Log("Pet Pens: " .. tostring(message)) end)
        end
    end

    local function getManager()
        local ok, manager = pcall(function()
            return ClientData.get("idle_progression_manager")
        end)
        return ok and type(manager) == "table" and manager or nil
    end

    local function getActive()
        local manager = getManager()
        return manager and type(manager.active_pets) == "table"
            and manager.active_pets or {}
    end

    local function countActive(active)
        local n = 0
        for _ in pairs(active or {}) do n += 1 end
        return n
    end

    local function waitForAssignment(unique, shouldExist, timeout)
        local deadline = os.clock() + (timeout or 4)
        repeat
            local exists = getActive()[unique] ~= nil
            if exists == shouldExist then return true end
            task.wait(0.2)
        until os.clock() >= deadline
        return false
    end

    local function describeUnique(unique)
        local item = Pets:GetItem(unique)
        if not item then return nil end
        return Pets:Describe(item)
    end

    local function remainingXP(pet)
        if not pet then return nil end
        return Pets:GetRemainingGrowthXP(pet)
    end

    local function isFullGrown(unique, state)
        if type(state) == "table" then
            if state.max_age == true then return true end
            if tonumber(state.age) and tonumber(state.age) >= 6 then return true end
        end
        local pet = describeUnique(unique)
        return pet and pet.isFullGrown == true or false
    end

    local function formatRate(rate)
        return rate and math.floor(rate + 0.5) or nil
    end

    -- Measure progression using the drop in total XP remaining rather than
    -- current-stage XP. This remains correct when a claim crosses an age
    -- boundary and the pet's stage XP resets.
    function Pens:UpdateMeasurements(active)
        local now = os.clock()
        local present = {}

        for unique in pairs(active or {}) do
            present[unique] = true
            local pet = describeUnique(unique)
            local remaining = remainingXP(pet)
            if remaining ~= nil then
                local previous = self.Measurements[unique]
                local measuredRate = previous and previous.rate or nil

                if previous
                    and previous.remaining ~= nil
                    and previous.at
                    and now - previous.at >= 30 then

                    local gained = previous.remaining - remaining
                    local elapsed = now - previous.at
                    if gained > 0 and elapsed > 0 then
                        local sample = gained / elapsed * 3600
                        -- Ignore clearly corrupt samples while leaving a wide
                        -- range for future game-side rate changes.
                        if sample >= 1 and sample <= 10000 then
                            measuredRate = measuredRate
                                and (measuredRate * 0.65 + sample * 0.35)
                                or sample
                            log(string.format(
                                "%s measured %.0f XP/hr",
                                tostring(pet and pet.name or unique),
                                measuredRate
                            ))
                        end
                    end
                end

                self.Measurements[unique] = {
                    remaining = remaining,
                    at = now,
                    rate = measuredRate,
                }
            end
        end

        for unique in pairs(self.Measurements) do
            if not present[unique] then
                self.Measurements[unique] = nil
            end
        end
    end

    function Pens:RefreshSlots(active)
        active = active or getActive()
        local slots = {}

        for unique, state in pairs(active) do
            local pet = describeUnique(unique)
            local remaining = remainingXP(pet)
            local measurement = self.Measurements[unique]
            local measuredRate = measurement and measurement.rate or nil
            local rate = measuredRate or self.BaselineXPPerHour
            local etaSeconds = remaining ~= nil and rate and rate > 0
                and (remaining / rate * 3600) or nil

            table.insert(slots, {
                unique = tostring(unique),
                name = pet and pet.name or tostring(unique),
                kind = pet and pet.kind or nil,
                age = pet and pet.age or tonumber(type(state) == "table" and state.age),
                xp = pet and pet.xp or 0,
                targetXP = pet and pet.targetXP or nil,
                isFullGrown = pet and pet.isFullGrown == true
                    or (type(state) == "table" and state.max_age == true),
                remainingXP = remaining,
                xpPerHour = formatRate(rate),
                rateMeasured = measuredRate ~= nil,
                etaSeconds = etaSeconds and math.max(0, math.floor(etaSeconds + 0.5)) or nil,
            })
        end

        table.sort(slots, function(a, b)
            if a.name == b.name then return a.unique < b.unique end
            return tostring(a.name) < tostring(b.name)
        end)

        self.SlotSnapshots = slots
        self.Occupied = #slots
        return slots
    end

    function Pens:GetSlots()
        local copy = {}
        for i, slot in ipairs(self.SlotSnapshots) do
            local row = {}
            for key, value in pairs(slot) do row[key] = value end
            copy[i] = row
        end
        return copy
    end

    function Pens:GetStatus()
        local nextCycleIn
        if self.Enabled then
            nextCycleIn = math.max(0, self.Interval - (os.clock() - self.LastCycle))
        end
        return {
            enabled = self.Enabled,
            implemented = true,
            busy = self.Busy,
            message = self.LastMessage,
            summary = self.LastSummary,
            occupied = self.Occupied,
            capacity = self.Capacity,
            lastClaim = self.LastClaim,
            nextCycleIn = nextCycleIn,
            baselineXPPerHour = self.BaselineXPPerHour,
        }
    end

    function Pens:SetEnabled(enabled)
        enabled = enabled == true
        if self.Enabled == enabled then return true end
        self.Enabled = enabled
        if enabled then
            self.LastMessage = "Starting idle-progression cycle"
            self.LastCycle = 0
            self.ForceCycle = true
            log("enabled")
        else
            self.LastMessage = "Off"
            self.ForceCycle = false
            log("disabled")
        end
        return true
    end

    -- Executor-safe UI request: the GUI only flips a Lua flag. The normal
    -- Pet Pens worker performs the remote/API work on its own thread.
    function Pens:RequestCycle()
        if not self.Enabled then return false, "Enable Pet Pens first" end
        if self.Busy then return false, "Pet Pens are already busy" end
        self.ForceCycle = true
        self.LastMessage = "Claim requested"
        return true
    end

    function Pens:Claim()
        local remote = Game:GetRemote("IdleProgressionAPI/CommitAllProgression")
        if not remote then return false, "CommitAllProgression unavailable" end
        local ok, err = pcall(function()
            remote:FireServer(true)
        end)
        if not ok then return false, tostring(err) end
        self.LastClaim = os.time()
        log("claimed idle progression")
        task.wait(0.75)
        return true
    end

    function Pens:Remove(unique)
        local remote = Game:GetRemote("IdleProgressionAPI/RemovePet")
        if not remote then return false, "RemovePet unavailable" end
        local ok, err = pcall(function()
            remote:FireServer(unique)
        end)
        if not ok then return false, tostring(err) end
        if not waitForAssignment(unique, false, 4) then
            return false, "server state did not confirm removal"
        end
        return true
    end

    function Pens:Add(unique)
        local remote = Game:GetRemote("IdleProgressionAPI/AddPet")
        if not remote then return false, "AddPet unavailable" end
        local ok, err = pcall(function()
            remote:FireServer(unique)
        end)
        if not ok then return false, tostring(err) end
        if not waitForAssignment(unique, true, 4) then
            return false, "server state did not confirm assignment"
        end
        return true
    end

    function Pens:Cycle()
        if not self.Enabled or self.Busy then return false end

        local queue = ASTRAL.Modules:Get("pet_queue")
        if queue and queue.Busy then
            self.LastMessage = "Waiting for Pet Queue"
            return false
        end

        self.Busy = true
        self.ForceCycle = false
        self.LastCycle = os.clock()

        local ok, err = pcall(function()
            local claimed, claimReason = self:Claim()
            if not claimed then
                warn("[ASTRAL PET PENS] Claim failed:", claimReason)
            end

            -- Read committed progression immediately after the claim and turn
            -- it into a per-pet observed XP/hour sample.
            local active = getActive()
            self:UpdateMeasurements(active)
            self:RefreshSlots(active)
            log(string.format("refresh: %d/%d occupied", self.Occupied, self.Capacity))

            local removed = 0
            for unique, state in pairs(active) do
                if isFullGrown(unique, state) then
                    log("removing Full Grown pet " .. tostring(unique))
                    local removedOk, reason = self:Remove(unique)
                    if removedOk then
                        removed += 1
                    else
                        warn("[ASTRAL PET PENS] Remove failed:", unique, reason)
                    end
                end
            end

            active = getActive()
            self.Occupied = countActive(active)

            local current = Pets:GetCurrent()
            local candidates = Pets:GetGrowablePets({
                currentUnique = current and current.unique or nil,
            })
            local attempted = {}
            local added = 0
            local index = 1

            while self.Occupied < self.Capacity and index <= #candidates do
                local pet = candidates[index]
                index += 1
                if pet and not attempted[pet.unique] and not getActive()[pet.unique] then
                    attempted[pet.unique] = true
                    log(string.format(
                        "filling slot %d/%d with %s (age %s, xp %s)",
                        self.Occupied + 1,
                        self.Capacity,
                        tostring(pet.name),
                        tostring(pet.age),
                        tostring(pet.xp)
                    ))
                    local addedOk, reason = self:Add(pet.unique)
                    if addedOk then
                        added += 1
                        self.Occupied = countActive(getActive())
                    else
                        warn("[ASTRAL PET PENS] Add failed:", pet.name, reason)
                    end
                end
            end

            active = getActive()

            -- New assignments need a clean measurement baseline so their first
            -- observed rate is calculated over a real full interval.
            for unique in pairs(active) do
                if not self.Measurements[unique] then
                    local pet = describeUnique(unique)
                    local remaining = remainingXP(pet)
                    if remaining ~= nil then
                        self.Measurements[unique] = {
                            remaining = remaining,
                            at = os.clock(),
                            rate = nil,
                        }
                    end
                end
            end

            self:RefreshSlots(active)
            self.LastSummary = string.format(
                "%d/%d occupied | claimed | %d removed | %d added",
                self.Occupied,
                self.Capacity,
                removed,
                added
            )
            self.LastMessage = self.LastSummary
            log(self.LastSummary)

            if queue and queue.Snapshot then
                queue:Snapshot()
            end
        end)

        self.Busy = false
        if not ok then
            self.LastMessage = "Cycle error: " .. tostring(err)
            warn("[ASTRAL PET PENS] " .. self.LastMessage)
            return false, err
        end
        return true
    end

    task.spawn(function()
        while not ASTRAL.Runtime.Destroyed do
            if Pens.Enabled
                and not Pens.Busy
                and (Pens.ForceCycle or os.clock() - Pens.LastCycle >= Pens.Interval) then
                Pens:Cycle()
            end
            task.wait(1)
        end
    end)

    ASTRAL.Modules:Register(Pens)
    return Pens
end
