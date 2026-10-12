-- ASTRAL Hauntlet 2 probe v0.2 - READ ONLY.
-- Run once in Haunted Hotel lobby and once during an active Hauntlet 2 room.
-- Does not invoke remotes, move the character, or mutate game state.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local function log(...) local a={} for i=1,select("#",...) do a[i]=tostring(select(i,...)) end print("[ASTRAL HAUNTLET PROBE] "..table.concat(a," ")) end
local function match(s)
    s=string.lower(tostring(s))
    return s:find("haunt",1,true) or s:find("halloween",1,true) or s:find("hotel",1,true)
        or s:find("minigame",1,true) or s:find("bolt",1,true)
end
local function preview(v)
    if typeof(v)~="table" then return tostring(v) end
    local a,n={},0
    for k,x in pairs(v) do
        n+=1
        if n<=18 then
            local t=typeof(x)
            a[#a+1]=tostring(k)..((t=="number" or t=="boolean" or t=="string")
                and ("="..tostring(x):sub(1,35)) or (":"..t))
        end
    end
    return "table("..n..") {"..table.concat(a,", ")..(n>18 and ", ..." or "").."}"
end
local function inspect(label,t)
    if typeof(t)~="table" then log(label,preview(t)); return end
    local n=0
    for k,v in pairs(t) do
        if match(k) then n+=1; if n<=35 then log(label.."."..tostring(k),preview(v)) end end
    end
    log(label,"matching fields:",n)
end
local function scan(label,root,max,filter)
    if not root then log(label,"unavailable"); return end
    local n,seen=0,0
    for _,obj in ipairs(root:GetDescendants()) do
        seen+=1
        if seen>35000 then break end
        if filter(obj.Name) then
            n+=1
            if n<=max then log(label,obj:GetFullName(),"["..obj.ClassName.."]") end
        end
    end
    log(label,"matches:",n,"scanned:",seen)
end
log("START",os.date("!%Y-%m-%dT%H:%M:%SZ"))
local okF,F=pcall(function() return require(RS:WaitForChild("Fsys",3)) end)
local function load(name)
    if not okF then return nil end
    local ok,result=pcall(function() return F.load(name) end)
    if not ok then log("Fsys.load",name,"error:",result); return nil end
    return result
end
local Interiors=load("InteriorsM")
if Interiors and Interiors.get_current_location then
    local ok,v=pcall(Interiors.get_current_location)
    log("Interiors location",ok and preview(v) or tostring(v))
end
local ClientData=load("ClientData")
if ClientData then
    local ok,w=pcall(function() return ClientData.get("char_wrapper","Raw") end)
    if ok and typeof(w)=="table" then log("char_wrapper.location",preview(w.location)) end
    local ok2,data=pcall(function() return ClientData.get_data() end)
    if ok2 and typeof(data)=="table" then
        local personal=data[player.Name]
        inspect("ClientData.player",personal)
        if typeof(personal)~="table" then inspect("ClientData.root",data) end
    else log("ClientData.get_data error",data) end
end
local net=RS:FindFirstChild("adoptme_new_net")
if net then
    local n=0
    for _,obj in ipairs(net:GetChildren()) do
        if match(obj.Name) then
            n+=1
            if n<=90 then log("NET",obj.Name,"["..obj.ClassName.."]") end
        end
    end
    log("NET matching endpoints",n)
else log("NET unavailable") end
scan("RS",RS,65,match)
scan("WORLD",workspace,45,function(name)
    local s=name:lower()
    return s:find("haunt",1,true) or s:find("hotel",1,true) or s:find("bolt",1,true)
end)
local function showChildren(label,root,limit)
    if not root then log(label,"unavailable"); return end
    local n=0
    log(label,"root",root:GetFullName(),"attributes:",preview(root:GetAttributes()))
    for _,obj in ipairs(root:GetDescendants()) do
        n+=1
        if n>limit then break end
        local value=""
        if obj:IsA("ValueBase") then value=" value="..tostring(obj.Value) end
        log(label,obj:GetFullName(),"["..obj.ClassName.."]"..value,"attributes:",preview(obj:GetAttributes()))
    end
    log(label,"items shown",math.min(n,limit))
end
local staticMap=workspace:FindFirstChild("StaticMap")
if staticMap then
    for _,obj in ipairs(staticMap:GetChildren()) do
        if obj.Name:lower():find("hauntlet",1,true) and obj.Name:lower():find("minigame_state",1,true) then
            showChildren("STATE",obj,120)
        end
    end
end
local interiors=workspace:FindFirstChild("Interiors")
if interiors then
    for _,interior in ipairs(interiors:GetChildren()) do
        if interior.Name:find("HauntletInterior",1,true) then
            local rooms=interior:FindFirstChild("Rooms")
            showChildren("ACTIVE ROOMS",rooms,180)
        end
    end
end
scan("GUI",player:FindFirstChild("PlayerGui"),35,match)
local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if root then
    local doors,seen={},0
    for _,obj in ipairs(workspace:GetDescendants()) do
        seen+=1
        if seen>35000 then break end
        if obj:IsA("BasePart") and obj.Name:lower():find("door",1,true) then
            local d=(obj.Position-root.Position).Magnitude
            if d<120 then doors[#doors+1]={obj=obj,d=d} end
        end
    end
    table.sort(doors,function(a,b) return a.d<b.d end)
    log("Nearby door parts",#doors)
    for i=1,math.min(#doors,15) do
        local v=doors[i]
        log("DOOR",math.floor(v.d).." studs",v.obj:GetFullName(),"attributes:",preview(v.obj:GetAttributes()))
    end
end
log("END - say whether this was lobby, queue or active room")