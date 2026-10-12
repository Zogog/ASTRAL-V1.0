return function(ASTRAL)
    local S, Game = assert(ASTRAL.NeedSupport), assert(ASTRAL.Game)
    local lastApplePurchase = -math.huge
    local function ownedApple()
        for _, item in pairs(Game:GetInventory().food or {}) do
            if type(item) == "table" and item.kind == "healing_apple" and item.unique then
                local props = item.properties
                if type(props) ~= "table" or tonumber(props.uses_left or 1) > 0 then return item end
            end
        end
    end
    return S:MakeHandler("sick", "Sick", 95, function(pet, context)
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
        local start, create = S:Remote("ToolAPI/ServerUseTool"), S:Remote("PetObjectAPI/CreatePetObject")
        if not start or not create then return false, "Food remotes unavailable" end
        local ok, why = S:Call(start, apple.unique, "START")
        if not ok then return false, why end
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
end
