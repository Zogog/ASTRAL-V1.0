--[[
    ASTRAL 1.0.0-dev.6.11.3 — Halloween Twig Diagnostics

    Only this loader is injected directly. Core/UI/feature modules
    are fetched independently from the repository.
    Repository: https://github.com/Zogog/ASTRAL-V1.0
]]

local ASTRAL = {
    Name = "ASTRAL",
    Version = "1.0.0-dev.6.11.6-crypt-claim-latch",
    Build = "Halloween 2026 suite + exact Twig diagnostics",

    Repository = {
        Owner = "Zogog",
        Name = "ASTRAL-V1.0",
        Branch = "main",
    },
    Boot = {
        Loaded = {},
        Failed = {},
    },
}

local env = getgenv and getgenv() or _G

-- dev.6.10.1 migration: preserve Neon Factory targets selected in the
-- previous planner instance before its runtime is destroyed.
if not env.ASTRALNeonTargets
    and env.ASTRAL
    and env.ASTRAL.Modules
    and env.ASTRAL.Modules.Get then
    pcall(function()
        local previousFactory = env.ASTRAL.Modules:Get("neon_factory")
        if previousFactory and type(previousFactory.Targets) == "table" then
            env.ASTRALNeonTargets = previousFactory.Targets
        end
    end)
end

-- Cleanly close a previous ASTRAL session before replacing it.
if env.ASTRAL and env.ASTRAL.Runtime and env.ASTRAL.Runtime.Destroy then
    pcall(function()
        env.ASTRAL.Runtime:Destroy()
    end)
end

env.ASTRAL = ASTRAL

local repo = ASTRAL.Repository
local BASE_URL = string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/",
    repo.Owner,
    repo.Name,
    repo.Branch
)
-- Ordered dependency manifest.
-- Required modules abort startup if they cannot be loaded.
-- Optional modules fail independently and ASTRAL continues.
local MANIFEST = {
    { id = "state",          path = "src/core/State.lua",          required = true  },
    { id = "config",         path = "src/core/Config.lua",         required = true  },
    { id = "runtime",        path = "src/core/Runtime.lua",        required = true  },
    { id = "anti_afk",       path = "src/core/AntiAFK.lua",        required = true  },
    { id = "scheduler",      path = "src/core/Scheduler.lua",      required = true  },
    { id = "game_api",       path = "src/core/GameAPI.lua",        required = true  },
    { id = "pet_api",        path = "src/core/PetAPI.lua",         required = true  },
    { id = "furniture_api",  path = "src/core/FurnitureAPI.lua",   required = true  },
    { id = "feeding_api",     path = "src/core/FeedingAPI.lua",       required = true  },
    { id = "feeding_support", path = "src/core/FeedingSupport.lua",   required = true  },
    { id = "ailment_support", path = "src/core/AilmentSupport.lua",   required = true  },
    { id = "movement_support",path = "src/core/MovementSupport.lua",  required = true  },
    { id = "module_manager",  path = "src/core/ModuleManager.lua",    required = true  },
    { id = "ailments",        path = "src/modules/autofarm/AilmentRegistry.lua", required = true },
    { id = "autofarm",        path = "src/modules/autofarm/Autofarm.lua", required = true },
    { id = "pet_queue",       path = "src/modules/pets/PetQueue.lua", required = true },
    { id = "egg_manager",     path = "src/modules/pets/EggManager.lua", required = true },
    { id = "pet_pens",        path = "src/modules/pets/PetPens.lua",  required = false },
    { id = "neon_factory",    path = "src/modules/pets/NeonFactory.lua", required = true },
    { id = "halloween_2026",  path = "src/modules/events/Halloween2026.lua", required = false },

    -- One file per core pet ailment.
    { id = "mystery",     path = "src/modules/autofarm/ailments/Mystery.lua",     required = true },
    { id = "sick",        path = "src/modules/autofarm/ailments/Sick.lua",        required = true },
    { id = "sleepy",      path = "src/modules/autofarm/ailments/Sleepy.lua",      required = true },
    { id = "dirty",       path = "src/modules/autofarm/ailments/Dirty.lua",       required = true },
    { id = "toilet",      path = "src/modules/autofarm/ailments/Toilet.lua",      required = true },
    { id = "school",      path = "src/modules/autofarm/ailments/School.lua",      required = true },
    { id = "salon",       path = "src/modules/autofarm/ailments/Salon.lua",       required = true },
    { id = "pizza_party", path = "src/modules/autofarm/ailments/PizzaParty.lua",  required = true },
    { id = "cat_cafe",    path = "src/modules/autofarm/ailments/CatCafe.lua",     required = true },
    { id = "camping",     path = "src/modules/autofarm/ailments/Camping.lua",     required = true },
    { id = "beach_party", path = "src/modules/autofarm/ailments/BeachParty.lua",  required = true },
    { id = "walk",        path = "src/modules/autofarm/ailments/Walk.lua",        required = true },
    { id = "ride",        path = "src/modules/autofarm/ailments/Ride.lua",        required = true },
    { id = "bored",       path = "src/modules/autofarm/ailments/Bored.lua",       required = true },
    { id = "hungry",      path = "src/modules/autofarm/ailments/Hungry.lua",      required = true },
    { id = "thirsty",     path = "src/modules/autofarm/ailments/Thirsty.lua",     required = true },
    { id = "pet_me",      path = "src/modules/autofarm/ailments/PetMe.lua",       required = true },
    { id = "play",        path = "src/modules/autofarm/ailments/Play.lua",        required = true },
    { id = "feature_stubs",  path = "src/modules/Stubs.lua",      required = false },
    { id = "window",         path = "src/ui/Window.lua",          required = true  },
}

