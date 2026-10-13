-- ASTRAL Hauntlet 2 passive observer v0.2 - READ ONLY.
-- Arm before a run. It automatically records each room transition, visible door kinds,
-- timer/HUD changes, generated room types, Bolt state and Hauntlet hotbar text.
-- No remotes, movement, interactions, or game-state mutation.

local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer

local function log(...)
    local a={}
    for i=1,select("#",...) do a[i]=tostring(select(i,...)) end
    print("[ASTRAL HAUNTLET OBS v0.2] "..table.concat(a," "))
end

local function posOf(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local ok,p=pcall(function() return obj:GetPivot().Position end)
        if ok then return p end
    end
end

local function relPath(root,d)
    local parts={}
    local x=d
    while x and x~=root do
        table.insert(parts,1,x.Name)
        x=x.Parent
    end
    return table.concat(parts,".")
end

local function guiText(root)
    if not root then return "" end
    local out={}
    for _,d in ipairs(root:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Visible then
            local s=tostring(d.Text or ""):gsub("%s+"," ")
            if s~="" then out[#out+1]=relPath(root,d).."="..s end
        elseif d:IsA("ValueBase") then
            out[#out+1]=relPath(root,d).."="..tostring(d.Value)
        end
    end
    table.sort(out)
    return table.concat(out," | ")
end

local function guiImages(root)
    if not root then return "" end
    local out={}
    for _,d in ipairs(root:GetDescendants()) do
        if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Visible then
            local image=tostring(d.Image or "")
            if image~="" then
                out[#out+1]=relPath(root,d).."="..image
            end
        end
    end
    table.sort(out)
    return table.concat(out," | ")
end

local function hudValue(side)
    local pg=player:FindFirstChild("PlayerGui")
    local gui=pg and pg:FindFirstChild("HauntletInGameApp")
    local body=gui and gui:FindFirstChild("Body")
    local panel=body and body:FindFirstChild(side)
    local container=panel and panel:FindFirstChild("Container")
    local value=container and container:FindFirstChild("ValueLabel")
    return value and value.Text or nil
end

local function activeInterior()
    local interiors=workspace:FindFirstChild("Interiors")
    if not interiors then return nil end
    for _,x in ipairs(interiors:GetChildren()) do
        if x.Name:find("HauntletInterior::",1,true)==1 then return x end
    end
end

local function activeState()
    local sm=workspace:FindFirstChild("StaticMap")
    if not sm then return nil end
    for _,x in ipairs(sm:GetChildren()) do
        if x.Name:find("hauntlet::",1,true)==1 and x.Name:find("_minigame_state",1,true) then
            local a=x:FindFirstChild("is_game_active")
            if a and a:IsA("ValueBase") and a.Value==true then return x end
        end
    end
end

local function currentRoom(active)
    local rooms=active and active:FindFirstChild("Rooms")
    if not rooms then return nil end
    local hrp=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local best,bestDist
    if hrp then
        for _,r in ipairs(rooms:GetChildren()) do
            if r.Name~="elevator" then
                local p=posOf(r)
                if p then
                    local dist=(p-hrp.Position).Magnitude
                    if not bestDist or dist<bestDist then best,bestDist=r,dist end
                end
            end
        end
    end
    return best,bestDist
end

local function snapshot(reason)
    local active=activeInterior()
    if not active then return end
    local room,dist=currentRoom(active)
    local hudRoom=hudValue("Right")
    local hudTime=hudValue("Left")
    log("SNAP",reason,"room="..tostring(hudRoom),"time="..tostring(hudTime),
        "interior="..active.Name,"nearest="..tostring(room and room.Name),
        "dist="..tostring(dist and math.floor(dist*10+0.5)/10))

    local rooms=active:FindFirstChild("Rooms")
    if rooms then
        local summary={}
        for _,r in ipairs(rooms:GetChildren()) do
            local p=posOf(r)
            summary[#summary+1]=r.Name.."@"..(p and string.format("%.1f,%.1f,%.1f",p.X,p.Y,p.Z) or "?")
        end
        table.sort(summary)
        log("ROOMS",table.concat(summary," | "))
    end

    if room then
        local doors=room:FindFirstChild("Doors")
        if doors then
            local dl=doors:GetChildren()
            table.sort(dl,function(a,b) return tostring(a.Name)<tostring(b.Name) end)
            local choices={}
            for _,d in ipairs(dl) do
                choices[#choices+1]=tostring(d.Name)..":"..tostring(d:GetAttribute("kind"))
            end
            log("CHOICES",table.concat(choices," | "))
        else
            log("CHOICES","none")
        end
    end

    local pg=player:FindFirstChild("PlayerGui")
    local inGame=pg and pg:FindFirstChild("HauntletInGameApp")
    local hotbar=pg and pg:FindFirstChild("MinigameHotbarApp")
    local rewards=pg and pg:FindFirstChild("MinigameRewardsApp")
    log("HUD",guiText(inGame))
    log("HOTBAR",guiText(hotbar))
    log("HOTBAR_IMAGES",guiImages(hotbar))
    log("INGAME_IMAGES",guiImages(inGame))
    log("REWARDS",guiText(rewards))

    local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then log("HUMANOID","health="..tostring(hum.Health),"max="..tostring(hum.MaxHealth)) end

    local bolt=workspace:FindFirstChild("Bolt")
    if bolt then
        local p=posOf(bolt)
        log("BOLT","present",p and tostring(p) or "no-position")
    else
        log("BOLT","absent")
    end
end

log("ARMED - play normally; snapshots happen automatically on room changes")

local lastRoom=nil
local lastActive=false
local lastHotbar=""
local lastBolt=false
local lastHealth=nil
local lastTick=0

while task.wait(0.12) do
    local state=activeState()
    local active=state~=nil
    if active~=lastActive then
        lastActive=active
        log("GAME_ACTIVE",active,state and state.Name or "")
        if active then
            task.wait(0.35)
            snapshot("run-start")
        else
            snapshot("run-end")
            local pg=player:FindFirstChild("PlayerGui")
            log("FINAL_REWARDS",guiText(pg and pg:FindFirstChild("MinigameRewardsApp")))
        end
    end

    if active then
        local room=tostring(hudValue("Right") or "")
        if room~="" and room~=lastRoom then
            lastRoom=room
            task.wait(0.18)
            snapshot("room-change")
        end

        local now=os.clock()
        if now-lastTick>=0.5 then
            lastTick=now
            local pg=player:FindFirstChild("PlayerGui")
            local hot=guiText(pg and pg:FindFirstChild("MinigameHotbarApp"))
            if hot~=lastHotbar then
                lastHotbar=hot
                log("HOTBAR_CHANGE",hot)
            end
            local bolt=workspace:FindFirstChild("Bolt")~=nil
            if bolt~=lastBolt then
                lastBolt=bolt
                log("BOLT_CHANGE",bolt)
            end
            local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            local hp=hum and hum.Health or nil
            if hp~=lastHealth then
                lastHealth=hp
                log("HEALTH_CHANGE",tostring(hp))
            end
        end
    end
end
