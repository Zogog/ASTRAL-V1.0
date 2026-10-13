-- ASTRAL Hauntlet 2 state observer v0.3 - READ ONLY.
-- Arm before a run. Reads the live cached HauntletMinigameClient state once it exists.
-- Tracks authoritative Hauntlet health, inventory, room index and selection state.
-- Also reports visible choice door kinds. No remotes, movement or interactions.

local Players=game:GetService("Players")
local player=Players.LocalPlayer

local function log(...)
    local a={}
    for i=1,select("#",...) do a[i]=tostring(select(i,...)) end
    print("[ASTRAL HAUNTLET OBS v0.3] "..table.concat(a," "))
end

local function getClient()
    if type(getloadedmodules)~="function" then return nil end
    local ok,mods=pcall(getloadedmodules)
    if not ok or type(mods)~="table" then return nil end
    for _,m in ipairs(mods) do
        if typeof(m)=="Instance" and m:IsA("ModuleScript")
            and m.Name=="HauntletMinigameClient"
            and m:GetFullName():find("Halloween2026",1,true) then
            local rok,result=pcall(require,m)
            if rok and type(result)=="table" then return result end
        end
    end
end

local function inventoryString(inv)
    local order={"cell_phone","ghost_potion","key","gold_key","gold_potion","rainbow_wand","red_potion"}
    local out={}
    for _,k in ipairs(order) do out[#out+1]=k.."="..tostring((inv and inv[k]) or 0) end
    return table.concat(out,",")
end

local function choiceString(game)
    local room=game and game.current_room
    local doors=room and room:FindFirstChild("Doors")
    if not doors then return "none" end
    local list=doors:GetChildren()
    table.sort(list,function(a,b) return tostring(a.Name)<tostring(b.Name) end)
    local out={}
    for _,d in ipairs(list) do
        out[#out+1]=tostring(d.Name)..":"..tostring(d:GetAttribute("kind"))
    end
    return table.concat(out," | ")
end

local last={}
local function changed(k,v)
    v=tostring(v)
    if last[k]~=v then last[k]=v return true end
    return false
end

log("ARMED - waiting for live Hauntlet client state")
local announced=false
while task.wait(0.08) do
    local root=getClient()
    local game=root and root.instanced_minigame
    if game and game.is_participating then
        if not announced then
            announced=true
            log("ATTACHED",game.minigame_id or "?")
        end

        local runner=game.runners and game.runners[player.Name]
        if runner then
            local hp=table.concat({
                "health="..tostring(runner.health),
                "max="..tostring(runner.max_health),
                "temp="..tostring(runner.temp_health)
            },",")
            if changed("health",hp) then log("HEALTH",hp) end
        end

        local inv=inventoryString(game.inventory)
        if changed("inventory",inv) then log("INVENTORY",inv) end

        local state=table.concat({
            "room="..tostring(game.current_room_index),
            "selected="..tostring(game.selected_door_index),
            "confirmed="..tostring(game.confirmed_selected_door_index),
            "room_model="..tostring(game.current_room and game.current_room.Name)
        },",")
        if changed("state",state) then
            log("STATE",state)
            log("CHOICES",choiceString(game))
        end

        local choices=choiceString(game)
        if changed("choices",choices) then log("CHOICES_CHANGE",choices) end
    elseif announced then
        log("DETACHED / RUN ENDED")
        announced=false
        last={}
    end
end
