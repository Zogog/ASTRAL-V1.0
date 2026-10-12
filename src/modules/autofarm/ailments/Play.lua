return function(ASTRAL)
    local Play = {
        Id = "play",
        Name = "Play",
        Version = "0.1.0",
        Priority = 50,
    }

    function Play:CanRun()
        return ASTRAL.Game:GetCurrentPetUnique() ~= nil
            and ASTRAL.Game:FindPlayToy() ~= nil
    end

    function Play:Run(_, context)
        if not ASTRAL.Game:PetHasAilment("play") then
            return true
        end

        local petUnique = ASTRAL.Game:GetCurrentPetUnique()
        if not petUnique then
            return false, "No equipped pet"
        end

        local candidate = ASTRAL.Game:FindPlayToy()
        if not candidate or not candidate.item then
            return false, "No compatible owned Play toy"
        end

        local toy = candidate.item
        local throwCount = 0
        local deadline = os.clock() + 55

        print("")
        print("[ASTRAL PLAY] Starting verified v0.8.3b Play pipeline")
        print("[ASTRAL PLAY] pet_unique=", petUnique)
        print("[ASTRAL PLAY] toy_kind=", toy.kind)
        print("[ASTRAL PLAY] toy_unique=", toy.unique)

        local ok, err = pcall(function()
            while os.clock() < deadline do
                if context:IsCancelled() then
                    return
                end

                if not ASTRAL.Game:PetHasAilment("play") then
                    return
                end

                local progressBefore = ASTRAL.Game:GetAilmentProgress("play") or 0
                throwCount += 1

                print(
                    "[ASTRAL PLAY] Throw",
                    throwCount,
                    "progress_before=",
                    progressBefore
                )

                local thrown, result = ASTRAL.Game:ThrowPlayToy(toy.unique)
                if not thrown then
                    error(result)
                end

                print("[ASTRAL PLAY] Created thrown toy:", result)

                -- v0.8.3b waited for actual Play progress rather than using a
                -- blind fixed delay. Keep that verified behaviour.
                local progressDeadline = math.min(deadline, os.clock() + 10)
                local advanced = false

                while os.clock() < progressDeadline do
                    if context:IsCancelled() then
                        return
                    end

                    if not ASTRAL.Game:PetHasAilment("play") then
                        return
                    end

                    local currentProgress = ASTRAL.Game:GetAilmentProgress("play")

                    if currentProgress
                        and currentProgress > progressBefore + 0.0001 then

                        print(
                            "[ASTRAL PLAY] Progress advanced:",
                            progressBefore,
                            "->",
                            currentProgress
                        )

                        advanced = true
                        break
                    end

                    task.wait(0.15)
                end

                if advanced then
                    task.wait(0.35)
                else
                    warn("[ASTRAL PLAY] Throw did not advance within 10s; retrying")
                    task.wait(0.5)
                end
            end
        end)

        ASTRAL.Game:CleanupPlayToy(toy.unique)

        if not ok then
            warn("[ASTRAL PLAY] Pipeline error:", err)
            return false, tostring(err)
        end

        if context:IsCancelled() then
            return false, "Cancelled"
        end

        if ASTRAL.Game:PetHasAilment("play") then
            return false, "Timed out waiting for Play completion"
        end

        print("[ASTRAL PLAY] Complete after", throwCount, "throw(s)")
        return true
    end

    ASTRAL.Ailments:Register(Play)
    return Play
end
