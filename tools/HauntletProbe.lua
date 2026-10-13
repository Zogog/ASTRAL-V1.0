-- ASTRAL Hauntlet 2 probe v0.5 - READ ONLY.
-- Focus: inspect the already-replicated Hauntlet DB modules during cooldown.
-- Does not invoke remotes, move the character, or mutate game state.

local RS=game:GetService("ReplicatedStorage")
local function log(...)
    local a={}
    for i=1,select("#",...) do a[i]=tostring(select(i,...)) end
    print("[ASTRAL HAUNTLET DB v0.5] "..table.concat(a," "))
end

local function scalar(v)
    local t=typeof(v)
    if t=="string" then return string.format("%q",v) end
    if t=="number" or t=="boolean" or t=="nil" then return tostring(v) end
    if t=="Instance" then return v:GetFullName() end
    if t=="Vector3" or t=="CFrame" or t=="Color3" then return tostring(v) end
    return "<"..t..">"
end

local seen={}
local function dump(v,path,depth)
    depth=depth or 0
    if depth>5 then log(path,"=<max-depth>"); return end
    local t=typeof(v)
    if t~="table" then
        log(path,"=",scalar(v))
        if t=="function" and debug and type(debug.getconstants)=="function" then
            local ok,c=pcall(debug.getconstants,v)
            if ok and type(c)=="table" then
                local out={}
                for _,x in ipairs(c) do
                    local xt=typeof(x)
                    if xt=="string" or xt=="number" or xt=="boolean" then
                        out[#out+1]=scalar(x)
                    end
                end
                if #out>0 then log(path..".constants",table.concat(out," | ")) end
            end
        end
        return
    end
    if seen[v] then log(path,"=<seen "..seen[v]..">"); return end
    seen[v]=path

    local keys={}
    for k in pairs(v) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    log(path,"table entries="..#keys)
    for i,k in ipairs(keys) do
        if i>250 then log(path,"... truncated"); break end
        dump(v[k],path.."."..tostring(k),depth+1)
    end
end

local base=RS:WaitForChild("SharedModules")
    :WaitForChild("ContentPacks")
    :WaitForChild("Halloween2026")
    :WaitForChild("Game")
    :WaitForChild("Hauntlet")

local names={"HauntletDoorDB","HauntletAreaDB","HauntletItemDB"}
for _,name in ipairs(names) do
    local m=base:FindFirstChild(name)
    if not m then
        log("MODULE",name,"missing")
    else
        local ok,result=pcall(require,m)
        if ok then
            seen={}
            log("MODULE",name,"required")
            dump(result,name,0)
        else
            log("MODULE",name,"require failed:",result)
        end
    end
end

-- Map the public surface of the runner/manager without calling anything.
for _,name in ipairs({"HauntletFloor","HauntletManager","HauntletRunner"}) do
    local m=base:FindFirstChild(name)
    if m then
        local loaded=false
        if type(getloadedmodules)=="function" then
            local ok,mods=pcall(getloadedmodules)
            if ok and type(mods)=="table" then
                for _,x in ipairs(mods) do if x==m then loaded=true break end end
            end
        end
        log("MODULE_SURFACE",name,"loaded="..tostring(loaded))
        if loaded then
            local ok,result=pcall(require,m)
            if ok then
                seen={}
                dump(result,name,0)
            else
                log("MODULE_SURFACE",name,"cached require failed:",result)
            end
        end
    end
end

log("END")
