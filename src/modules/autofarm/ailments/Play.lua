return function(ASTRAL)
    local Play = {
        Id = "play",
        Name = "Play",
        Version = "0.1.3-dev.6.5.1-ds",
        Priority = 50,
        RetryAfter = 0,
    }

    function Play:CanRun()
        return os.clock() >= (self.RetryAfter or 0)
            and ASTRAL.Game:GetCurrentPetUnique() ~= nil
            and ASTRAL.Game:FindPlayToy() ~= nil
    end

    function Play:Backoff(seconds)
        self.RetryAfter = os.clock() + (seconds or 12)
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

        -- Play depends on the physical PetEntity being present to notice and
        -- react to the thrown object. Location transitions/pet switches can
        -- leave the inventory wrapper available slightly before the model is.
        local function waitForPetEntity(seconds)
            local deadline = os.clock() + (seconds or 5)
            while os.clock() < deadline do
                if context:IsCancelled() then return false end
                local support = ASTRAL.NeedSupport
                local root = support and support:PetRoot()
                if root then return true end
                task.wait(0.2)
            end
            return false
        end

        if not waitForPetEntity(5) then
            self:Backoff(12)
            return false, "Equipped pet model not ready for Play"
        end

        local throwCount = 0
        local deadline = os.clock() + 55

        print("")
        print("[ASTRAL PLAY] Starting D&S 4.1.3 pet-object Play pipeline")
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

                local support = ASTRAL.NeedSupport
                local _, petCharacter = support and support:PetRoot()
                if not petCharacter then
                    error("Equipped pet model unavailable for D&S Play")
                end

                local thrown, result = ASTRAL.Game:ThrowPlayToy(
                    toy.unique,
                    petUnique,
                    petCharacter
                )
                if not thrown then
                    error(result)
                end

                print("[ASTRAL PLAY] D&S Create/Grab/Drop completed:", result)

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
                    warn("[ASTRAL PLAY] Throw did not advance within 10s; resetting toy state")
                    -- D&S cleans each spawned object immediately after
                    -- Grab/Drop, so there is no ToolAPI START/END state to reset.

                    if not waitForPetEntity(5) then
                        warn("[ASTRAL PLAY] Pet model not ready after failed throw")
                    end

                    task.wait(1)
                end
            end
        end)

        if not ok then
            self:Backoff(12)
            warn("[ASTRAL PLAY] Pipeline error:", err)
            return false, tostring(err)
        end

        if context:IsCancelled() then
            return false, "Cancelled"
        end

        if ASTRAL.Game:PetHasAilment("play") then
            self:Backoff(12)
            return false, "Timed out waiting for Play completion"
        end

        print("[ASTRAL PLAY] Complete after", throwCount, "throw(s)")
        return true
    end

    ASTRAL.Ailments:Register(Play)
    return Play
end
