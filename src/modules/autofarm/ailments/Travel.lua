-- ASTRAL dev.5: location / spatial rate ailments.
return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)
    local destinations = {
        {"school", "School", "School", 77},
        {"salon", "Salon", "Salon", 76},
        {"pizza_party", "Pizza Party", "PizzaShop", 75},
        {"cat_cafe", "Cat Cafe", "CatCafe", 74},
    }
    for _, item in ipairs(destinations) do
        local kind, name, destination, priority = item[1], item[2], item[3], item[4]
        S:MakeHandler(kind, name, priority, function(pet, context)
            return S:GoLocation(kind, destination, pet, context, 68)
        end, 35)
    end
    -- Coordinates from ASTRAL v0.8.3b, not universal navigation waypoints.
    S:MakeHandler("camping", "Camping", 73, function(pet, context)
        return S:GoSpatial("camping",
            CFrame.new(-13.855457, 37.460064, -1043.678223),
            CFrame.new(-17.754433, 36.286900, -1043.678955),
            pet, context)
    end, 35)
    S:MakeHandler("beach_party", "Beach Party", 72, function(pet, context)
        return S:GoSpatial("beach_party",
            CFrame.new(-555.260925, 30.385265, -1501.694458),
            CFrame.new(-555.247192, 28.914038, -1507.422852),
            pet, context)
    end, 35)
end
