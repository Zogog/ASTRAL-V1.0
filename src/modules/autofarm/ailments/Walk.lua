return function(ASTRAL)
    local S, Movement = assert(ASTRAL.NeedSupport), assert(ASTRAL.MovementSupport)
    return S:MakeHandler("walk", "Walk", 70, function(pet, context)
        return Movement:Move("walk", pet, context)
    end, 40)
end
