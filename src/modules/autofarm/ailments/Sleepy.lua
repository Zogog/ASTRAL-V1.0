return function(ASTRAL)
    local S, Game = assert(ASTRAL.NeedSupport), assert(ASTRAL.Game)
    local Furniture = assert(ASTRAL.Furniture)
    return S:MakeHandler("sleepy", "Sleepy", 88, function(pet, context)
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
            local bed, reason = Furniture:FindMatching(function(record)
                return tostring(record.id or ""):lower():find("bed", 1, true) ~= nil
            end, "owned furniture id containing 'bed'")
            if not bed then return false, reason end

            local root, petChar = S:PetRoot()
            if not root or not petChar then return false, "Equipped pet model unavailable" end
            local remote = S:Remote("HousingAPI/ActivateFurniture")
            S:Log("sleepy: egg using " .. tostring(bed.id) .. " from slot " .. tostring(bed.slot) .. " / Seat1")
            local used, err = S:Call(remote, game:GetService("Players").LocalPlayer,
                bed.unique, "Seat1", { cframe = root.CFrame }, petChar)
            if not used then return false, err end
            return S:WaitClear("sleepy", pet, context, 32)
        end

        return S:UseFurniture("sleepy", {"basiccrib"}, "UseBlock", pet, context, 32)
    end, 30)
end
