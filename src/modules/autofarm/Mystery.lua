-- ASTRAL dev.5: Mystery choice using live game generator, never guessed slot indices.
return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)
    local Game = assert(ASTRAL.Game)
    local RS = game:GetService("ReplicatedStorage")
    local Fsys = require(RS:WaitForChild("Fsys"))
    local EquippedPets = Fsys.load("EquippedPets")
    local SECONDS = {
        hungry = 8, thirsty = 8, toilet = 7, bored = 20,
        walk = 30, ride = 30, school = 50, camping = 50,
        pizza_party = 50, beach_party = 50, salon = 50, cat_cafe = 50,
        play = 90, pet_me = 999,
    }
    local function getSlotsFunction()
        local ok, helper = pcall(function()
            return require(RS:WaitForChild("new"):WaitForChild("modules")
                :WaitForChild("Ailments"):WaitForChild("Helpers"):WaitForChild("MysteryHelper"))
        end)
        if not ok or type(helper) ~= "table" or type(helper.get_action) ~= "function" then
            return nil, "MysteryHelper unavailable"
        end
        if debug and type(debug.getupvalues) == "function" then
            local success, values = pcall(debug.getupvalues, helper.get_action)
            if success and type(values) == "table" then
                for key, fn in pairs(values) do
                    if type(fn) == "function" and tostring(key):find("ailment_slots", 1, true) then
                        return fn
                    end
                end
                if type(debug.getinfo) == "function" then
                    for _, fn in pairs(values) do
                        if type(fn) == "function" then
                            local got, info = pcall(debug.getinfo, fn)
                            if got and type(info) == "table"
                                and tostring(info.name or ""):find("ailment_slots", 1, true) then return fn end
                        end
                    end
                end
            end
        end
        if debug and type(debug.getupvalue) == "function" then
            for i = 1, 12 do
                local ok2, name, fn = pcall(debug.getupvalue, helper.get_action, i)
                if not ok2 or name == nil then break end
                if type(fn) == "function" and tostring(name):find("ailment_slots", 1, true) then
                    return fn
                end
            end
        end
        return nil, "Live get_ailment_slots closure unavailable"
    end
    S:MakeHandler("mystery", "Mystery", 98, function(pet, context)
        local present, ailment = Game:PetHasAilment("mystery")
        if not present then return true end
        local component = ailment and ailment.components and ailment.components.mystery
        local seed = component and tonumber(component.random_seed)
        if not seed then return false, "Mystery seed unavailable" end
        local wrapper = Game:GetEquippedPetWrappers()[1]
        if not wrapper then return false, "Equipped pet wrapper unavailable" end
        local okItem, item = pcall(function() return EquippedPets.get_item_from_wrapper(wrapper) end)
        if not okItem or type(item) ~= "table" then
            okItem, item = pcall(function() return EquippedPets.get_item_from_unique(pet) end)
        end
        if not okItem or type(item) ~= "table" then return false, "Pet context unavailable" end
        local petContext = {}
        for k, v in pairs(item) do petContext[k] = v end
        petContext.pet_id = petContext.pet_id or item.kind
        if not petContext.pet_id then return false, "Pet kind unavailable" end
        local generator, why = getSlotsFunction()
        if not generator then return false, why end
        local manager = Game:GetAilmentsManager()
        local active = {}
        local petAilments = manager and manager.ailments and manager.ailments[pet] or {}
        for key, value in pairs(petAilments) do
            local kind = type(value) == "table" and value.kind or key
            if type(kind) == "string" then active[kind] = true end
        end
        local generated, slots = pcall(generator, seed, active, petContext)
        if not generated or type(slots) ~= "table" then return false, "Mystery slot generation failed" end
        local bestIndex, bestKind, bestTime = nil, nil, math.huge
        for index = 1, 3 do
            local kind = slots[index]
            local supported = kind and ASTRAL.Ailments:Get(kind) and S:Ready(kind)
            local estimate = SECONDS[kind] or math.huge
            if supported and estimate < bestTime then
                bestIndex, bestKind, bestTime = index, kind, estimate
            end
        end
        if not bestIndex then return false, "No supported mystery choice" end
        if context:IsCancelled() then return false, "Cancelled" end
        S:Log("mystery: choosing " .. bestKind .. " (slot " .. bestIndex .. ")")
        local ok, err = S:Call(S:Remote("AilmentsAPI/ChooseMysteryAilment"), pet, "mystery", bestIndex, bestKind)
        if not ok then return false, err end
        local deadline = os.clock() + 5
        while os.clock() < deadline do
            if context:IsCancelled() then return false, "Cancelled" end
            if Game:GetCurrentPetUnique() ~= pet then return false, "Pet changed" end
            if not Game:PetHasAilment("mystery") and Game:PetHasAilment(bestKind) then
                S:Log("mystery: resolved into " .. bestKind .. "; scheduler will handle it next")
                return true
            end
            task.wait(0.15)
        end
        return false, "Mystery did not resolve into " .. bestKind
    end, 45)
end
