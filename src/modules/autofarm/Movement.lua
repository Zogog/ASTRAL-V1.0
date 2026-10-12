-- ASTRAL dev.5: physical Walk/Ride with reliable cleanup.
return function(ASTRAL)
    local S = assert(ASTRAL.NeedSupport)
    local Game = assert(ASTRAL.Game)
    local function move(kind, pet, context)
        local root, char = S:PlayerRoot()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then return false, "Player unavailable" end
        local petChar = S:PetCharacter()
        if not petChar then return false, "Equipped pet model unavailable" end
        local stroller, equipped, held = nil, false, false
        local oldCF, platform
        local equip, unequip = S:Remote("ToolAPI/Equip"), S:Remote("ToolAPI/Unequip")
        local hold, eject = S:Remote("AdoptAPI/HoldBaby"), S:Remote("AdoptAPI/EjectBaby")
        local function cleanup()
            pcall(function() if hum.Parent then hum:Move(Vector3.zero, false) end end)
            pcall(function() if root.Parent and oldCF then root.CFrame = oldCF end end)
            pcall(function() if platform then platform:Destroy() end end)
            if equipped and stroller and unequip then pcall(function() unequip:InvokeServer(stroller.unique) end) end
            if held and eject and petChar.Parent then pcall(function() eject:FireServer(petChar) end) end
        end
        local ok, result, reason = pcall(function()
            if kind == "walk" then
                if not hold or not eject then return false, "HoldBaby/EjectBaby unavailable" end
                local done, why = S:Call(hold, petChar)
                if not done then return false, why end
                held = true
                task.wait(0.75)
            else
                if not equip then return false, "ToolAPI/Equip unavailable" end
                for _, item in pairs(Game:GetInventory().strollers or {}) do
                    if type(item) == "table" and item.unique then stroller = item; break end
                end
                if not stroller then return false, "No owned stroller" end
                local done, why = S:Call(equip, stroller.unique, {use_sound_delay = true, equip_as_last = false})
                if not done then return false, why end
                equipped = true
                task.wait(1.5)
            end
            if context:IsCancelled() then return false, "Cancelled" end
            -- The old validated controller used an isolated movement platform.
            -- Keep it temporary and restore the original player position on ALL exits.
            oldCF = root.CFrame
            local arenaOk, arenaErr = pcall(function()
                platform = Instance.new("Part")
                platform.Name = "ASTRAL_MovementArena"
                platform.Anchored = true
                platform.CanCollide = true
                platform.CanTouch = false
                platform.CanQuery = false
                platform.Size = Vector3.new(80, 2, 80)
                platform.Transparency = 0.35
                platform.CFrame = CFrame.new(root.Position.X, root.Position.Y + 1000, root.Position.Z)
                platform.Parent = workspace
                root.CFrame = platform.CFrame * CFrame.new(0, 4, 0)
            end)
            if not arenaOk then
                -- Some executor worker threads cannot create Instances.
                -- Stay on the map and use physical movement rather than crashing.
                if platform then pcall(function() platform:Destroy() end); platform = nil end
                oldCF = nil -- never teleport/restore when using the map fallback
                S:Log(kind .. ": arena unavailable; using ground movement: " .. tostring(arenaErr))
            end
            task.wait(0.35)
            local centre = arenaOk and (platform.Position + Vector3.new(0, 4, 0)) or root.Position
            local waypoint = 0
            local deadline = os.clock() + 48
            while os.clock() < deadline do
                local status, why = S:Check(kind, pet, context)
                if status ~= nil then return status, why end
                if hum.Health <= 0 or not root.Parent then return false, "Player became unavailable" end
                waypoint += 1
                local angle = ((waypoint - 1) % 12) / 12 * math.pi * 2
                local target = centre + Vector3.new(math.cos(angle) * 12, 0, math.sin(angle) * 12)
                hum:MoveTo(target)
                local wpDeadline = os.clock() + 5
                while os.clock() < wpDeadline do
                    local status2, why2 = S:Check(kind, pet, context)
                    if status2 ~= nil then return status2, why2 end
                    if not root.Parent or hum.Health <= 0 then return false, "Player became unavailable" end
                    local flat = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
                    if flat.Magnitude <= 2.5 then break end
                    task.wait(0.1)
                end
            end
            return false, "Movement timeout"
        end)
        cleanup()
        if not ok then return false, tostring(result) end
        return result, reason
    end
    S:MakeHandler("walk", "Walk", 70, function(pet, context)
        return move("walk", pet, context)
    end, 40)
    S:MakeHandler("ride", "Ride", 69, function(pet, context)
        return move("ride", pet, context)
    end, 40)
end
