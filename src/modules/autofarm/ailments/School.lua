return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)
    return S:MakeHandler("school", "School", 77, function(pet, context)
        return S:GoLocation("school", "School", pet, context, 68)
    end, 35)
end
