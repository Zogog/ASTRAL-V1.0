-- ASTRAL dev.6.8.2 Bored Playground hotfix.
-- Match Dusk & Shine's Playground route: create an anchored 200x5x200
-- support platform 2.5 studs below BoredAilmentTarget, then stand the
-- player/pet six studs above the platform centre while Bored progresses.
return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)

    local function getPlatform(targetCF)
        local terrain = workspace:FindFirstChildOfClass("Terrain") or workspace
        local platform = terrain:FindFirstChild("ASTRAL_BoredPlatform")

        if not platform or not platform:IsA("BasePart") then
            if platform then platform:Destroy() end
            platform = Instance.new("Part")
            platform.Name = "ASTRAL_BoredPlatform"
            platform.Anchored = true
            platform.CanCollide = true
            platform.CanTouch = true
            platform.CanQuery = true
            platform.Size = Vector3.new(200, 5, 200)
            platform.Material = Enum.Material.SmoothPlastic
            platform.Transparency = 0.5
            platform.CastShadow = false
            platform.Parent = terrain
        end

        -- D&S V648("Playground"): BoredAilmentTarget.Position + (0,-2.5,0).
        -- With a 5-stud-thick platform, its top face is exactly target Y.
        platform.CFrame = CFrame.new(targetCF.Position + Vector3.new(0, -2.5, 0))
        return platform
    end

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

        local platform = getPlatform(targetCF)
        local playerCF = CFrame.new(platform.Position + Vector3.new(0, 6, 0))
        local petCF = playerCF * CFrame.new(4, 0, 0)

        S:Log("bored: Playground support platform ready")
        S:Log("bored: moving player/pet onto Playground platform")
        return S:GoSpatial("bored", playerCF, petCF, pet, context)
    end, 30)
end
