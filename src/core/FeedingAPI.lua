-- ASTRAL dev.4 feeding extension. Loaded after GameAPI, before ailment handlers.
-- Keeps dev.3 Play behaviour untouched.
return function(ASTRAL)
    local Game = assert(ASTRAL.Game, "GameAPI must load before FeedingAPI")
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer

    local FALLBACK = {
        hungry = "schospital_refresh_2023_cafeteria_sandwich",
        thirsty = "water",
    }
    local BOWLS = {
        hungry = { "pet_food_bowl", "petfoodbowl" },
        thirsty = { "pet_water_bowl", "petwaterbowl" },
    }

    local function petModel()
        local wrappers = Game:GetEquippedPetWrappers()
        local wrapper = wrappers and wrappers[1]
        if wrapper and typeof(wrapper.char) == "Instance" then return wrapper.char end
        return nil
    end

    function Game:FindCompatibleConsumable(kind)
        if not FALLBACK[kind] then return nil end
        local candidate = self:FindCompatibleInventoryEntry(kind, "food")
        if candidate and candidate.item and candidate.item.unique then
            local props = candidate.item.properties
            if type(props) ~= "table" or props.uses_left == nil
                or tonumber(props.uses_left) == nil or tonumber(props.uses_left) > 0 then
                return candidate
            end
        end
        -- The older game definitions don't always tag water/sandwich with an
        -- ailment. The historically observed exact item kind is a safe fallback.
        local food = self:GetInventory().food
        if type(food) ~= "table" then return nil end
        for _, item in pairs(food) do
            if type(item) == "table" and item.kind == FALLBACK[kind] and item.unique then
                local props = item.properties
                if type(props) ~= "table" or props.uses_left == nil
                    or tonumber(props.uses_left) == nil or tonumber(props.uses_left) > 0 then
                    return { item = item, category = "food", uses = self:InventoryItemQuantity(item) }
                end
            end
        end
        return nil
    end

    function Game:BuyConsumable(kind)
        local itemKind = FALLBACK[kind]
        if not itemKind then return false, "Unknown ailment" end
        local buy = self:GetRemote("ShopAPI/BuyItem")
        if not buy then return false, "BuyItem remote unavailable" end
        local ok, result = pcall(function()
            return buy:InvokeServer("food", itemKind, { buy_count = 1 })
        end)
        if not ok or result == false then return false, tostring(result) end
        return true
    end

    function Game:UsePetConsumable(petUnique, candidate)
        local item = candidate and (candidate.item or candidate)
        if not item or not item.unique or not petUnique then
            return false, "No valid pet/item"
        end
        local start = self:GetRemote("ToolAPI/ServerUseTool")
        local create = self:GetRemote("PetObjectAPI/CreatePetObject")
        if not start or not create then return false, "Food remotes unavailable" end
        local ok, err = pcall(function()
            start:InvokeServer(item.unique, "START")
            task.wait(0.25)
            create:InvokeServer("__Enum_PetObjectCreatorType_2", {
                pet_unique = petUnique,
                unique_id = item.unique,
                additional_consume_uniques = {},
            })
        end)
        if not ok then return false, tostring(err) end
        -- The normal client pet entity is expected to consume the object.
        -- The ailment handler checks actual completion; a successful remote
        -- invocation is not treated as proof of completion.
        return true
    end

    function Game:TryUseNeedBowl(kind, petUnique)
        local ids = BOWLS[kind]
        if not ids or not petUnique then return false, "Unknown need" end
        local Furniture = ASTRAL.Furniture
        if not Furniture then return false, "FurnitureAPI unavailable" end
        local furniture, reason = Furniture:Find(ids)
        if not furniture then return false, reason end
        local activate = self:GetRemote("HousingAPI/ActivateFurniture")
        if not activate then return false, "ActivateFurniture unavailable" end
        local target = petModel()
        local root = target and (target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart)
        if not root or not target then return false, "Equipped pet model unresolved" end
        print(string.format("[ASTRAL FEEDING] %s: using %s from house slot %d",
            kind, tostring(furniture.id), furniture.slot))
        local used, result = pcall(function()
            return activate:InvokeServer(player, furniture.unique, "UseBlock", {
                cframe = root.CFrame,
            }, target)
        end)
        if not used or result == false then return false, tostring(result) end
        return true
    end

    return Game
end
