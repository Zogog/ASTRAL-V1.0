-- ASTRAL dev.6.9.2 Anti-AFK.
-- Isolated runtime service: when Roblox reports the local player as idle,
-- send a minimal VirtualUser input and keep the unattended session alive.
return function(ASTRAL)
    local Players = game:GetService("Players")
    local VirtualUser = game:GetService("VirtualUser")
    local player = Players.LocalPlayer

    local AntiAFK = {
        Version = "0.1.0-dev.6.9.2",
        Enabled = true,
        TriggerCount = 0,
        LastTrigger = nil,
    }

    local function log(message)
        print("[ASTRAL ANTI-AFK] " .. tostring(message))
        if ASTRAL.State then
            pcall(function()
                ASTRAL.State:Log("Anti-AFK: " .. tostring(message))
            end)
        end
    end

    function AntiAFK:Pulse()
        if not self.Enabled or (ASTRAL.Runtime and ASTRAL.Runtime.Destroyed) then
            return false
        end

        local ok, err = pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)

        if ok then
            self.TriggerCount += 1
            self.LastTrigger = os.time()
            log("idle detected - activity sent (" .. tostring(self.TriggerCount) .. ")")
            return true
        end

        warn("[ASTRAL ANTI-AFK] activity failed:", err)
        return false, err
    end

    function AntiAFK:SetEnabled(enabled)
        self.Enabled = enabled == true
        log(self.Enabled and "enabled" or "disabled")
        return true
    end

    if player then
        ASTRAL.Runtime:Connect(player.Idled, function()
            AntiAFK:Pulse()
        end)
        log("enabled - waiting for Roblox idle signal")
    else
        AntiAFK.Enabled = false
        warn("[ASTRAL ANTI-AFK] LocalPlayer unavailable")
    end

    ASTRAL.AntiAFK = AntiAFK
    return AntiAFK
end
