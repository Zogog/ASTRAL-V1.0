-- ASTRAL Hauntlet 2 probe v0.4 - READ ONLY.
-- Cooldown/lobby mode maps client-side Hauntlet resources and loaded modules.
-- Active-run mode prints only the current HUD room, newest generated room and its doors.
-- Does not invoke remotes, move the character, require unknown modules, or mutate game state.

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer

local function log(...)
    local a={}
    for i=1,select("#",...) do a[i]=tostring(select(i,...)) end
    print("[ASTRAL HAUNTLET PROBE v0.4] "..table.concat(a," "))
end

local function preview(v)
    if typeof(v)~="table" then return tostring(v) end
    local a,n={},0
    for k,x in pairs(v) do
        n+=1
        if n<=24 then
            local t=typeof(x)
            a[#a+1]=tostring(k)..((t=="number" or t=="boolean" or t=="string")
                and ("="..tostring(x):sub(1,60)) or (":"..t))
        end
    end
    return "table("..n..") {"..table.concat(a,", ")..(n>24 and ", ..." or "").."}"
end

local function attrsAndTags(obj)
    local tags={}
    pcall(function() tags=CollectionService:GetTags(obj) end)
    return "attrs="..preview(obj:GetAttributes()).." tags="..table.concat(tags,",")
end

