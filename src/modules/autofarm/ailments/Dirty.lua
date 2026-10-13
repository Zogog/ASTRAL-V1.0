return function(ASTRAL)
    local S, Game = assert(ASTRAL.NeedSupport), assert(ASTRAL.Game)
    local RS = game:GetService("ReplicatedStorage")
    local ClientData = require(RS:WaitForChild("Fsys")).load("ClientData")

    local function useCampsiteShowerFallback(pet, context)
        if context:IsCancelled() or not Game:PetHasAilment("dirty") then
            return not Game:PetHasAilment("dirty"), "Cancelled or already complete"
        end

        -- Dusk & Shine 4.1.3 discovers MainMap camping_shower furniture and
        -- activates it through ActivateInteriorFurniture with UseBlock.
        local setLocation = S:Remote("LocationAPI/SetLocation")
        local activateInterior = S:Remote("HousingAPI/ActivateInteriorFurniture")
        if not setLocation or not activateInterior then
            return false, "Campsite shower fallback remotes unavailable"
        end

        local unsubscribe = S:Remote("HousingAPI/UnsubscribeFromHouse")
        if unsubscribe then pcall(function() S:Call(unsubscribe) end) end
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

        local showers = {}
        for unique, wrapper in pairs(records) do
            local data = type(wrapper) == "table" and (wrapper.data or wrapper) or nil
            if type(data) == "table" and tostring(data.id or ""):lower() == "camping_shower" then
                table.insert(showers, tostring(data.unique or unique))
            end
        end
        table.sort(showers)
        if #showers == 0 then return false, "MainMap camping_shower not found" end

        local root, petChar = S:PetRoot()
        if not root or not petChar then return false, "Equipped pet model unavailable" end

        for _, unique in ipairs(showers) do
            if context:IsCancelled() then return false, "Cancelled" end
            if not Game:PetHasAilment("dirty") then return true, "Complete" end

            S:Log("dirty: fallback using MainMap camping_shower " .. unique .. " / UseBlock")
            task.spawn(function()
                S:Call(activateInterior, unique, "UseBlock", { cframe = root.CFrame }, petChar)
            end)

            local baseline = Game:GetAilmentProgress("dirty") or 0
            local confirmUntil = os.clock() + 4
            while os.clock() < confirmUntil do
                local status, why = S:Check("dirty", pet, context)
                if status ~= nil then return status, why end
                local progress = Game:GetAilmentProgress("dirty")
                if progress and progress > baseline + 0.0001 then
                    S:Log("dirty: campsite shower confirmed progress "
                        .. tostring(baseline) .. " -> " .. tostring(progress))
                    return S:WaitClear("dirty", pet, context, 28)
                end
                task.wait(0.2)
            end
        end

        return false, "Campsite shower did not start progression"
    end

    return S:MakeHandler("dirty", "Dirty", 86, function(pet, context)
        local completed, reason = S:UseFurniture("dirty", {
            "modernshower", "cheap_pet_bathtub_tutorial", "cheappetbathtub", "cheap_pet_bathtub",
        }, "UseBlock", pet, context, 12)

        if completed or not Game:PetHasAilment("dirty") then
            return completed, reason
        end

        S:Log("dirty: owned shower/bath did not progress (" .. tostring(reason)
            .. "); trying MainMap campsite shower fallback")
        return useCampsiteShowerFallback(pet, context)
    end, 30)
end
