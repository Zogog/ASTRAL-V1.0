return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)
    return S:MakeHandler("beach_party", "Beach Party", 72, function(pet, context)
        return S:GoSpatial("beach_party",
            CFrame.new(-555.260925, 30.385265, -1501.694458),
            CFrame.new(-555.247192, 28.914038, -1507.422852), pet, context)
    end, 35)
end
