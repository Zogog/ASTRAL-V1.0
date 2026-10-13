-- ASTRAL Hauntlet client probe v0.6 - READ ONLY.
-- Run during Hauntlet. Inspects already-loaded Hauntlet modules and function metadata.
-- Does not invoke game functions/remotes, move the character, or mutate state.

local RS=game:GetService("ReplicatedStorage")
local function log(...)
    local a={}
    for i=1,select("#",...) do a[i]=tostring(select(i,...)) end
    print("[ASTRAL HAUNTLET CLIENT v0.6] "..table.concat(a," "))
end

local function simple(v)
    local t=typeof(v)
    if t=="string" then return string.format("%q",v) end
    if t=="number" or t=="boolean" or t=="nil" then return tostring(v) end
    if t=="Instance" then return v:GetFullName() end
    return "<"..t..">"
end

local function functionInfo(fn,path)
    log("FUNCTION",path)
    if debug and type(debug.getconstants)=="function" then
        local ok,vals=pcall(debug.getconstants,fn)
        if ok and type(vals)=="table" then
            local out={}
            for _,v in ipairs(vals) do
                local t=typeof(v)
                if t=="string" or t=="number" or t=="boolean" then out[#out+1]=simple(v) end
            end
            if #out>0 then log("CONSTANTS",path,table.concat(out," | ")) end
        end
    end
    if debug and type(debug.getupvalues)=="function" then
        local ok,vals=pcall(debug.getupvalues,fn)
        if ok and type(vals)=="table" then
            for k,v in pairs(vals) do
                local t=typeof(v)
                if t=="string" or t=="number" or t=="boolean" or t=="Instance" then
                    log("UPVALUE",path,tostring(k),simple(v))
                elseif t=="table" then
                    local keys={}
                    for kk in pairs(v) do
                        if #keys<40 then keys[#keys+1]=tostring(kk) end
                    end
                    table.sort(keys)
                    log("UPVALUE_TABLE",path,tostring(k),"keys="..table.concat(keys,","))
                end
            end
        end
    end
end

local function dumpSurface(v,path,depth,seen)
    depth=depth or 0
    seen=seen or {}
    local t=typeof(v)
    if t=="function" then functionInfo(v,path); return end
    if t~="table" then log("VALUE",path,simple(v)); return end
    if seen[v] then return end
    seen[v]=true
    if depth>3 then return end
    local keys={}
    for k in pairs(v) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    log("TABLE",path,"entries="..#keys)
    for i,k in ipairs(keys) do
        if i>160 then break end
        local x=v[k]
        local xt=typeof(x)
        if xt=="function" then
            functionInfo(x,path.."."..tostring(k))
        elseif xt=="table" then
            dumpSurface(x,path.."."..tostring(k),depth+1,seen)
        elseif xt=="string" or xt=="number" or xt=="boolean" or xt=="Instance" then
            log("VALUE",path.."."..tostring(k),simple(x))
        end
    end
end

if type(getloadedmodules)~="function" then
    log("getloadedmodules unavailable")
    return
end

local ok,mods=pcall(getloadedmodules)
if not ok or type(mods)~="table" then
    log("getloadedmodules failed",mods)
    return
end

local matches={}
for _,m in ipairs(mods) do
    if typeof(m)=="Instance" and m:IsA("ModuleScript") then
        local full=m:GetFullName():lower()
        if full:find("hauntlet",1,true) then matches[#matches+1]=m end
    end
end
table.sort(matches,function(a,b) return a:GetFullName()<b:GetFullName() end)
log("LOADED_HAUNTLET_MODULES",#matches)

for _,m in ipairs(matches) do
    log("MODULE",m:GetFullName())
    local rok,result=pcall(require,m) -- already loaded: reads cached return value
    if rok then
        dumpSurface(result,m.Name,0,{})
    else
        log("CACHED_REQUIRE_FAILED",m:GetFullName(),result)
    end
end

log("END")
