-- ASTRAL dev.5: Sick, Sleepy, Dirty, Toilet, Bored, Pet Me.
return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)
    local Game = assert(ASTRAL.Game)
    local function ownedApple()
        for _, item in pairs(Game:GetInventory().food or {}) do
            if type(item) == "table" and item.kind == "healing_apple" and item.unique then
                local props = item.properties
                if type(props) ~= "table" or tonumber(props.uses_left or 1) > 0 then return item end
            end
        end
    end
    local lastApplePurchase = -math.huge
    S:MakeHandler("sick", "Sick", 95, function(pet, context)
        local apple = ownedApple()
        if not apple then
            if os.clock() - lastApplePurchase < 60 then return false, "Apple purchase cooldown" end
            local buy = S:Remote("ShopAPI/BuyItem")
            if not buy then return false, "BuyItem unavailable" end
            lastApplePurchase = os.clock()
            local ok, why = S:Call(buy, "food", "healing_apple", {buy_count = 1})
            if not ok then return false, "Healing Apple purchase failed: " .. tostring(why) end
            local deadline = os.clock() + 6
            while os.clock() < deadline do
                if context:IsCancelled() then return false, "Cancelled" end
                apple = ownedApple()
                if apple then break end
                task.wait(0.2)
            end
            if not apple then return false, "Healing Apple not replicated" end
        end
        local start = S:Remote("ToolAPI/ServerUseTool")
        local create = S:Remote("PetObjectAPI/CreatePetObject")
        if not start or not create then return false, "Food remotes unavailable" end
        local ok, why = S:Call(start, apple.unique, "START")
        if not ok then return false, why end
        -- 1.17s from the previously controlled Healing Apple capture.
        local deadline = os.clock() + 1.17
        while os.clock() < deadline do
            if context:IsCancelled() then return false, "Cancelled" end
            task.wait(0.05)
        end
        ok, why = S:Call(create, "__Enum_PetObjectCreatorType_2", {
            pet_unique = pet, unique_id = apple.unique, additional_consume_uniques = {},
        })
        if not ok then return false, why end
        return S:WaitClear("sick", pet, context, 17)
    end, 35)

    S:MakeHandler("sleepy", "Sleepy", 88, function(pet, context)
        -- Eggs need bed/Seat1; ordinary pets prefer crib/UseBlock.
        local wrappers = Game:GetEquippedPetWrappers()
        local wrapper = wrappers and wrappers[1]
        local isEgg = false
        if wrapper then
            local ok, item = pcall(function()
                local Fsys = require(game:GetService("ReplicatedStorage"):WaitForChild("Fsys"))
                return Fsys.load("EquippedPets").get_item_from_wrapper(wrapper)
            end)
            if ok and type(item) == "table" then
                isEgg = tostring(item.kind or ""):lower():find("egg", 1, true) ~= nil
            end
        end
        if isEgg then
            local slot = S:HouseSlot()
            if not slot then return false, "Egg needs bed; house slot unknown" end
            local remote = S:Remote("HousingAPI/GetFurnitureWithinHouse")
            if not remote then return false, "House furniture lookup unavailable" end
            local ok, records = pcall(function() return remote:InvokeServer(slot) end)
            if not ok or type(records) ~= "table" then return false, "Furniture query failed" end
            local beds = {}
            for _, entry in pairs(records) do
                local data = type(entry) == "table" and (entry.data or entry) or nil
                if type(data) == "table" and tostring(data.id or ""):lower():find("bed", 1, true) then
                    table.insert(beds, tostring(data.id))
                end
            end
            table.sort(beds)
            if #beds == 0 then return false, "No owned egg-compatible bed" end
            return S:UseFurniture("sleepy", beds, "Seat1", pet, context, 32)
        end
        return S:UseFurniture("sleepy", {"basiccrib"}, "UseBlock", pet, context, 32)
    end, 30)
    S:MakeHandler("dirty", "Dirty", 86, function(pet, context)
        return S:UseFurniture("dirty", {
            "modernshower", "cheap_pet_bathtub_tutorial", "cheappetbathtub", "cheap_pet_bathtub",
        }, "UseBlock", pet, context, 32)
    end, 30)
    S:MakeHandler("toilet", "Toilet", 84, function(pet, context)
        return S:UseFurniture("toilet", {"toilet"}, "Seat1", pet, context, 25)
    end, 30)
    S:MakeHandler("bored", "Bored", 68, function(pet, context)
        -- Historical piano route; no fabricated generic boredom-completion remote.
        return S:UseFurniture("bored", {"piano"}, "Seat1", pet, context, 32)
    end, 30)
    S:MakeHandler("pet_me", "Pet Me", 55, function(pet, context)
        local petChar = S:PetCharacter()
        if not petChar then return false, "Pet character unresolved" end
        local focus = S:Remote("AdoptAPI/FocusPet")
        local perf = S:Remote("PetAPI/ReplicateActivePerformances")
        local petted = S:Remote("PetAPI/PetPetted")
        local progress = S:Remote("AilmentsAPI/ProgressPetMeAilment")
        if not focus or not perf or not petted or not progress then return false, "Pet Me remotes unavailable" end
        local function wait(seconds)
            local untilAt = os.clock() + seconds
            while os.clock() < untilAt do
                if context:IsCancelled() or Game:GetCurrentPetUnique() ~= pet then return false end
                task.wait(0.1)
            end
            return true
        end
        local ok, why = S:Call(focus, petChar)
        if not ok then return false, why end
        S:Call(perf, petChar, {FocusPet = true})
        if not wait(1) then return false, "Cancelled" end
        S:Call(perf, petChar, {FocusPet = true, Petting = true})
        if not wait(3.7) then return false, "Cancelled" end
        S:Call(perf, petChar, {FocusPet = true, PettingHappy = true})
        if not wait(1.2) then return false, "Cancelled" end
        S:Call(perf, petChar, {FocusPet = true})
        ok, why = S:Call(petted, pet, game:GetService("Players").LocalPlayer)
        if not ok then return false, why end
        ok, why = S:Call(progress, pet)
        if not ok then return false, why end
        return S:WaitClear("pet_me", pet, context, 8)
    end, 45)
end
