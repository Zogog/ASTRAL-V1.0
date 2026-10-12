return function(ASTRAL)
    local S, Game = assert(ASTRAL.NeedSupport), assert(ASTRAL.Game)
    return S:MakeHandler("pet_me", "Pet Me", 55, function(pet, context)
        local petChar = S:PetCharacter()
        if not petChar then return false, "Pet character unresolved" end
        local focus = S:Remote("AdoptAPI/FocusPet")
        local perf = S:Remote("PetAPI/ReplicateActivePerformances")
        local petted = S:Remote("PetAPI/PetPetted")
        local progress = S:Remote("AilmentsAPI/ProgressPetMeAilment")
        if not focus or not perf or not petted or not progress then return false, "Pet Me remotes unavailable" end
        local function wait(seconds)
            local untilAt = os.clock() + seconds
            while os.clock() < untilAt do
                if context:IsCancelled() or Game:GetCurrentPetUnique() ~= pet then return false end
                task.wait(0.1)
            end
            return true
        end
        local ok, why = S:Call(focus, petChar)
        if not ok then return false, why end
        S:Call(perf, petChar, {FocusPet = true})
        if not wait(1) then return false, "Cancelled" end
        S:Call(perf, petChar, {FocusPet = true, Petting = true})
        if not wait(3.7) then return false, "Cancelled" end
        S:Call(perf, petChar, {FocusPet = true, PettingHappy = true})
        if not wait(1.2) then return false, "Cancelled" end
        S:Call(perf, petChar, {FocusPet = true})
        ok, why = S:Call(petted, pet, game:GetService("Players").LocalPlayer)
        if not ok then return false, why end
        ok, why = S:Call(progress, pet)
        if not ok then return false, why end
        return S:WaitClear("pet_me", pet, context, 8)
    end, 45)
end
