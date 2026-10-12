-- ASTRAL dev.4 feeding extension. Loaded after GameAPI, before ailment handlers.
-- Keeps dev.3 Play behaviour untouched.
return function(ASTRAL)
    local Game = assert(ASTRAL.Game, "GameAPI must load before FeedingAPI")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ClientData = require(ReplicatedStorage:WaitForChild("Fsys")).load("ClientData")
    local player = Players.LocalPlayer

    local FALLBACK = {
        hungry = "schospital_refresh_2023_cafeteria_sandwich",
        thirsty = "water",
    }
    local BOWLS = {
        hungry = { pet_food_bowl = true, petfoodbowl = true },
        thirsty = { pet_water_bowl = true, petwaterbowl = true },
    }

    local function safeGet(key)
        local ok, result = pcall(function() return ClientData.get(key) end)
        if ok then return result end
    end

    local function petModel()
        local pets = workspace:FindFirstChild("Pets")
        if not pets then return nil end
        -- A model target is required by the observed furniture UseBlock call.
        -- Do not guess if multiple pets are present.
        local selected
        for _, child in ipairs(pets:GetChildren()) do
            if child:IsA("Model") then
                if selected then return nil end
                selected = child
            end
        end
        return selected
    end

    local function activeHouseSlot()
        -- ClientData schemas vary. Only accept an explicit numeric house slot;
        -- never hard-code the previously observed slot 5.
        for _, key in ipairs({ "house_interior", "house", "housing" }) do
            local value = safeGet(key)
            if type(value) == "table" then
                for _, field in ipairs({ "house_id", "houseId", "active_house_id", "active_house_slot" }) do
                    local id = tonumber(value[field])
                    if id and id >= 1 and id % 1 == 0 then return id end
                end
            end
        end
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
        if not BOWLS[kind] or not petUnique then return false, "Unknown need" end
        local interiors = workspace:FindFirstChild("HouseInteriors")
        if not interiors then return false, "Not inside a loaded house" end
        local slot = activeHouseSlot()
        if not slot then return false, "Active house slot unresolved" end
        local getFurniture = self:GetRemote("HousingAPI/GetFurnitureWithinHouse")
        local activate = self:GetRemote("HousingAPI/ActivateFurniture")
        if not getFurniture or not activate then return false, "House remotes unavailable" end
        local ok, furniture = pcall(function() return getFurniture:InvokeServer(slot) end)
        if not ok or type(furniture) ~= "table" then return false, "Furniture lookup failed" end
        local bowlUnique
        for _, wrapper in pairs(furniture) do
            local data = type(wrapper) == "table" and (wrapper.data or wrapper) or nil
            if type(data) == "table" and type(data.unique) == "string"
                and BOWLS[kind][string.lower(tostring(data.id or ""))] then
                bowlUnique = data.unique
                break
            end
        end
        if not bowlUnique then return false, "No compatible house bowl" end
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local target = petModel()
        if not root or not target then return false, "Character/pet model unresolved" end
        local used, result = pcall(function()
            return activate:InvokeServer(player, bowlUnique, "UseBlock", {
                cframe = root.CFrame,
            }, target)
        end)
        if not used or result == false then return false, tostring(result) end
        return true
    end

    return Game
end
