return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)
    return S:MakeHandler("toilet", "Toilet", 84, function(pet, context)
        return S:UseFurniture("toilet", {"toilet"}, "Seat1", pet, context, 25)
    end, 30)
end
