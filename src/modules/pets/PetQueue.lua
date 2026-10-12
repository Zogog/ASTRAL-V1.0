-- ASTRAL dev.6 Pet Queue.
-- Safe first pass: grow non-egg pets to Full Grown, then equip the next
-- eligible inventory pet. Pet Pen assignments are reserved by default.
return function(ASTRAL)
    local Pets = assert(ASTRAL.Pets, "PetAPI must load before Pet Queue")

    local Queue = {
        Id = "pet_queue",
        Name = "Pet Queue",
        Page = "Pets",
        Description = "Automatically progress growable pets to Full Grown, then equip the next pet.",
        Version = "0.1.0-dev.6",
        Implemented = true,
        Enabled = false,
        Busy = false,
        LastSwitch = 0,
        SwitchCooldown = 3,
        Current = nil,
        Next = nil,
        Remaining = 0,
        LastMessage = "Off",
    }

    local function log(message)
        print("[ASTRAL PET QUEUE] " .. tostring(message))
        if ASTRAL.State then pcall(function() ASTRAL.State:Log("Pet Queue: " .. tostring(message)) end) end
    end

    function Queue:Snapshot()
        local current = Pets:GetCurrent()
        local candidates = Pets:GetGrowablePets({
            currentUnique = current and current.unique or nil,
        })
        self.Current = current
        self.Next = candidates[1]
        self.Remaining = #candidates
        return current, candidates
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
        return {
            enabled = self.Enabled,
            implemented = true,
            busy = self.Busy,
            message = message,
        }
    end

    function Queue:SetEnabled(enabled)
        enabled = enabled == true
        if self.Enabled == enabled then return true end
        self.Enabled = enabled
        if enabled then
            self.LastMessage = "Scanning pet inventory"
            log("enabled")
            self:Snapshot()
        else
            self.LastMessage = "Off"
            log("disabled")
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

        local current, candidates = self:Snapshot()

        -- A growable equipped pet is already the correct queue target.
        if current and not current.isEgg and current.age ~= nil and current.age < 6 then
            self.LastMessage = "Growing " .. current.name
            return false
        end

        -- Eggs are intentionally owned by the future Egg Manager.
        if current and current.isEgg then
            self.LastMessage = "Egg equipped; waiting for Egg Manager"
            return false
        end

        local nextPet = candidates[1]
        if not nextPet then
            self.LastMessage = current and current.isFullGrown
                and "All eligible pets are Full Grown"
                or "No eligible growable pets"
            return false
        end

        self.Busy = true
        self.LastSwitch = os.clock()
        local fromName = current and current.name or "No pet"
        log(string.format(
            "%s -> equipping %s (age %s, xp %s)",
            fromName,
            nextPet.name,
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