local function posOf(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local ok,p=pcall(function() return obj:GetPivot().Position end)
        if ok then return p end
    end
end

local function interestingName(name)
    local s=name:lower()
    local words={"door","interact","trigger","zone","spawn","bolt","ghost","reward","heart",
        "key","phone","wand","exit","room","choice","safe","danger","shadow","rotten","lock",
        "journal","lever","button","prompt","teleport","target"}
    for _,w in ipairs(words) do if s:find(w,1,true) then return true end end
    return false
end

local function loadFsys(name)
    local fs=RS:FindFirstChild("Fsys")
    if not fs then return nil end
    local ok,F=pcall(require,fs)
    if not ok then return nil end
    local ok2,v=pcall(function() return F.load(name) end)
    return ok2 and v or nil
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

local function currentLocation()
    local Interiors=loadFsys("InteriorsM")
    if Interiors and Interiors.get_current_location then
        local ok,v=pcall(Interiors.get_current_location)
        if ok and type(v)=="table" then return v.destination_id or v.full_destination_id end
    end
    return nil
end

local function findActiveInterior()
    local interiors=workspace:FindFirstChild("Interiors")
    if not interiors then return nil end
    for _,x in ipairs(interiors:GetChildren()) do
        if x.Name:find("HauntletInterior::",1,true)==1 then return x end
    end
end

local function sortedRooms(active)
    local rooms=active and active:FindFirstChild("Rooms")
    if not rooms then return {} end
    local list=rooms:GetChildren()
    table.sort(list,function(a,b)
        local pa,pb=posOf(a),posOf(b)
        if pa and pb then return pa.X>pb.X end
        return a.Name<b.Name
    end)
    return list
end

local function dumpCurrentRun()
    local active=findActiveInterior()
    if not active then
        log("RUN no active HauntletInterior")
        return false
    end

    local list=sortedRooms(active)
    local hudRoom=hudValue("Right")
    local hudTime=hudValue("Left")
    log("RUN location="..tostring(currentLocation()),"hud_room="..tostring(hudRoom),
        "time_left="..tostring(hudTime),"generated_rooms="..tostring(#list))

    if #list==0 then return true end
    local room=list[#list]
    local rp=posOf(room)
    log("CURRENT",room.Name,attrsAndTags(room),rp and ("pos="..tostring(rp)) or "")

    local doors=room:FindFirstChild("Doors")
    if not doors then
        log("CURRENT no Doors folder")
        return true
    end
    local dl=doors:GetChildren()
    table.sort(dl,function(a,b) return tonumber(a.Name) and tonumber(b.Name) and tonumber(a.Name)<tonumber(b.Name) or a.Name<b.Name end)
    for _,door in ipairs(dl) do
        local dp=door:FindFirstChild("DoorPart",true)
        local pp=dp and dp.Position or posOf(door)
        log("CHOICE","door="..door.Name,"kind="..tostring(door:GetAttribute("kind")),
            attrsAndTags(door),dp and attrsAndTags(dp) or "",
            pp and ("pos="..tostring(pp)) or "")
        local shown=0
        for _,d in ipairs(door:GetDescendants()) do
            if interestingName(d.Name) or d:IsA("ValueBase") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
                shown+=1
                if shown<=30 then
                    local val=d:IsA("ValueBase") and (" value="..tostring(d.Value)) or ""
                    log("CHOICEDETAIL","door="..door.Name,d:GetFullName(),"["..d.ClassName.."]"..val,attrsAndTags(d))
                end
            end
        end
    end
    return true
end

local function dumpState()
    local sm=workspace:FindFirstChild("StaticMap")
    if not sm then return end
    for _,root in ipairs(sm:GetChildren()) do
        local n=root.Name:lower()
        if n:find("hauntlet",1,true) and n:find("minigame_state",1,true) then
            local values={}
            for _,d in ipairs(root:GetDescendants()) do
                if d:IsA("ValueBase") then values[#values+1]=d.Name.."="..tostring(d.Value) end
            end
            table.sort(values)
            log("STATE",root.Name,table.concat(values," | "))
        end
    end
end

local function dumpTemplates()
    local resources=RS:FindFirstChild("Resources")
    local hauntlet=resources and resources:FindFirstChild("Hauntlet")
    local rooms=hauntlet and hauntlet:FindFirstChild("Rooms")
    if not rooms then log("TEMPLATES unavailable"); return end

    local templates=rooms:GetChildren()
    table.sort(templates,function(a,b) return a.Name<b.Name end)
    log("TEMPLATES count="..#templates)

    for _,room in ipairs(templates) do
        local p=posOf(room)
        log("TEMPLATE",room.Name,attrsAndTags(room),p and ("pivot="..tostring(p)) or "")
        local doors=room:FindFirstChild("Doors")
        if doors then
            local dl=doors:GetChildren()
            table.sort(dl,function(a,b) return a.Name<b.Name end)
            for _,door in ipairs(dl) do
                log("TEMPLATE_DOOR",room.Name,"door="..door.Name,
                    "kind="..tostring(door:GetAttribute("kind")),attrsAndTags(door))
            end
        end
        local shown=0
        for _,d in ipairs(room:GetDescendants()) do
            if interestingName(d.Name) or d:IsA("ValueBase") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
                shown+=1
                if shown<=80 then
                    local val=d:IsA("ValueBase") and (" value="..tostring(d.Value)) or ""
                    log("TEMPLATE_DETAIL",room.Name,d:GetFullName(),"["..d.ClassName.."]"..val,attrsAndTags(d))
                end
            end
        end
        log("TEMPLATE_DETAIL_COUNT",room.Name,shown)
    end
end

local function dumpHauntletModules()
    local found={}
    for _,d in ipairs(RS:GetDescendants()) do
        if d:IsA("ModuleScript") then
            local full=d:GetFullName():lower()
            if full:find("hauntlet",1,true) or
               (full:find("halloween2026",1,true) and
                (full:find("minigame",1,true) or full:find("room",1,true) or full:find("hotel",1,true))) then
                found[#found+1]=d
            end
        end
    end
    table.sort(found,function(a,b) return a:GetFullName()<b:GetFullName() end)
    log("MODULES replicated matching="..#found)
    for i=1,math.min(#found,120) do log("MODULE",found[i]:GetFullName(),attrsAndTags(found[i])) end

    if type(getloadedmodules)=="function" then
        local ok,mods=pcall(getloadedmodules)
        if ok and type(mods)=="table" then
            local loaded={}
            for _,m in ipairs(mods) do
                if typeof(m)=="Instance" and m:IsA("ModuleScript") then
                    local full=m:GetFullName():lower()
                    if full:find("hauntlet",1,true) then loaded[#loaded+1]=m:GetFullName() end
                end
            end
            table.sort(loaded)
            log("MODULES loaded hauntlet="..#loaded)
            for _,name in ipairs(loaded) do log("LOADED_MODULE",name) end
        else log("MODULES getloadedmodules failed") end
    else
        log("MODULES getloadedmodules unavailable")
    end
end

log("START",os.date("!%Y-%m-%dT%H:%M:%SZ"))
dumpState()
local active=dumpCurrentRun()

-- These are static/read-only discoveries and are especially useful during the cooldown.
dumpHauntletModules()
dumpTemplates()

if not active then
    local ClientData=loadFsys("ClientData")
    if ClientData then
        local ok,data=pcall(function() return ClientData.get_data() end)
        local personal=ok and type(data)=="table" and data[player.Name] or nil
        if type(personal)=="table" then
            log("PLAYER hauntlet_manager",preview(personal.halloween_2026_hauntlet_manager))
            log("PLAYER hauntlet_cycle",preview(personal.hauntlet_cycle_timestamp))
            log("PLAYER minigame_timestamps",preview(personal.minigame_timestamps))
        end
    end
end
log("END")
