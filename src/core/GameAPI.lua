return function(ASTRAL)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
    local load = Fsys.load

    local ClientData = load("ClientData")
    local EquippedPets = load("EquippedPets")
    local InventoryDB = load("InventoryDB")
    local RouterClient = load("RouterClient")

    local GameAPI = {
        Ready = true,
        Version = "0.1.2-dev.6.5.1-ds-wrapper",
        Remotes = {},
    }

    function GameAPI:GetRemote(name)
        if self.Remotes[name] then
            return self.Remotes[name]
        end

        local ok, remote = pcall(function()
            return RouterClient.get(name)
        end)

        if not ok or not remote then
            warn("[ASTRAL GAME API] Could not resolve remote:", name, remote)
            return nil
        end

        self.Remotes[name] = remote
        return remote
    end

    function GameAPI:GetAilmentsManager()
        local ok, manager = pcall(function()
            return ClientData.get("ailments_manager")
        end)

        if ok then
            return manager
        end

        return nil
    end

    function GameAPI:GetEquippedPetWrappers()
        local ok, wrappers = pcall(function()
            return EquippedPets.get_my_equipped_char_wrappers()
        end)

        if ok and type(wrappers) == "table" then
            return wrappers
        end

        return {}
    end

    function GameAPI:GetCurrentPetUnique()
        local wrapper = self:GetEquippedPetWrappers()[1]
        return wrapper and wrapper.pet_unique
    end

    function GameAPI:GetPetCharWrapper(petUnique)
        petUnique = petUnique or self:GetCurrentPetUnique()
        if not petUnique then return nil end

        -- D&S 4.1.3 sources the physical pet model from ClientData's
        -- pet_char_wrappers, not from the EquippedPets helper.
        local ok, wrappers = pcall(function()
            local data = ClientData.get_data and ClientData.get_data() or nil
            return (type(data) == "table" and data.pet_char_wrappers)
                or ClientData.get("pet_char_wrappers")
        end)

        if ok and type(wrappers) == "table" then
            for _, wrapper in pairs(wrappers) do
                if type(wrapper) == "table"
                    and wrapper.pet_unique == petUnique
                    and typeof(wrapper.char) == "Instance"
                    and wrapper.char.Parent then
                    return wrapper
                end
            end
        end

        return nil
    end

    function GameAPI:GetPetCharacter(petUnique)
        local wrapper = self:GetPetCharWrapper(petUnique)
        return wrapper and wrapper.char or nil
    end

    function GameAPI:GetInventory()
        local ok, inventory = pcall(function()
            return ClientData.get("inventory")
        end)

        if ok and type(inventory) == "table" then
            return inventory
        end

        return {}
    end

    function GameAPI:GetDefinition(category, item)
        if type(item) ~= "table" or not item.kind then
            return nil
        end

        local dbCategory = InventoryDB[category]
        if type(dbCategory) == "table" then
            return dbCategory[item.kind]
        end

        return nil
    end

    local function findAilmentMention(value, kind, path, depth)
        path = path or "definition"
        depth = depth or 0

        if depth > 4 then
            return nil
        end

        if type(value) == "string" then
            return value == kind and path or nil
        end

        if type(value) ~= "table" then
            return nil
        end

        for key, child in pairs(value) do
            local childPath = path .. "." .. tostring(key)

            if key == kind and child then
                return childPath
            end

            local found = findAilmentMention(child, kind, childPath, depth + 1)
            if found then
                return found
            end
        end

        return nil
    end

    function GameAPI:DefinitionMatchesAilment(definition, kind)
        if type(definition) ~= "table" then
            return false
        end

        for _, field in ipairs({
            "ailment_to_boost",
            "ailments_to_boost",
            "consumable",
            "use",
        }) do
            if findAilmentMention(
                definition[field],
                kind,
                "definition." .. field
            ) then
                return true
            end
        end

        return false
    end

    function GameAPI:InventoryItemQuantity(item)
        if type(item) ~= "table" then
            return 1
        end

        local properties = item.properties
        if type(properties) == "table" then
            local uses = tonumber(properties.uses_left)
            if uses and uses > 0 then
                return uses
            end
        end

        local uses = tonumber(item.uses_left)
        if uses and uses > 0 then
            return uses
        end

        return 1
    end

    function GameAPI:FindCompatibleInventoryEntry(kind, requiredCategory)
        local inventory = self:GetInventory()
        local candidates = {}

        for category, items in pairs(inventory) do
            if (not requiredCategory or category == requiredCategory)
                and type(items) == "table" then

                for _, item in pairs(items) do
                    if type(item) == "table" and item.kind and item.unique then
                        local definition = self:GetDefinition(category, item)

                        if self:DefinitionMatchesAilment(definition, kind) then
                            table.insert(candidates, {
                                item = item,
                                category = category,
                                definition = definition,
                                uses = self:InventoryItemQuantity(item),
                            })
                        end
                    end
                end
            end
        end

        table.sort(candidates, function(a, b)
            if a.uses == b.uses then
                return tostring(a.item.kind) < tostring(b.item.kind)
            end
            return a.uses > b.uses
        end)

        return candidates[1]
    end

    function GameAPI:FindPlayToy()
        local candidate = self:FindCompatibleInventoryEntry("play", "toys")
        if candidate then
            return candidate
        end

        -- Verified v0.8.3b fallback from the controlled Play capture.
        local toys = self:GetInventory().toys
        if type(toys) == "table" then
            for _, item in pairs(toys) do
                if type(item) == "table"
                    and item.kind == "squeaky_bone_default"
                    and item.unique then

                    return {
                        item = item,
                        category = "toys",
                        definition = self:GetDefinition("toys", item),
                        uses = self:InventoryItemQuantity(item),
                    }
                end
            end
        end

        return nil
    end

    function GameAPI:PetHasAilment(kind)
        local manager = self:GetAilmentsManager()
        local petUnique = self:GetCurrentPetUnique()

        if not manager
            or not petUnique
            or type(manager.ailments) ~= "table" then
            return false
        end

        local petAilments = manager.ailments[petUnique]
        if type(petAilments) ~= "table" then
            return false
        end

        for key, ailment in pairs(petAilments) do
            if type(ailment) == "table"
                and (ailment.kind == kind or key == kind) then
                return true, ailment
            end
        end

        return false
    end

    function GameAPI:GetAilmentProgress(kind)
        local present, ailment = self:PetHasAilment(kind)
        if not present or type(ailment) ~= "table" then
            return nil
        end

        return tonumber(ailment.progress) or 0
    end

    function GameAPI:ThrowPlayToy(toyUnique, petUnique, petCharacter)
        -- Dusk & Shine 4.1.3 path: create the throw object specifically for
        -- the target pet, then make that pet grab and drop the spawned object.
        local createPetObject = self:GetRemote("PetObjectAPI/CreatePetObject")
        local grabPetObject = self:GetRemote("PetObjectAPI/GrabPetObject")
        local dropPetObject = self:GetRemote("PetObjectAPI/DropPetObject")

        if not createPetObject or not grabPetObject or not dropPetObject then
            return false, "Required D&S Play remote(s) unavailable"
        end
        if not petUnique or not petCharacter then
            return false, "Pet identity/model unavailable for D&S Play"
        end

        local created = createPetObject:InvokeServer(
            "__Enum_PetObjectCreatorType_1",
            {
                reaction_name = "ThrowToyReaction",
                unique_id = toyUnique,
                pet_unique = petUnique,
            }
        )

        local object = typeof(created) == "Instance"
            and (created:FindFirstChild("Model") or created)
            or nil

        -- D&S also searches Workspace.PetObjects because CreatePetObject may
        -- return no Instance even though the server created the object.
        if not object then
            local petObjects = workspace:FindFirstChild("PetObjects")
            local deadline = os.clock() + 0.5
            repeat
                if petObjects then
                    for _, child in ipairs(petObjects:GetChildren()) do
                        local itemUnique = child:FindFirstChild("ItemUniqueId")
                        if itemUnique and itemUnique.Value == toyUnique then
                            object = child:FindFirstChild("Model") or child
                            break
                        end
                    end
                end
                if not object then task.wait(0.05) end
            until object or os.clock() >= deadline
        end

        if not object then
            return false, "D&S Play object was not created/found"
        end

        grabPetObject:FireServer(petCharacter, object)
        task.wait(0.3)
        dropPetObject:FireServer(petCharacter)

        -- Match D&S's local cleanup after the grab/drop reaction has fired.
        pcall(function()
            if object and object.Parent then object:Destroy() end
        end)

        return true, object
    end

    function GameAPI:CleanupPlayToy()
        -- D&S's Play path does not use ToolAPI START/END or Unequip.
        -- The spawned pet object is cleaned up immediately after Grab/Drop.
    end

    ASTRAL.Game = GameAPI
    return GameAPI
end
