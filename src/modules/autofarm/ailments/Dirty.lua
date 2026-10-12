return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)
    return S:MakeHandler("dirty", "Dirty", 86, function(pet, context)
        return S:UseFurniture("dirty", {
            "modernshower", "cheap_pet_bathtub_tutorial", "cheappetbathtub", "cheap_pet_bathtub",
        }, "UseBlock", pet, context, 32)
    end, 30)
end
