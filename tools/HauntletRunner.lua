-- ASTRAL Hauntlet 2 standalone runner v0.3
-- Autonomous door runner with inter-floor handoff. Starts only after the normal Hauntlet client is participating.
-- Uses the live HauntletMinigameClient state and its own message_server("try_pick_door", index)
-- path discovered from the normal door callbacks. Adds one-shot verified item use.
-- No movement/teleport simulation. Special-floor choices remain manual.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local env = getgenv and getgenv() or _G

-- Singleton: re-running this file replaces an older copy of this runner.
local TOKEN = {}
env.ASTRAL_HAUNTLET_RUNNER_TOKEN = TOKEN

local function alive()
    return env.ASTRAL_HAUNTLET_RUNNER_TOKEN == TOKEN
end

local function log(...)
    local out = {}
    for i = 1, select("#", ...) do
        out[i] = tostring(select(i, ...))
    end
    print("[ASTRAL HAUNTLET RUN v0.3] " .. table.concat(out, " "))
end

local function getClient()
    if type(getloadedmodules) ~= "function" then
        return nil
    end

    local ok, modules = pcall(getloadedmodules)
    if not ok or type(modules) ~= "table" then
        return nil
    end

    for _, module in ipairs(modules) do
        if typeof(module) == "Instance"
            and module:IsA("ModuleScript")
            and module.Name == "HauntletMinigameClient"
            and module:GetFullName():find("Halloween2026", 1, true) then
            local required, result = pcall(require, module)
            if required and type(result) == "table" then
                return result
            end
        end
    end

    return nil
end

local function getRunner(run)
    if type(run) ~= "table" or type(run.runners) ~= "table" then
        return nil
    end

    if type(run.runners[player.Name]) == "table" then
        return run.runners[player.Name]
    end

    local modelName = run.player_model and run.player_model.Name
    if modelName and type(run.runners[modelName]) == "table" then
        return run.runners[modelName]
    end

    local only
    local count = 0
    for _, value in pairs(run.runners) do
        if type(value) == "table" and value.health ~= nil then
            only = value
            count += 1
        end
    end
    if count == 1 then
        return only
    end

    return nil
end

local function inventoryCount(run, kind)
    local inventory = run and run.inventory
    if type(inventory) ~= "table" then
        return 0
    end
    return tonumber(inventory[kind]) or 0
end

