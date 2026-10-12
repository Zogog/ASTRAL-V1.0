return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)
    return S:MakeHandler("salon", "Salon", 76, function(pet, context)
        return S:GoLocation("salon", "Salon", pet, context, 68)
    end, 35)
end
