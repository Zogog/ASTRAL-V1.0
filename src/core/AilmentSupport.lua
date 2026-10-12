-- ASTRAL dev.5 shared helpers for remaining core pet ailments.
-- No destructive guesses: every action checks pet identity, cancellation and real ailment state.
return function(ASTRAL)
    local Game = assert(ASTRAL.Game)
    local Players = game:GetService("Players")
    local RS = game:GetService("ReplicatedStorage")
    local Player = Players.LocalPlayer
    local Fsys = require(RS:WaitForChild("Fsys"))
    local ClientData = Fsys.load("ClientData")
    local EquippedPets = Fsys.load("EquippedPets")
    local S = { Cooldowns = {}, Version = "0.1.8-dev.6.9.1-preferred-house" }

    function S:Log(message)
        print("[ASTRAL NEEDS] " .. tostring(message))
        if ASTRAL.State then pcall(function() ASTRAL.State:Log(tostring(message)) end) end
    end
    function S:Ready(kind)
        return os.clock() >= (self.Cooldowns[kind] or 0)
    end
    function S:Backoff(kind, seconds)
        self.Cooldowns[kind] = os.clock() + (seconds or 12)
    end
    function S:Check(kind, petUnique, context)
        if context:IsCancelled() then return false, "Cancelled" end
        if Game:GetCurrentPetUnique() ~= petUnique then return false, "Pet changed" end
        if not Game:PetHasAilment(kind) then return true, "Complete" end
        return nil, "Pending"
    end
    function S:WaitClear(kind, petUnique, context, seconds)
        local deadline = os.clock() + seconds
        while os.clock() < deadline do
            local status, why = self:Check(kind, petUnique, context)
            if status ~= nil then return status, why end
            task.wait(0.2)
        end
        return not Game:PetHasAilment(kind), "Timed out"
    end
    function S:PetCharacter()
        local currentUnique = Game:GetCurrentPetUnique()
        local dsChar = Game:GetPetCharacter(currentUnique)
        if dsChar then return dsChar end

        local wrappers = Game:GetEquippedPetWrappers()
        local wrapper = wrappers and wrappers[1]
        if wrapper and typeof(wrapper.char) == "Instance" and wrapper.char.Parent then return wrapper.char end
        local ok, legacy = pcall(function() return ClientData.get("pet_char_wrapper") end)
        if ok and type(legacy) == "table" and typeof(legacy.char) == "Instance" then
            return legacy.char
        end
        local pets = workspace:FindFirstChild("Pets")
        if not pets then return nil end
        for _, candidate in ipairs(pets:GetChildren()) do
            local owner = candidate:FindFirstChild("Owner")
            if owner and owner:IsA("ObjectValue") and owner.Value == Player then return candidate end
        end
        return nil -- do not select another player's pet
    end
    function S:PetRoot()
        local char = self:PetCharacter()
        if not char then return nil, nil end
        return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart or char:FindFirstChildWhichIsA("BasePart"), char
    end
    function S:PlayerRoot()
        local char = Player.Character
        return char and char:FindFirstChild("HumanoidRootPart"), char
    end
    function S:Remote(name)
        return Game:GetRemote(name)
    end
    function S:Call(remote, ...)
        if not remote then return false, "Remote unavailable" end
        local args = table.pack(...)
        local ok, result = pcall(function()
            if remote:IsA("RemoteFunction") then return remote:InvokeServer(table.unpack(args, 1, args.n)) end
            remote:FireServer(table.unpack(args, 1, args.n))
            return true
        end)
        if not ok or result == false then return false, tostring(result) end
        return true, result
    end
    -- Dusk & Shine 4.1.3 checks the pet state manager for an active
    -- UseFurniture state and clears it with PetAPI/ExitFurnitureUseStates.
    function S:PetInFurnitureState(petUnique)
        local ok, managers = pcall(function()
            return ClientData.get("pet_state_managers")
        end)
        if not ok or type(managers) ~= "table" then return false end

        local manager = managers[petUnique]
        if type(manager) ~= "table" then return false end
        if manager.is_sitting then return true end

        if type(manager.states) == "table" then
            for _, state in pairs(manager.states) do
                if type(state) == "table" and state.id == "UseFurniture" then
                    return true
                end
            end
        end
        return false
    end

    function S:ExitPetFurnitureState(petUnique, attempts, delaySeconds)
        if not self:PetInFurnitureState(petUnique) then
            return true, "Already clear"
        end

        local remote = self:Remote("PetAPI/ExitFurnitureUseStates")
        if not remote then return false, "ExitFurnitureUseStates unavailable" end

        attempts = attempts or 1
        delaySeconds = delaySeconds or 0.5

        for attempt = 1, attempts do
            local ok, why = self:Call(remote, petUnique)
            if not ok then
                self:Log("furniture exit attempt " .. tostring(attempt)
                    .. " failed: " .. tostring(why))
            end

            task.wait(delaySeconds)
            if not self:PetInFurnitureState(petUnique) then
                return true, "Cleared"
            end
        end

        return not self:PetInFurnitureState(petUnique), "Furniture state still active"
    end

    function S:MakeHandler(kind, name, priority, action, cooldown)
        local handler = { Id = kind, Name = name, Priority = priority, Version = self.Version }
        function handler:CanRun()
            return Game:GetCurrentPetUnique() ~= nil and S:Ready(kind)
        end
        function handler:Run(_, context)
            local petUnique = Game:GetCurrentPetUnique()
            if not petUnique then return false, "No pet" end
            if not Game:PetHasAilment(kind) then return true end
            S:Log(kind .. ": starting")
            local ok, result, why = pcall(action, petUnique, context)
            if not ok then
                S:Backoff(kind, cooldown or 20)
                S:Log(kind .. ": error " .. tostring(result))
                return false, tostring(result)
            end
            if result == true and not Game:PetHasAilment(kind) then
                S:Log(kind .. ": complete")
                return true
            end
            if context:IsCancelled() then return false, "Cancelled" end
            S:Backoff(kind, cooldown or 20)
            local reason = why or (result == true and "Still present" or "Action unavailable")
            S:Log(kind .. ": incomplete: " .. tostring(reason))
            return false, tostring(reason)
        end
        ASTRAL.Ailments:Register(handler)
        return handler
    end
    function S:HouseSlot()
        -- Compatibility helper: return an explicitly configured slot first,
        -- otherwise the first house slot discovered by FurnitureAPI.
        local configured = tonumber(ASTRAL.Config and ASTRAL.Config.HouseSlot)
        if configured and configured >= 1 and configured % 1 == 0 then return configured end
        local Furniture = ASTRAL.Furniture
        if Furniture and Furniture.SelectPreferredHome then
            return Furniture:SelectPreferredHome(false)
        end
        return Furniture and Furniture.DiscoveredSlots and Furniture.DiscoveredSlots[1] or nil
    end
    function S:HouseFurniture(ids)
        local Furniture = assert(ASTRAL.Furniture, "FurnitureAPI not loaded")
        return Furniture:Find(ids)
    end
    function S:UseFurniture(kind, ids, interaction, petUnique, context, timeout)
        local furniture, reason = self:HouseFurniture(ids)
        if not furniture then return false, reason end
        local remote = self:Remote("HousingAPI/ActivateFurniture")
        if not remote then return false, "ActivateFurniture unavailable" end

        -- D&S performs a stale-state sweep before choosing the next task.
        -- Do the equivalent for this pet before trying another furniture use.
        if self:PetInFurnitureState(petUnique) then
            self:Log(kind .. ": clearing stale furniture state before activation")
            local cleared, clearReason = self:ExitPetFurnitureState(petUnique, 1, 0.5)
            self:Log(kind .. ": pre-activation furniture state "
                .. (cleared and "cleared" or ("still active: " .. tostring(clearReason))))
        end

        local function finishFurniture(success, why)
            if success then
                -- D&S retries ExitFurnitureUseStates after the need disappears,
                -- up to six times with two-second checks.
                local cleared, clearReason = self:ExitPetFurnitureState(petUnique, 6, 2)
                self:Log(kind .. ": post-completion furniture state "
                    .. (cleared and "cleared" or ("still active: " .. tostring(clearReason))))
            end
            return success, why
        end

        local function waitFurnitureClear(seconds)
            local success, why = self:WaitClear(kind, petUnique, context, seconds)
            return finishFurniture(success, why)
        end

        local totalTimeout = timeout or 30
        local deadline = os.clock() + totalTimeout
        local baseline = Game:GetAilmentProgress(kind) or 0
        local maxAttempts = 3
        local candidates = { furniture }
        local seenFurniture = { [furniture.unique] = true }
        local Furniture = ASTRAL.Furniture
        if Furniture and Furniture.GetMatches then
            for _, candidate in ipairs(Furniture:GetMatches(ids)) do
                if candidate.unique and not seenFurniture[candidate.unique] then
                    seenFurniture[candidate.unique] = true
                    table.insert(candidates, candidate)
                end
            end
        end

        for attempt = 1, maxAttempts do
            furniture = candidates[math.min(attempt, #candidates)] or furniture
            if context:IsCancelled() then return false, "Cancelled" end
            if Game:GetCurrentPetUnique() ~= petUnique then return false, "Pet changed" end
            if not Game:PetHasAilment(kind) then return finishFurniture(true, "Complete") end

            local root, petChar = self:PetRoot()
            if not root or not petChar then return false, "Equipped pet model unavailable" end

            local suffix = attempt > 1 and (" (attempt " .. tostring(attempt) .. ")") or ""
            self:Log(kind .. ": using furniture " .. tostring(furniture.id)
                .. " from slot " .. tostring(furniture.slot)
                .. " / " .. tostring(interaction or "UseBlock") .. suffix)

            local callStarted = os.clock()
            local callDone, used, err = false, false, nil
            task.spawn(function()
                used, err = self:Call(remote, Player, furniture.unique,
                    interaction or "UseBlock", { cframe = root.CFrame }, petChar)
                callDone = true
            end)

            -- ActivateFurniture may remain blocked long after the ailment should
            -- have timed out. Never let that InvokeServer pin the Autofarm
            -- scheduler: observe it for two seconds, then wait on ailment state
            -- only, bounded by this handler's existing deadline.
            local observeUntil = math.min(deadline, callStarted + 2.0)
            while not callDone and os.clock() < observeUntil do
                local status, why = self:Check(kind, petUnique, context)
                if status ~= nil then return status, why end
                task.wait(0.1)
            end

            local callSeconds = os.clock() - callStarted
            if not callDone then
                self:Log(kind .. ": activation still pending; waiting on ailment state")
                local remaining = math.max(0, deadline - os.clock())
                return waitFurnitureClear(remaining)
            end

            if not used then
                if attempt >= maxAttempts then return false, err end
                self:Log(kind .. ": activation failed; retrying: " .. tostring(err))
                task.wait(0.75)
            else
                if not Game:PetHasAilment(kind) then return finishFurniture(true, "Complete") end

                -- Successful furniture use often keeps InvokeServer blocked for
                -- the interaction duration. A silently rejected activation
                -- returns almost immediately. Only retry the latter case.
                if callSeconds >= 2.0 then
                    local remaining = math.max(0, deadline - os.clock())
                    return waitFurnitureClear(remaining)
                end

                local confirmUntil = math.min(deadline, os.clock() + 2.5)
                local progressed = false
                while os.clock() < confirmUntil do
                    local status, why = self:Check(kind, petUnique, context)
                    if status ~= nil then return status, why end
                    local progress = Game:GetAilmentProgress(kind)
                    if progress and progress > baseline + 0.0001 then
                        progressed = true
                        self:Log(kind .. ": furniture interaction confirmed progress "
                            .. tostring(baseline) .. " -> " .. tostring(progress))
                        break
                    end
                    task.wait(0.2)
                end

                if progressed then
                    local remaining = math.max(0, deadline - os.clock())
                    return waitFurnitureClear(remaining)
                end

                if attempt < maxAttempts and os.clock() < deadline then
                    -- D&S clears the server-side furniture state instead of
                    -- unequipping/re-equipping the pet.
                    if self:PetInFurnitureState(petUnique) then
                        self:Log(kind .. ": clearing furniture state before retry")
                        self:ExitPetFurnitureState(petUnique, 1, 0.5)
                    end
                    local nextFurniture = candidates[math.min(attempt + 1, #candidates)]
                    if nextFurniture and nextFurniture.unique ~= furniture.unique then
                        self:Log(kind .. ": activation returned without progress; trying alternate "
                            .. tostring(nextFurniture.id) .. " -> " .. tostring(nextFurniture.unique)
                            .. " (slot " .. tostring(nextFurniture.slot) .. ")")
                    else
                        self:Log(kind .. ": activation returned without progress; retrying")
                    end
                    task.wait(0.75)
                end
            end
        end

        local remaining = math.max(0, deadline - os.clock())
        if remaining > 0 then
            return waitFurnitureClear(remaining)
        end
        return not Game:PetHasAilment(kind), "Timed out"
    end

    function S:GoLocation(kind, destination, petUnique, context, timeout)
        local remote = self:Remote("LocationAPI/SetLocation")
        local ok, why = self:Call(remote, destination, nil, nil)
        if not ok then return false, why end
        self:Log(kind .. ": travelled to " .. destination)
        local success, reason = self:WaitClear(kind, petUnique, context, timeout or 67)
        -- Always return to MainMap, including cancellation or timeout.
        local returned, retReason = self:Call(remote, "MainMap", nil, "Default")
        if not returned then self:Log(kind .. ": MainMap return failed: " .. tostring(retReason)) end
        return success, reason
    end
    function S:GoSpatial(kind, playerCF, petCF, petUnique, context)
        local setLocation = self:Remote("LocationAPI/SetLocation")
        if not setLocation then return false, "SetLocation unavailable" end
        local ok, reason = self:Call(setLocation, "MainMap", nil, "Default")
        if not ok then return false, reason end
        task.wait(1.5)
        if context:IsCancelled() then return false, "Cancelled" end
        local root = self:PlayerRoot()
        local petRoot = self:PetRoot()
        if not root or not petRoot then return false, "Player/pet root unavailable" end
        local oldPlayer, oldPet = root.CFrame, petRoot.CFrame
        local function restore()
            pcall(function() if root.Parent then root.CFrame = oldPlayer end end)
            pcall(function() if petRoot.Parent then petRoot.CFrame = oldPet end end)
        end
        local success, completed, why = pcall(function()
            root.CFrame = playerCF
            petRoot.CFrame = petCF
            local progressDeadline = os.clock() + 9
            local confirmed = false
            while os.clock() < progressDeadline do
                local state, why2 = self:Check(kind, petUnique, context)
                if state ~= nil then return state, why2 end
                local _, ailment = Game:PetHasAilment(kind)
                if ailment and tonumber(ailment.rate) and tonumber(ailment.rate) > 0 then
                    confirmed = true
                    self:Log(kind .. ": positive progression rate " .. tostring(ailment.rate))
                    break
                end
                task.wait(0.2)
            end
            if not confirmed then return false, "No positive rate at destination" end
            return self:WaitClear(kind, petUnique, context, 65)
        end)
        restore()
        if not success then return false, tostring(completed) end
        return completed, why
    end
    ASTRAL.NeedSupport = S
    return S
end