local function inventoryString(run)
    local kinds = {
        "cell_phone", "ghost_potion", "key", "gold_key",
        "gold_potion", "rainbow_wand", "red_potion",
    }
    local out = {}
    for _, kind in ipairs(kinds) do
        out[#out + 1] = kind .. "=" .. tostring(inventoryCount(run, kind))
    end
    return table.concat(out, ",")
end

-- Values observed directly in Halloween 2026 HauntletDoorDB.
-- Lower ghost weight is treated as safer, with conservative penalties for
-- spending keys, losing health/items, or using still-unproven transforms.
local DOORS = {
    wooden      = { ghost = 90,  score = 90,  note = "baseline" },
    bouncy      = { ghost = 80,  score = 80,  note = "bounce" },
    rotten      = { ghost = 120, score = 120, note = "higher ghost weight" },
    shadow      = { ghost = 150, score = 150, note = "high ghost weight" },
    nightmare   = { ghost = 180, score = 180, note = "highest ghost weight" },
    copycat     = { ghost = 0,   score = 140, note = "transform effect - conservative penalty" },
    electric    = { ghost = 30,  score = 230, note = "costs 1 heart" },
    webbed      = { ghost = 5,   score = 240, note = "loses 1 item" },
    locked      = { ghost = 30,  score = 190, note = "costs 1 grey key", grey = 1 },
    security    = { ghost = 20,  score = 230, note = "costs 2 grey keys", grey = 2 },
    gold_locked = { ghost = 0,   score = 260, note = "costs 1 gold key", gold = 1 },
}

local function currentChoices(run)
    local room = run and run.current_room
    local doorsFolder = room and room:FindFirstChild("Doors")
    if not doorsFolder then
        return {}
    end

    local raw = doorsFolder:GetChildren()
    table.sort(raw, function(a, b)
        local ai, bi = tonumber(a.Name), tonumber(b.Name)
        if ai and bi then return ai < bi end
        if ai then return true end
        if bi then return false end
        return tostring(a.Name) < tostring(b.Name)
    end)

    local choices = {}
    for ordinal, door in ipairs(raw) do
        local index = tonumber(door.Name) or ordinal
        local kind = tostring(door:GetAttribute("kind") or "unknown")
        choices[#choices + 1] = {
            index = index,
            kind = kind,
            door = door,
        }
    end
    return choices
end

local function isLegal(run, runner, choice)
    local profile = DOORS[choice.kind]
    if not profile then
        return false, "unknown door kind"
    end

    if profile.grey and inventoryCount(run, "key") < profile.grey then
        return false, "needs " .. profile.grey .. " grey key(s)"
    end
    if profile.gold and inventoryCount(run, "gold_key") < profile.gold then
        return false, "needs " .. profile.gold .. " gold key(s)"
    end

    if choice.kind == "electric" then
        local health = runner and tonumber(runner.health)
        local temp = runner and tonumber(runner.temp_health) or 0
        if health and (health + temp) <= 1 then
            return false, "would spend final heart"
        end
    end

    return true
end

local function chooseDoor(run)
    local runner = getRunner(run)
    local choices = currentChoices(run)
    local candidates = {}
    local summary = {}

    for _, choice in ipairs(choices) do
        local legal, reason = isLegal(run, runner, choice)
        local profile = DOORS[choice.kind]
        local score = profile and profile.score or 9999
        summary[#summary + 1] = string.format(
            "%d:%s[%s%s]",
            choice.index,
            choice.kind,
            legal and ("score=" .. score) or "BLOCKED",
            legal and "" or (":" .. tostring(reason))
        )
        if legal then
            choice.score = score
            candidates[#candidates + 1] = choice
        end
    end

    table.sort(candidates, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        local preference = { [2] = 1, [1] = 2, [3] = 3 }
        return (preference[a.index] or 9) < (preference[b.index] or 9)
    end)

    return candidates[1], table.concat(summary, " | ")
end

-- Item-use route was recovered from the live Hauntlet hotbar callback:
-- message_server("try_use_item", itemKind). Exact argument behavior is being
-- validated here. Never retry an unconfirmed use, and disable further automatic
-- item requests for this run if the first one does not change authoritative state.
local itemAutoDisabled = false
local itemAttempted = {}
local function healthString(runner)
    if not runner then return "?/?,temp=?" end
    return tostring(runner.health) .. "/" .. tostring(runner.max_health)
        .. ",temp=" .. tostring(runner.temp_health or 0)
end

local function useItemOnce(run, kind, roomIndex)
    if itemAutoDisabled or not alive() or not run.is_participating then return false end
    local key = tostring(roomIndex) .. ":" .. kind
    if itemAttempted[key] then return false end
    local before = inventoryCount(run, kind)
    if before < 1 then return false end
    itemAttempted[key] = true

    if type(run.message_server) ~= "function" then
        log("ITEM DISABLED - live run has no message_server")
        itemAutoDisabled = true
        return false
    end

    local runner = getRunner(run)
    local hpBefore = healthString(runner)
    log("ITEM TRY", kind, "room=" .. roomIndex,
        "count=" .. before, "hp=" .. hpBefore)
    local ok, result = pcall(function()
        return run:message_server("try_use_item", kind)
    end)
    if not ok then
        log("ITEM DISABLED - try_use_item error", kind, tostring(result))
        itemAutoDisabled = true
        return false
    end

    local started = os.clock()
    while alive() and run.is_participating and os.clock() - started < 1.5 do
        local after = inventoryCount(run, kind)
        if after < before then
            log("ITEM CONFIRMED", kind, "count=" .. before .. "->" .. after,
                "hp=" .. healthString(getRunner(run)))
            return true
        end
        task.wait(0.05)
    end

    log("ITEM UNCONFIRMED", kind,
        "no inventory decrement after 1.5s; disabling auto-items for this run")
    itemAutoDisabled = true
    return false
end

local function useSurvivalItems(run, roomIndex)
    if itemAutoDisabled then return end
    local runner = getRunner(run)
    if not runner then
        log("ITEM SKIP - runner health unavailable")
        return
    end

    -- A Golden Heart Potion increases max red hearts. The 2026 game notes say
    -- it does not refill previously missing hearts. Use early to gain capacity.
    if inventoryCount(run, "gold_potion") > 0 then
        useItemOnce(run, "gold_potion", roomIndex)
    end

    runner = getRunner(run)
    if itemAutoDisabled or not runner or not run.is_participating then return end
    local hp = tonumber(runner.health)
    local maxHp = tonumber(runner.max_health)
    if not hp or not maxHp then return end

    -- Red Heart Potion restores missing red hearts. Save until critical health
    -- or until at least two red hearts are missing.
    if inventoryCount(run, "red_potion") > 0
        and hp < maxHp
        and (hp <= 1 or maxHp - hp >= 2) then
        useItemOnce(run, "red_potion", roomIndex)
    end

    runner = getRunner(run)
    if itemAutoDisabled or not runner or not run.is_participating then return end
    hp = tonumber(runner.health)
    local temp = tonumber(runner.temp_health) or 0
    if hp and hp <= 2 and temp < 1
        and inventoryCount(run, "ghost_potion") > 0 then
        -- Temporary heart protects against damage for the next door.
        useItemOnce(run, "ghost_potion", roomIndex)
    end

    -- Cell Phone, Rainbow Wand and door-selection information are deliberately
    -- left untouched until we verify their precise client interaction/results.
end

local function sendDoorChoice(run, index)
    if type(run.message_server) ~= "function" then
        return false, "live run has no message_server function"
    end

    -- Mirror the normal client callback: selected first, confirmation remains server-owned.
    run.selected_door_index = index
    local ok, result = pcall(function()
        return run:message_server("try_pick_door", index)
    end)
    if not ok then
        run.selected_door_index = nil
        return false, tostring(result)
    end
    return true, result
end

local function waitForOutcome(run, roomBefore, index)
    local started = os.clock()
    local confirmed = false

    while alive() and os.clock() - started < 8 do
        if not run.is_participating then
            return true, "run ended"
        end

        local roomNow = tonumber(run.current_room_index) or 0
        if roomNow ~= roomBefore then
            return true, "advanced to room " .. tostring(roomNow)
        end

        if run.confirmed_selected_door_index == index and not confirmed then
            confirmed = true
            log("SERVER CONFIRMED", "room=" .. roomBefore, "door=" .. index)
        end

        task.wait(0.05)
    end

    if confirmed then
        return false, "server confirmed door but room did not advance within 8s"
    end
    return false, "door was not server-confirmed within 8s"
end

log("ARMED - autonomous Hauntlet with survival item use")
log("POLICY gold heart early, red heart when damaged, ghost heart when vulnerable")
log("ITEM SAFETY one request per item/room; disable items on first unconfirmed response")
log("Start Hauntlet normally; this script takes over once room choices are live.")

local attached = false
local lastHandledRoom = nil
local waitingForInterfloor = false
local stoppedForError = false

while alive() and task.wait(0.05) do
    local root = getClient()
    local run = root and root.instanced_minigame

    if run and run.is_participating then
        if not attached then
            attached = true
            lastHandledRoom = nil
            waitingForInterfloor = false
            itemAutoDisabled = false
            itemAttempted = {}
            log("ATTACHED", tostring(run.minigame_id or "?"))
        end

        local roomIndex = tonumber(run.current_room_index) or 0
        local choices = currentChoices(run)

        -- Every tenth room is an inter-floor/Nexus choice rather than a normal
        -- three-door room. We have not yet captured that interaction path, so do
        -- not guess or spam a message. Hand that choice to the player, then resume
        -- automatically as soon as the next normal room appears.
        if roomIndex >= 10 and roomIndex % 10 == 0 and #choices == 0 then
            if not waitingForInterfloor then
                waitingForInterfloor = true
                lastHandledRoom = roomIndex
                local runner = getRunner(run)
                log("INTER-FLOOR", "room=" .. roomIndex,
                    "room_model=" .. tostring(run.current_room and run.current_room.Name),
                    "hp=" .. tostring(runner and runner.health or "?"))
                log("INVENTORY", inventoryString(run))
                log("MANUAL ACTION NEEDED - choose the between-floor minigame; runner will resume automatically afterward")
            end
        elseif #choices > 0 and waitingForInterfloor then
            waitingForInterfloor = false
            lastHandledRoom = nil
            log("INTER-FLOOR COMPLETE - normal doors returned; autonomous running resumed")
        end

        if roomIndex >= 1
            and #choices > 0
            and run.selected_door_index == nil
            and run.confirmed_selected_door_index == nil
            and lastHandledRoom ~= roomIndex then

            lastHandledRoom = roomIndex
            local runner = getRunner(run)
            local hp = runner and tonumber(runner.health) or "?"
            local temp = runner and tonumber(runner.temp_health) or "?"
            log("ROOM", roomIndex, "hp=" .. healthString(runner))
            log("INVENTORY BEFORE", inventoryString(run))
            useSurvivalItems(run, roomIndex)
            if not alive() or not run.is_participating then
                log("RUN ENDED during item stage")
                break
            end
            local choice, summary = chooseDoor(run)
            log("AFTER ITEMS", "hp=" .. healthString(getRunner(run)))
            log("INVENTORY", inventoryString(run))
            log("CHOICES", summary)

            if not choice then
                log("STOP - no legal known door found; leaving control to you")
                stoppedForError = true
                break
            end

            log("PICK", choice.index .. ":" .. choice.kind, "score=" .. tostring(choice.score))
            local sent, result = sendDoorChoice(run, choice.index)
            if not sent then
                log("STOP - try_pick_door failed:", result)
                stoppedForError = true
                break
            end

            log("SENT", "try_pick_door", choice.index)
            local progressed, outcome = waitForOutcome(run, roomIndex, choice.index)
            if progressed then
                log("RESULT", outcome)
            else
                log("STOP -", outcome, "| no retry sent")
                stoppedForError = true
                break
            end
        end
    elseif attached then
        log("RUN ENDED / DETACHED")
        attached = false
        lastHandledRoom = nil
        break
    end
end

if not alive() then
    log("REPLACED by a newer runner instance")
elseif stoppedForError then
    log("HALTED safely - manual control remains available")
else
    log("DONE")
end

-- Explicit teardown. There are no event connections or spawned worker loops in
-- this standalone runner; clearing the singleton token removes its final global
-- reference as well. After this point this copy has no code left executing.
if env.ASTRAL_HAUNTLET_RUNNER_TOKEN == TOKEN then
    env.ASTRAL_HAUNTLET_RUNNER_TOKEN = nil
end
log("STOPPED - runner fully unloaded")
