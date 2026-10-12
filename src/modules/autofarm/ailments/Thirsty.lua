return function(ASTRAL)
    local Thirsty = {
        Id = "thirsty",
        Name = "Thirsty",
        Version = "0.1.0",
        Priority = 69,
    }

    function Thirsty:CanRun()
        return ASTRAL.Game:GetCurrentPetUnique() ~= nil
            and ASTRAL.Game:FindCompatibleInventoryEntry("thirsty") ~= nil
    end

    function Thirsty:Run(_, context)
        if not ASTRAL.Game:PetHasAilment("thirsty") then
            return true
        end

        local candidate = ASTRAL.Game:FindCompatibleInventoryEntry("thirsty")
        if not candidate then
            return false, "No compatible owned drink; purchase not attempted"
        end

        print("")
        print("[ASTRAL THIRSTY] Starting known-good v0.8.x consumable pipeline")
        print("[ASTRAL THIRSTY] item_kind=", candidate.item.kind)
        print("[ASTRAL THIRSTY] item_unique=", candidate.item.unique)
        print("[ASTRAL THIRSTY] uses=", candidate.uses)

        local ok, result = ASTRAL.Game:ConsumeForPetAilment("thirsty")
        if not ok then
            return false, result
        end

        local deadline = os.clock() + 15
        while os.clock() < deadline do
            if context:IsCancelled() then
                return false, "Cancelled"
            end

            if not ASTRAL.Game:PetHasAilment("thirsty") then
                print("[ASTRAL THIRSTY] Complete")
                return true
            end

            task.wait(0.2)
        end

        return false, "Timed out waiting for Thirsty completion"
    end

    ASTRAL.Ailments:Register(Thirsty)
    return Thirsty
end
