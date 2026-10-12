-- ASTRAL dev.6 shared pet inventory, lifecycle and equip API.
-- Migrates the controlled v0.8.3b pet lifecycle/equip path into the modular core.
return function(ASTRAL)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
    local load = Fsys.load

    local ClientData = load("ClientData")
    local EquippedPets = load("EquippedPets")
    local InventoryDB = load("InventoryDB")
    local PetProgressionDB = load("PetProgressionDB")
    local SharedConstants = load("SharedConstants")

    local PetAPI = {
        Version = "0.1.2-dev.6.8-growth-eta",
    }

    local function properties(item)
        return type(item) == "table" and type(item.properties) == "table"
            and item.properties or {}
    end

    function PetAPI:GetItem(unique)
        if not unique then return nil end
        local ok, item = pcall(function()
            return EquippedPets.get_item_from_unique(unique)
        end)
        if ok and type(item) == "table" then return item end

        local pets = (ASTRAL.Game:GetInventory() or {}).pets
        if type(pets) == "table" then
            for _, candidate in pairs(pets) do
                if type(candidate) == "table" and candidate.unique == unique then
                    return candidate
                end
            end
        end
        return nil
    end

    function PetAPI:GetName(item, wrapper)
        local name
        if item then pcall(function() name = EquippedPets.get_name(item) end) end
        if not name and wrapper then
            pcall(function() name = EquippedPets.get_name_from_wrapper(wrapper) end)
        end
        local definition = item and item.kind and InventoryDB.pets
            and InventoryDB.pets[item.kind] or nil
        return name
            or (properties(item).name)
            or (definition and definition.name)
            or (item and item.kind)
            or "Unknown Pet"
    end

    function PetAPI:Describe(item, wrapper)
        if type(item) ~= "table" then return nil end
        local props = properties(item)
        local definition = item.kind and InventoryDB.pets
            and InventoryDB.pets[item.kind] or nil
        local age = tonumber(props.age)
        local xp = tonumber(props.xp) or 0
        local friendship = tonumber(props.friendship_level) or 0
        local isEgg = definition and definition.is_egg == true or false
        local targetXP, mode

        if isEgg then
            targetXP = tonumber(definition and definition.xp_to_hatch)
            mode = "EGG"
        elseif age and age < 6 then
            local ok, thresholds = pcall(function()
                return PetProgressionDB.get_xp_per_age(definition)
            end)
            if ok and type(thresholds) == "table" then
                targetXP = tonumber(thresholds[age])
            end
            mode = "AGING"
        elseif age and age >= 6 then
            targetXP = tonumber(SharedConstants.xp_per_friendship_level)
            mode = "FRIENDSHIP"
        end

        return {
            item = item,
            wrapper = wrapper,
            unique = item.unique,
            kind = item.kind,
            name = self:GetName(item, wrapper),
            age = age,
            xp = xp,
            friendship = friendship,
            targetXP = targetXP,
            mode = mode,
            isEgg = isEgg,
            isFullGrown = age ~= nil and age >= 6,
        }
    end

    -- Return the exact XP still required to reach age 6 (Full Grown).
    -- This deliberately uses Adopt Me's own PetProgressionDB thresholds rather
    -- than hard-coded rarity totals, so Pet Pens and future progression UIs
    -- share the same source of truth as Describe().
    function PetAPI:GetRemainingGrowthXP(petOrItem)
        if type(petOrItem) ~= "table" then return nil end

        local pet = petOrItem.item and petOrItem or self:Describe(petOrItem)
        if not pet or pet.isEgg or pet.age == nil then return nil end
        if pet.age >= 6 then return 0 end

        local item = pet.item or petOrItem
        local definition = item.kind and InventoryDB.pets
            and InventoryDB.pets[item.kind] or nil
        if not definition then return nil end

        local ok, thresholds = pcall(function()
            return PetProgressionDB.get_xp_per_age(definition)
        end)
        if not ok or type(thresholds) ~= "table" then return nil end

        local currentTarget = tonumber(thresholds[pet.age])
        if not currentTarget then return nil end

        local remaining = math.max(0, currentTarget - (tonumber(pet.xp) or 0))
        for age = pet.age + 1, 5 do
            local stageXP = tonumber(thresholds[age])
            if not stageXP then return nil end
            remaining += stageXP
        end
        return remaining
    end

    function PetAPI:GetCurrent()
        local wrapper = ASTRAL.Game:GetEquippedPetWrappers()[1]
        if not wrapper then return nil end
        local item
        pcall(function() item = EquippedPets.get_item_from_wrapper(wrapper) end)
        if not item and wrapper.pet_unique then item = self:GetItem(wrapper.pet_unique) end
        return item and self:Describe(item, wrapper) or nil
    end

    function PetAPI:GetPenAssigned()
        local assigned = {}
        local ok, manager = pcall(function()
            return ClientData.get("idle_progression_manager")
        end)
        if ok and type(manager) == "table" and type(manager.active_pets) == "table" then
            for unique in pairs(manager.active_pets) do assigned[unique] = true end
        end
        return assigned
    end

    function PetAPI:GetPets()
        local result = {}
        local pets = (ASTRAL.Game:GetInventory() or {}).pets
        if type(pets) ~= "table" then return result end
        for _, item in pairs(pets) do
            if type(item) == "table" and item.unique then
                local pet = self:Describe(item)
                if pet then table.insert(result, pet) end
            end
        end
        return result
    end

    function PetAPI:GetGrowablePets(options)
        options = options or {}
        local currentUnique = options.currentUnique
        local penAssigned = options.includePenPets and {} or self:GetPenAssigned()
        local result = {}

        for _, pet in ipairs(self:GetPets()) do
            if pet.unique
                and pet.unique ~= currentUnique
                and not pet.isEgg
                and pet.age ~= nil
                and pet.age < 6
                and not penAssigned[pet.unique] then
                table.insert(result, pet)
            end
        end

        -- Deterministic default queue: finish the most-developed pets first.
        table.sort(result, function(a, b)
            if a.age == b.age then
                if a.xp == b.xp then return tostring(a.unique) < tostring(b.unique) end
                return a.xp > b.xp
            end
            return a.age > b.age
        end)
        return result
    end

    function PetAPI:Equip(unique)
        if not unique then return false, "Pet unique missing" end
        local remote = ASTRAL.Game:GetRemote("ToolAPI/Equip")
        if not remote then return false, "ToolAPI/Equip unavailable" end

        local ok, err = pcall(function()
            remote:InvokeServer(unique, {
                use_sound_delay = true,
                equip_as_last = false,
            })
        end)
        if not ok then return false, tostring(err) end

        local deadline = os.clock() + 5
        while os.clock() < deadline do
            if ASTRAL.Game:GetCurrentPetUnique() == unique then
                return true
            end
            task.wait(0.2)
        end
        return false, "Equip call returned but new pet was not confirmed"
    end

    -- Recovery for a pet left in a stale furniture interaction. The player
    -- manually verified that unequipping and re-equipping the same pet allows
    -- a rejected Sleepy interaction to progress. Pet unequip remote arguments
    -- are not yet captured independently; verify the state transition.
    function PetAPI:ResetFurnitureInteraction(expectedUnique)
        local Game = ASTRAL.Game
        if not expectedUnique or Game:GetCurrentPetUnique() ~= expectedUnique then
            return false, "Equipped pet changed before reset"
        end
        local unequip = Game:GetRemote("ToolAPI/Unequip")
        if not unequip then return false, "ToolAPI/Unequip unavailable" end

        local ok, err = pcall(function()
            unequip:InvokeServer(expectedUnique)
        end)
        if not ok then return false, "Pet unequip remote failed: " .. tostring(err) end

        local deadline = os.clock() + 2
        local unequipped = false
        while os.clock() < deadline do
            if Game:GetCurrentPetUnique() ~= expectedUnique then
                unequipped = true
                break
            end
            task.wait(0.15)
        end
        if not unequipped then
            return false, "Pet unequip not confirmed; equip skipped"
        end

        local equipped, reason = self:Equip(expectedUnique)
        if not equipped then
            return false, "Pet re-equip failed: " .. tostring(reason)
        end
        return true
    end

    ASTRAL.Pets = PetAPI
    return PetAPI
end
