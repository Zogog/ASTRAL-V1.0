return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)
    return S:MakeHandler("cat_cafe", "Cat Cafe", 74, function(pet, context)
        return S:GoLocation("cat_cafe", "CatCafe", pet, context, 68)
    end, 35)
end
