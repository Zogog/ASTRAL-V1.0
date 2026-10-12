-- ASTRAL dev.6.8.1 Bored hotfix.
-- Dusk & Shine 4.1.3 does not solve Bored with owned piano furniture.
-- It moves the player/pet to MainMap's Park.BoredAilmentTarget ("Playground")
-- and waits there for the location-based ailment to clear.
return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)

    return S:MakeHandler("bored", "Bored", 68, function(pet, context)
        local staticMap = workspace:FindFirstChild("StaticMap")
        local park = staticMap and staticMap:FindFirstChild("Park")
        local target = park and park:FindFirstChild("BoredAilmentTarget")
        if not target then
            return false, "Playground BoredAilmentTarget unavailable"
        end

        local targetCF
        if target:IsA("Model") then
            targetCF = target:GetPivot()
        elseif target:IsA("BasePart") then
            targetCF = target.CFrame
        else
            return false, "Unsupported BoredAilmentTarget type"
        end

        -- D&S places its Playground platform 2.5 studs below the target,
        -- then positions the player 6 studs above that platform. Preserve the
        -- same effective +3.5 stud height and keep the pet alongside.
        local playerCF = targetCF + Vector3.new(0, 3.5, 0)
        local petCF = playerCF * CFrame.new(4, 0, 0)

        S:Log("bored: moving to Playground BoredAilmentTarget")
        return S:GoSpatial("bored", playerCF, petCF, pet, context)
    end, 30)
end
