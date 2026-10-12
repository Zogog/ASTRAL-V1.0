-- ASTRAL dev.6.7 Pet Pens.
-- Restores the verified v0.5.6/v0.5.7b idle-progression lifecycle:
-- claim -> refresh -> remove Full Grown -> refresh -> fill vacancies.
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
        Version = "0.1.0-dev.6.7-restored",
        Implemented = true,
        Enabled = false,
        Busy = false,
        Interval = 60,
        -- Four slots are the last verified capacity. Jamie owns the fifth
        -- purchased slot, but its ownership/capacity field is not yet proven.
        Capacity = 4,
        LastCycle = 0,
        LastMessage = "Off",
        Occupied = 0,
        LastClaim = 0,
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

    local function isFullGrown(unique, state)
        if type(state) == "table" then
            if state.max_age == true then return true end
            if tonumber(state.age) and tonumber(state.age) >= 6 then return true end
        end
        local item = Pets:GetItem(unique)
        local described = item and Pets:Describe(item) or nil
        return described and described.isFullGrown == true or false
    end

    function Pens:GetStatus()
        return {
            enabled = self.Enabled,
            implemented = true,
            busy = self.Busy,
            message = self.LastMessage,
            occupied = self.Occupied,
            capacity = self.Capacity,
            lastClaim = self.LastClaim,
        }
    end

    function Pens:SetEnabled(enabled)
        enabled = enabled == true
        if self.Enabled == enabled then return true end
        self.Enabled = enabled
        if enabled then
            self.LastMessage = "Starting idle-progression cycle"
            self.LastCycle = 0 -- immediate first cycle
            log("enabled")
        else
            self.LastMessage = "Off"
            log("disabled")
        end
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
        self.LastCycle = os.clock()

        local ok, err = pcall(function()
            -- The old Auto Pet Pen always claimed first so accumulated XP/Bucks
            -- were committed before any assignment was changed.
            local claimed, claimReason = self:Claim()
            if not claimed then
                warn("[ASTRAL PET PENS] Claim failed:", claimReason)
            end

            local active = getActive()
            self.Occupied = countActive(active)
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

            self.Occupied = countActive(getActive())
            self.LastMessage = string.format(
                "%d/%d occupied | claimed | %d removed | %d added",
                self.Occupied,
                self.Capacity,
                removed,
                added
            )
            log(self.LastMessage)

            -- Refresh queue caches after pen membership changes so the UI and
            -- active queue immediately reserve every newly assigned pen pet.
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
                and os.clock() - Pens.LastCycle >= Pens.Interval then
                Pens:Cycle()
            end
            task.wait(1)
        end
    end)

    ASTRAL.Modules:Register(Pens)
    return Pens
end
