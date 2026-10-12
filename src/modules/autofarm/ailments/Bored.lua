return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)
    return S:MakeHandler("bored", "Bored", 68, function(pet, context)
        return S:UseFurniture("bored", {"piano"}, "Seat1", pet, context, 32)
    end, 30)
end
