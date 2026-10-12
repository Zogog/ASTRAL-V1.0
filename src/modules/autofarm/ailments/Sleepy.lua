return function(ASTRAL)
    local S, Game = assert(ASTRAL.NeedSupport), assert(ASTRAL.Game)
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
end
