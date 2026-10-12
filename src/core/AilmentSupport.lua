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
    local S = { Cooldowns = {}, Version = "0.1.0-dev.5" }

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
        local wrappers = Game:GetEquippedPetWrappers()
        local wrapper = wrappers and wrappers[1]
        if wrapper and typeof(wrapper.char) == "Instance" then return wrapper.char end
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
        -- Optional explicit setting, for the user's own verified house slot.
        local configSlot = tonumber(ASTRAL.Config and ASTRAL.Config.HouseSlot)
        if configSlot and configSlot > 0 and configSlot % 1 == 0 then return configSlot end
        for _, key in ipairs({"house_interior", "house", "housing", "house_slots"}) do
            local ok, data = pcall(function() return ClientData.get(key) end)
            if ok and type(data) == "table" then
                for _, field in ipairs({"active_house_slot", "active_house_id", "house_id", "houseId"}) do
                    local slot = tonumber(data[field])
                    if slot and slot > 0 and slot % 1 == 0 then return slot end
                end
            end
        end
        return nil
    end
    function S:HouseFurniture(ids)
        local slot = self:HouseSlot()
        if not slot then return nil, "House slot unknown (set ASTRAL.Config.HouseSlot for your own house)" end
        local remote = self:Remote("HousingAPI/GetFurnitureWithinHouse")
        if not remote then return nil, "Furniture lookup remote missing" end
        local ok, records = pcall(function() return remote:InvokeServer(slot) end)
        if not ok or type(records) ~= "table" then return nil, "House furniture query failed" end
        local wanted = {}
        for _, id in ipairs(ids) do wanted[string.lower(id)] = true end
        for _, wrapper in pairs(records) do
            local data = type(wrapper) == "table" and (wrapper.data or wrapper) or nil
            if type(data) == "table" and type(data.unique) == "string"
                and wanted[string.lower(tostring(data.id or ""))] then
                return data
            end
        end
        return nil, "Required furniture not owned: " .. table.concat(ids, ", ")
    end
    function S:UseFurniture(kind, ids, interaction, petUnique, context, timeout)
        local furniture, reason = self:HouseFurniture(ids)
        if not furniture then return false, reason end
        local root, petChar = self:PetRoot()
        if not root or not petChar then return false, "Equipped pet model unavailable" end
        local remote = self:Remote("HousingAPI/ActivateFurniture")
        self:Log(kind .. ": using furniture " .. tostring(furniture.id) .. " / " .. tostring(interaction or "UseBlock"))
        local used, err = self:Call(remote, Player, furniture.unique, interaction or "UseBlock", { cframe = root.CFrame }, petChar)
        if not used then return false, err end
        return self:WaitClear(kind, petUnique, context, timeout or 30)
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