local function fetch(path)
    local lastError
    for attempt = 1, 3 do
        -- A fresh query string on every request bypasses URL-based caches.
        -- This does not override an uncommitted GitHub change or replication delay.
        local nonce = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
        local url = BASE_URL .. path
            .. "?astral=" .. ASTRAL.Version
            .. "&fresh=" .. nonce
            .. "-" .. tostring(attempt)
        local ok, result = pcall(function()
            return game:HttpGet(url)
        end)

        if ok and type(result) == "string" and #result > 0 then
            return result
        end

        lastError = result or "empty response"
        if task and task.wait then
            task.wait(0.35 * attempt)
        end
    end

    return nil, tostring(lastError or "request failed")
end
local function loadModule(entry)
    local source, fetchError = fetch(entry.path)
    if not source then
        return false, "HTTP: " .. tostring(fetchError)
    end

    local chunk, compileError = loadstring(source, "@ASTRAL/" .. entry.path)
    if not chunk then
        return false, "Compile: " .. tostring(compileError)
    end

    local ok, exported = pcall(chunk)
    if not ok then
        return false, "Module execution: " .. tostring(exported)
    end
    -- ASTRAL modules normally export a function that receives shared context.
    if type(exported) == "function" then
        local initOk, initResult = pcall(exported, ASTRAL)
        if not initOk then
            return false, "Initialisation: " .. tostring(initResult)
        end
        exported = initResult
    end

    ASTRAL.Boot.Loaded[entry.id] = {
        path = entry.path,
        export = exported,
    }

    return true
end
local function fail(entry, reason)
    ASTRAL.Boot.Failed[entry.id] = {
        path = entry.path,
        required = entry.required,
        reason = reason,
    }

    warn(string.format(
        "[ASTRAL] %s module '%s' failed: %s",
        entry.required and "REQUIRED" or "Optional",
        entry.id,
        tostring(reason)
    ))
end

for _, entry in ipairs(MANIFEST) do
    local ok, reason = loadModule(entry)
    if ok then
        local loaded = ASTRAL.Boot.Loaded[entry.id]
        local exported = loaded and loaded.export
        local moduleVersion = type(exported) == "table" and exported.Version or nil
        print(string.format(
            "[ASTRAL] Loaded %s%s",
            entry.id,
            moduleVersion and (" [" .. tostring(moduleVersion) .. "]") or ""
        ))
    else
        fail(entry, reason)

        if entry.required then
            if ASTRAL.State then
                ASTRAL.State.Runtime = "BOOT FAILED"
            end
            error(string.format(
                "[ASTRAL] Startup aborted because required module '%s' could not load.\n%s",
                entry.id,
                tostring(reason)
            ))
        end
    end
end
if ASTRAL.State then
    ASTRAL.State.Runtime = "READY"
    ASTRAL.State:Log("ASTRAL " .. ASTRAL.Version .. " loaded")
    ASTRAL.State:Log(string.format(
        "Remote modules: %d loaded, %d failed",
        (function()
            local n = 0
            for _ in pairs(ASTRAL.Boot.Loaded) do n += 1 end
            return n
        end)(),
        (function()
            local n = 0
            for _ in pairs(ASTRAL.Boot.Failed) do n += 1 end
            return n
        end)()
    ))
end
if ASTRAL.UI and ASTRAL.UI.Refresh then
    ASTRAL.UI:Refresh()
end

print("[ASTRAL] " .. ASTRAL.Version .. " ready")
return ASTRAL
