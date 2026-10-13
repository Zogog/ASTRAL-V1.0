-- ASTRAL Hauntlet client proto probe v0.7 - READ ONLY.
-- Run once during Hauntlet. Recursively inspects nested function prototypes for
-- interaction/message names without invoking gameplay functions.

local function log(...)
    local a={}
    for i=1,select("#",...) do a[i]=tostring(select(i,...)) end
    print("[ASTRAL HAUNTLET PROTO v0.7] "..table.concat(a," "))
end

if type(getloadedmodules)~="function" then log("getloadedmodules unavailable") return end

local target
local ok,mods=pcall(getloadedmodules)
if ok then
    for _,m in ipairs(mods) do
        if typeof(m)=="Instance" and m:IsA("ModuleScript")
            and m.Name=="HauntletMinigameClient"
            and m:GetFullName():find("Halloween2026",1,true) then
            target=m break
        end
    end
end
if not target then log("HauntletMinigameClient not loaded") return end

local rok,client=pcall(require,target)
if not rok or type(client)~="table" then log("cached require failed",client) return end
local cls=client.minigame_class
if type(cls)~="table" then log("minigame_class missing") return end

local names={
    "define_hotbar_buttons",
    "doors_opened_msg",
    "picked_door_msg",
    "started_room_msg",
    "door_effect_triggered_msg",
    "grey_locks_removed_msg",
    "all_locks_removed_msg",
    "revealed_ghost_msg",
    "used_item_msg",
    "ghosts_dispelled_msg",
}

local seen={}
local function constants(fn)
    if not debug or type(debug.getconstants)~="function" then return {} end
    local okc,c=pcall(debug.getconstants,fn)
    if not okc or type(c)~="table" then return {} end
    local out={}
    for _,v in ipairs(c) do
        local t=typeof(v)
        if t=="string" or t=="number" or t=="boolean" then out[#out+1]=tostring(v) end
    end
    return out
end

local function inspect(fn,path,depth)
    if type(fn)~="function" or seen[fn] or depth>5 then return end
    seen[fn]=true
    local c=constants(fn)
    log("FN",path,"depth="..depth,"constants="..table.concat(c," | "))

    if debug and type(debug.getupvalues)=="function" then
        local oku,ups=pcall(debug.getupvalues,fn)
        if oku and type(ups)=="table" then
            for k,v in pairs(ups) do
                if type(v)=="function" then
                    inspect(v,path..".up"..tostring(k),depth+1)
                elseif type(v)=="table" then
                    local keys={}
                    for kk in pairs(v) do if #keys<80 then keys[#keys+1]=tostring(kk) end end
                    table.sort(keys)
                    local joined=table.concat(keys,",")
                    if joined:find("message",1,true) or joined:find("inventory",1,true)
                        or joined:find("selected",1,true) or joined:find("interaction",1,true)
                        or joined:find("door",1,true) or joined:find("runner",1,true) then
                        log("TABLE",path..".up"..tostring(k),"keys="..joined)
                    end
                end
            end
        end
    end

    if debug and type(debug.getprotos)=="function" then
        local okp,protos=pcall(debug.getprotos,fn)
        if okp and type(protos)=="table" then
            for i,p in ipairs(protos) do inspect(p,path..".proto"..i,depth+1) end
        end
    elseif depth==0 then
        log("debug.getprotos unavailable")
    end
end

for _,name in ipairs(names) do
    local fn=cls[name]
    if type(fn)=="function" then inspect(fn,name,0) else log("missing",name) end
end

local game=client.instanced_minigame
if type(game)=="table" then
    log("LIVE","room="..tostring(game.current_room_index),
        "selected="..tostring(game.selected_door_index),
        "confirmed="..tostring(game.confirmed_selected_door_index))
    if type(game.inventory)=="table" then
        for k,v in pairs(game.inventory) do log("INV",k,v) end
    end
    local r=game.runners and game.runners[game.player_model and game.player_model.Name or ""]
    if not r and game.runners then
        for k,v in pairs(game.runners) do
            if type(v)=="table" then log("RUNNER",k,"health="..tostring(v.health),"max="..tostring(v.max_health),"temp="..tostring(v.temp_health)) end
        end
    end
end
log("END")
