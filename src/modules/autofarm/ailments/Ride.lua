return function(ASTRAL)
    local S, Movement = assert(ASTRAL.NeedSupport), assert(ASTRAL.MovementSupport)
    return S:MakeHandler("ride", "Ride", 69, function(pet, context)
        return Movement:Move("ride", pet, context)
    end, 40)
end
