return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)
    return S:MakeHandler("camping", "Camping", 73, function(pet, context)
        return S:GoSpatial("camping",
            CFrame.new(-13.855457, 37.460064, -1043.678223),
            CFrame.new(-17.754433, 36.286900, -1043.678955), pet, context)
    end, 35)
end
