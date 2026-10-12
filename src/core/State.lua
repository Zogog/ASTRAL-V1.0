return function(ASTRAL)
    local State = {
        Runtime = "BOOTING",
        CurrentPage = "Dashboard",
        CurrentAction = "None",
        CurrentNeed = "None",
        EquippedPet = "None",
        StartedAt = os.clock(),
        Activity = {},
    }

    function State:Log(message)
        table.insert(self.Activity, 1, {
            t = os.clock() - self.StartedAt,
            message = tostring(message),
        })
        while #self.Activity > 40 do
            table.remove(self.Activity)
        end

        -- Gameplay handlers can run on executor-created worker threads whose
        -- capability set may not permit touching GUI Instances. Logging must
        -- never make gameplay fail just because an immediate UI refresh is
        -- unavailable on the calling thread. The normal Heartbeat refresh in
        -- Window.lua will pick the updated state up on the next UI tick.
        if ASTRAL.UI and ASTRAL.UI.Refresh then
            pcall(function()
                ASTRAL.UI:Refresh()
            end)
        end
    end

    function State:Uptime()
        local s = math.max(0, math.floor(os.clock() - self.StartedAt))
        return string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
    end

    ASTRAL.State = State
    return State
end
