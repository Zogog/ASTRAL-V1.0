return function(ASTRAL)
    local Autofarm = {
        Id = "pet_farm",
        Name = "Pet Autofarm",
        Page = "Autofarm",
        Description = "Modular pet ailment detection and completion.",
        Version = "0.1.0",
        Implemented = true,
        Enabled = false,
        Busy = false,
        CurrentAilment = nil,
        RunGeneration = 0,
    }

    function Autofarm:GetStatus()
        return {
            enabled = self.Enabled,
            implemented = true,
            busy = self.Busy,
            current = self.CurrentAilment,
            message = self.Enabled
                and (self.CurrentAilment and ("Running " .. self.CurrentAilment) or "Waiting for supported ailment")
                or "Off",
        }
    end

    function Autofarm:SetEnabled(enabled)
        enabled = enabled == true

        if self.Enabled == enabled then
            return true
        end

        self.Enabled = enabled
        self.RunGeneration += 1

        if not enabled then
            ASTRAL.State.CurrentAction = "None"
            ASTRAL.State.CurrentNeed = "None"
            ASTRAL.State:Log("Pet Autofarm disabled")
        else
            ASTRAL.State:Log("Pet Autofarm enabled")
        end

        if ASTRAL.UI and ASTRAL.UI.Refresh then
            ASTRAL.UI:Refresh()
        end

        return true
    end

    local function runHandler(handler)
        Autofarm.Busy = true
        Autofarm.CurrentAilment = handler.Id
        ASTRAL.State.CurrentNeed = handler.Name or handler.Id
        ASTRAL.State.CurrentAction = "Pet Autofarm: " .. (handler.Name or handler.Id)

        local generation = Autofarm.RunGeneration

        local context = {}

        function context:IsCancelled()
            return ASTRAL.Runtime.Destroyed
                or not Autofarm.Enabled
                or generation ~= Autofarm.RunGeneration
        end

        ASTRAL.State:Log("Starting ailment: " .. handler.Id)

        local ok, result, detail = pcall(handler.Run, handler, ASTRAL, context)

        if not ok then
            warn("[ASTRAL AUTOFARM] Handler error:", handler.Id, result)
            ASTRAL.State:Log("Ailment error: " .. handler.Id)
        elseif result then
            ASTRAL.State:Log("Ailment completed: " .. handler.Id)
        elseif not context:IsCancelled() then
            ASTRAL.State:Log(
                "Ailment did not complete: "
                .. handler.Id
                .. (detail and (" - " .. tostring(detail)) or "")
            )
        end

        ASTRAL.Scheduler:Release("pet_farm")

        Autofarm.Busy = false
        Autofarm.CurrentAilment = nil
        ASTRAL.State.CurrentAction = "None"

        if not Autofarm.Enabled then
            ASTRAL.State.CurrentNeed = "None"
        end
    end

    task.spawn(function()
        while not ASTRAL.Runtime.Destroyed do
            if Autofarm.Enabled and not Autofarm.Busy then
                local handler = ASTRAL.Ailments:SelectActive()

                if handler then
                    ASTRAL.State.CurrentNeed = handler.Name or handler.Id

                    if ASTRAL.Scheduler:Request("pet_farm", handler.Priority or 50) then
                        task.spawn(runHandler, handler)
                    end
                else
                    ASTRAL.State.CurrentNeed = "None"
                end
            end

            task.wait(0.5)
        end
    end)

    ASTRAL.Modules:Register(Autofarm)
    return Autofarm
end
