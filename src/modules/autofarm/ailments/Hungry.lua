return function(ASTRAL)
    local Hungry = {
        Id = "hungry",
        Name = "Hungry",
        Version = "0.1.0",
        Priority = 70,
    }

    function Hungry:CanRun()
        return ASTRAL.Game:GetCurrentPetUnique() ~= nil
            and ASTRAL.Game:FindCompatibleInventoryEntry("hungry") ~= nil
    end

    function Hungry:Run(_, context)
        if not ASTRAL.Game:PetHasAilment("hungry") then
            return true
        end

        local candidate = ASTRAL.Game:FindCompatibleInventoryEntry("hungry")
        if not candidate then
            return false, "No compatible owned food; purchase not attempted"
        end

        print("")
        print("[ASTRAL HUNGRY] Starting known-good v0.8.x consumable pipeline")
        print("[ASTRAL HUNGRY] item_kind=", candidate.item.kind)
        print("[ASTRAL HUNGRY] item_unique=", candidate.item.unique)
        print("[ASTRAL HUNGRY] uses=", candidate.uses)

        local ok, result, usedCandidate = ASTRAL.Game:ConsumeForPetAilment("hungry")
        if not ok then
            return false, result
        end

        local deadline = os.clock() + 15
        while os.clock() < deadline do
            if context:IsCancelled() then
                return false, "Cancelled"
            end

            if not ASTRAL.Game:PetHasAilment("hungry") then
                print("[ASTRAL HUNGRY] Complete")
                return true
            end

            task.wait(0.2)
        end

        return false, "Timed out waiting for Hungry completion"
    end

    ASTRAL.Ailments:Register(Hungry)
    return Hungry
end
