return function(ASTRAL)
    local S, Game = assert(ASTRAL.NeedSupport), assert(ASTRAL.Game)
    local Furniture = assert(ASTRAL.Furniture)
    local Players = game:GetService("Players")
    local RS = game:GetService("ReplicatedStorage")
    local Player = Players.LocalPlayer
    local ClientData = require(RS:WaitForChild("Fsys")).load("ClientData")

    local function useInteriorSleepFallback(pet, context)
        if context:IsCancelled() or not Game:PetHasAilment("sleepy") then
            return not Game:PetHasAilment("sleepy"), "Cancelled or already complete"
        end

        -- Dusk & Shine 4.1.3 uses MainMap's interior sleepingbag with Seat2
        -- for Sleepy. This is independent of which owned house slot is active,
        -- so it is a safe fallback when an owned crib belongs to another house.
        local setLocation = S:Remote("LocationAPI/SetLocation")
        local activateInterior = S:Remote("HousingAPI/ActivateInteriorFurniture")
        if not setLocation or not activateInterior then
            return false, "Interior sleep fallback remotes unavailable"
        end

        local moved, moveReason = S:Call(setLocation, "MainMap", nil, "MainMap")
        if not moved then return false, moveReason end
        task.wait(1.25)

        local houseInterior
        local ok = pcall(function()
            houseInterior = ClientData.get("house_interior")
        end)
        local records = ok and type(houseInterior) == "table" and houseInterior.furniture or nil
        if type(records) ~= "table" then
            return false, "MainMap interior furniture unavailable"
        end

        local sleepingBags = {}
        for unique, wrapper in pairs(records) do
            local data = type(wrapper) == "table" and (wrapper.data or wrapper) or nil
            if type(data) == "table" and tostring(data.id or ""):lower() == "sleepingbag" then
                table.insert(sleepingBags, tostring(data.unique or unique))
            end
        end
        table.sort(sleepingBags)
        if #sleepingBags == 0 then
            return false, "MainMap sleepingbag not found"
        end

        local root, petChar = S:PetRoot()
        if not root or not petChar then return false, "Equipped pet model unavailable" end

        for _, unique in ipairs(sleepingBags) do
            if context:IsCancelled() then return false, "Cancelled" end
            if not Game:PetHasAilment("sleepy") then return true, "Complete" end

            S:Log("sleepy: fallback using MainMap sleepingbag " .. unique .. " / Seat2")
            task.spawn(function()
                S:Call(activateInterior, unique, "Seat2", { cframe = root.CFrame }, petChar)
            end)

            local baseline = Game:GetAilmentProgress("sleepy") or 0
            local confirmUntil = os.clock() + 4
            while os.clock() < confirmUntil do
                local status, why = S:Check("sleepy", pet, context)
                if status ~= nil then return status, why end
                local progress = Game:GetAilmentProgress("sleepy")
                if progress and progress > baseline + 0.0001 then
                    S:Log("sleepy: interior sleepingbag confirmed progress "
                        .. tostring(baseline) .. " -> " .. tostring(progress))
                    return S:WaitClear("sleepy", pet, context, 28)
                end
                task.wait(0.2)
            end
        end

        return false, "Interior sleepingbag did not start progression"
    end

    return S:MakeHandler("sleepy", "Sleepy", 88, function(pet, context)
        local wrappers = Game:GetEquippedPetWrappers()
        local wrapper = wrappers and wrappers[1]
        local isEgg = false
        if wrapper then
            local ok, item = pcall(function()
                local Fsys = require(RS:WaitForChild("Fsys"))
                return Fsys.load("EquippedPets").get_item_from_wrapper(wrapper)
            end)
            if ok and type(item) == "table" then
                isEgg = tostring(item.kind or ""):lower():find("egg", 1, true) ~= nil
            end
        end

        if isEgg then
            local bed, reason = Furniture:FindMatching(function(record)
                return tostring(record.id or ""):lower():find("bed", 1, true) ~= nil
            end, "owned furniture id containing 'bed'")
            if not bed then return false, reason end

            local root, petChar = S:PetRoot()
            if not root or not petChar then return false, "Equipped pet model unavailable" end
            local remote = S:Remote("HousingAPI/ActivateFurniture")
            S:Log("sleepy: egg using " .. tostring(bed.id) .. " from slot " .. tostring(bed.slot) .. " / Seat1")
            local used, err = S:Call(remote, Player,
                bed.unique, "Seat1", { cframe = root.CFrame }, petChar)
            if not used then return false, err end
            return S:WaitClear("sleepy", pet, context, 32)
        end

        local completed, reason = S:UseFurniture(
            "sleepy", {"basiccrib"}, "UseBlock", pet, context, 12
        )
        if completed or not Game:PetHasAilment("sleepy") then
            return completed, reason
        end

        S:Log("sleepy: owned crib did not progress (" .. tostring(reason)
            .. "); trying D&S MainMap sleepingbag fallback")
        return useInteriorSleepFallback(pet, context)
    end, 30)
end
