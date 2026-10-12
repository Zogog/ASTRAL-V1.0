return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)
    return S:MakeHandler("pizza_party", "Pizza Party", 75, function(pet, context)
        return S:GoLocation("pizza_party", "PizzaShop", pet, context, 68)
    end, 35)
end
