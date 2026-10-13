-- ASTRAL Hauntlet 2 overnight runner v0.5.0
-- Persistent autonomous door + Nexus runner. Waits across runs until explicitly stopped.
-- Uses the live HauntletMinigameClient state and its own message_server("try_pick_door", index)
-- path discovered from the normal door callbacks. Adds one-shot verified item use.
-- Follows selected doors physically and automatically chooses Nexus/special-floor routes.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local env = getgenv and getgenv() or _G

-- Singleton: re-running this file replaces an older copy of this runner.
local TOKEN = {}
env.ASTRAL_HAUNTLET_RUNNER_TOKEN = TOKEN

local function alive()
    return env.ASTRAL_HAUNTLET_RUNNER_TOKEN == TOKEN
end

local function stopRunner()
    if env.ASTRAL_HAUNTLET_RUNNER_TOKEN == TOKEN then
        env.ASTRAL_HAUNTLET_RUNNER_TOKEN = nil
    end
end
env.ASTRAL_HAUNTLET_RUNNER_STOP = stopRunner

local function log(...)
    local out = {}
    for i = 1, select("#", ...) do
        out[i] = tostring(select(i, ...))
    end
    print("[ASTRAL HAUNTLET RUN v0.5.0] " .. table.concat(out, " "))
end

-- Anti-AFK is deliberately isolated from Hauntlet gameplay. It only responds
-- to Roblox's local Idled signal and is disconnected when this runner stops.
local antiAfkConnection = nil
local function startAntiAfk()
    local ok, virtualUser = pcall(function()
        return game:GetService("VirtualUser")
    end)
    if not ok or not virtualUser then
        log("ANTI-AFK unavailable - VirtualUser service not accessible")
        return
    end

    antiAfkConnection = player.Idled:Connect(function()
        if not alive() then return end
        local worked, err = pcall(function()
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new(0, 0))
        end)
        if worked then
            log("ANTI-AFK keepalive")
        else
            log("ANTI-AFK error", tostring(err))
        end
    end)
    log("ANTI-AFK armed")
end

startAntiAfk()

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

-- Nexus choices are authoritative in the started_room payload, but unlike
-- ordinary rooms they are not exposed as physical children of current_room.Doors.
-- Passively cache that payload so Room 10/20/etc can be selected immediately.
local nexusSnapshot = nil
local messageClientConnection = nil

local function startNexusCapture()
    local ok, remote = pcall(function()
        return game:GetService("ReplicatedStorage").API["MinigameAPI/MessageClient"]
    end)
    if not ok or not remote or not remote:IsA("RemoteEvent") then
        log("NEXUS CAPTURE unavailable - MessageClient remote not found")
        return
    end

    messageClientConnection = remote.OnClientEvent:Connect(function(minigameId, message, roomData)
        if not alive() or message ~= "started_room" or type(roomData) ~= "table"
            or roomData.kind ~= "nexus" or type(roomData.doors) ~= "table" then
            return
        end

        local choices = {}
        for index, doorData in ipairs(roomData.doors) do
            if type(doorData) == "table" then
                choices[#choices + 1] = {
                    index = index,
                    kind = "unknown",
                    area_kind = tostring(doorData.area_kind or "unknown"),
                    door = nil,
                }
            end
        end

        nexusSnapshot = {
            minigame_id = tostring(minigameId),
            choices = choices,
            captured_at = os.clock(),
        }

        local names = {}
        for _, choice in ipairs(choices) do
            names[#names + 1] = tostring(choice.index) .. ":" .. choice.area_kind
        end
        log("NEXUS PAYLOAD CAPTURED", table.concat(names, " | "))
    end)
end

startNexusCapture()

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
        local areaKind = tostring(door:GetAttribute("area_kind") or "unknown")
        choices[#choices + 1] = {
            index = index,
            kind = kind,
            area_kind = areaKind,
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

-- Nexus rooms use the same try_pick_door protocol as ordinary rooms. Their
-- two choices expose area_kind instead of a normal door kind.
local NEXUS_AREA_SCORE = {
    carnival = 10, copycat = 20, hallway = 25, spider = 30,
    laboratory = 40, mechanical = 50, nightmare = 60,
}

local function isNexusChoices(roomIndex, choices)
    if roomIndex < 1 or #choices ~= 2 then return false end
    for _, choice in ipairs(choices) do
        if choice.kind ~= "unknown" or choice.area_kind == "unknown" then
            return false
        end
    end
    return true
end

local function chooseNexus(choices)
    local ranked, summary = {}, {}
    for _, choice in ipairs(choices) do
        local score = NEXUS_AREA_SCORE[choice.area_kind] or 999
        choice.score = score
        ranked[#ranked + 1] = choice
        summary[#summary + 1] = string.format("%d:%s[score=%d]", choice.index, choice.area_kind, score)
    end
    table.sort(ranked, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        return a.index < b.index
    end)
    return ranked[1], table.concat(summary, " | ")
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
        -- Locked/Security/Golden doors have a separate lock-removal flow.
        -- Direct try_pick_door is not reliably accepted while locks remain, so
        -- keep them behind ordinary doors until that interaction is automated.
        if legal and choice.kind == "locked" then
            score = 190
        elseif legal and choice.kind == "security" then
            score = 230
        elseif legal and choice.kind == "gold_locked" then
            score = 260
        elseif legal and choice.kind == "bouncy" then
            -- Bounce can redirect the choice; do not treat ghost weight alone
            -- as proof that it is safer than an ordinary wooden door.
            score = 110
        end
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
local itemEffectConfirmed = {}
local itemLastConfirmedAt = {}
local itemRetryAfter = {}
local function healthString(runner)
    if not runner then return "?/?,temp=?" end
    return tostring(runner.health) .. "/" .. tostring(runner.max_health)
        .. ",temp=" .. tostring(runner.temp_health or 0)
end

local function useItemOnce(run, kind, roomIndex)
    if itemAutoDisabled or not alive() or not run.is_participating then return false end

    local nowClock = os.clock()
    if itemRetryAfter[kind] and nowClock < itemRetryAfter[kind] then
        log("ITEM BACKOFF", kind,
            string.format("%.1fs remaining", itemRetryAfter[kind] - nowClock))
        return false
    end
    if itemLastConfirmedAt[kind]
        and nowClock - itemLastConfirmedAt[kind] < 2.5 then
        log("ITEM COOLDOWN", kind,
            string.format("%.1fs since confirmed use", nowClock - itemLastConfirmedAt[kind]))
        return false
    end

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

    local beforeRunner = runner
    local beforeHealth = beforeRunner and tonumber(beforeRunner.health)
    local beforeMax = beforeRunner and tonumber(beforeRunner.max_health)
    local beforeTemp = beforeRunner and tonumber(beforeRunner.temp_health) or 0

    local started = os.clock()
    while alive() and run.is_participating and os.clock() - started < 1.5 do
        local after = inventoryCount(run, kind)
        local now = getRunner(run)
        local nowHealth = now and tonumber(now.health)
        local nowMax = now and tonumber(now.max_health)
        local nowTemp = now and tonumber(now.temp_health) or 0

        local stateEffect =
            (kind == "gold_potion" and beforeMax and nowMax and nowMax > beforeMax)
            or (kind == "red_potion" and beforeHealth and nowHealth and nowHealth > beforeHealth)
            or (kind == "ghost_potion" and nowTemp > beforeTemp)

        if after < before or stateEffect then
            itemEffectConfirmed[kind] = true
            itemLastConfirmedAt[kind] = os.clock()
            itemRetryAfter[kind] = nil
            log("ITEM CONFIRMED", kind,
                "count=" .. before .. "->" .. after,
                "state_effect=" .. tostring(stateEffect),
                "hp=" .. healthString(now))
            return true
        end
        task.wait(0.05)
    end

    -- A rejected/cooldown-limited consumable must not disable healing or other
    -- item types. Back off only this item briefly and keep the survival system live.
    itemRetryAfter[kind] = os.clock() + 2.5
    log("ITEM UNCONFIRMED", kind,
        "no inventory or health-state confirmation after 1.5s; per-item backoff only")
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
    if inventoryCount(run, "gold_potion") > 0
        and not itemEffectConfirmed.gold_potion then
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

-- Keep the real character physically with the route. Remote door selection can
-- advance authoritative room state without walking the avatar, which otherwise
-- leaves the player back at room 1 when the Nexus appears.
local function followDoor(choice)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local door = choice and choice.door
    if not root or not door or not door.Parent then
        return false, "character/root/door unavailable"
    end

    local ok, pivot = pcall(function()
        if door:IsA("Model") then
            return door:GetPivot()
        elseif door:IsA("BasePart") then
            return door.CFrame
        end
        local part = door:FindFirstChildWhichIsA("BasePart", true)
        return part and part.CFrame
    end)
    if not ok or typeof(pivot) ~= "CFrame" then
        return false, "door pivot unavailable"
    end

    -- Put the avatar just above the selected doorway. We deliberately do not
    -- guess which local Z direction is "through" the door; reaching the doorway
    -- is enough to keep the player alongside the generated route and avoids
    -- throwing them into geometry.
    local target = pivot + Vector3.new(0, 3, 0)
    local moved, err = pcall(function()
        character:PivotTo(target)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    if not moved then
        return false, tostring(err)
    end
    return true, string.format("%.1f,%.1f,%.1f", target.X, target.Y, target.Z)
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

log("ARMED - persistent overnight Hauntlet runner with survival items + Nexus routing")
log("POLICY gold heart early, red heart when damaged, ghost heart when vulnerable")
log("ITEM SAFETY per-item cooldown/backoff; one rejected potion cannot disable healing")
log("MOVEMENT follows each selected doorway so the avatar reaches the Nexus with the route")
log("NEXUS AUTO prefers Bounce House > Copycat > Spider Den > Security > Power Station > Nightmare")
log("PERSISTENCE waits for future Hauntlet runs after each run ends")
log("STOP with: getgenv().ASTRAL_HAUNTLET_RUNNER_STOP()")
log("NOTE this version does not yet start a new Hauntlet by itself; it takes over whenever a run becomes participating.")

local attached = false
local lastHandledRoom = nil
local stoppedForError = false

while alive() and task.wait(0.05) do
    local root = getClient()
    local run = root and root.instanced_minigame

    if run and run.is_participating then
        if not attached then
            attached = true
            lastHandledRoom = nil
            itemAutoDisabled = false
            itemAttempted = {}
            itemEffectConfirmed = {}
            itemLastConfirmedAt = {}
            itemRetryAfter = {}
            log("ATTACHED", tostring(run.minigame_id or "?"))
        end

        local roomIndex = tonumber(run.current_room_index) or 0
        local choices = currentChoices(run)

        -- Nexus room models can have no current_room.Doors children at all.
        -- Cobalt proved their two choices arrive in started_room instead, so
        -- substitute the captured authoritative payload for this minigame.
        if #choices == 0
            and nexusSnapshot
            and nexusSnapshot.minigame_id == tostring(run.minigame_id)
            and os.clock() - nexusSnapshot.captured_at < 35 then
            choices = nexusSnapshot.choices
        end

        if roomIndex >= 1
            and #choices > 0
            and run.selected_door_index == nil
            and run.confirmed_selected_door_index == nil
            and lastHandledRoom ~= roomIndex then

            lastHandledRoom = roomIndex
            local runner = getRunner(run)
            local nexus = isNexusChoices(roomIndex, choices)
            log(nexus and "NEXUS" or "ROOM", roomIndex, "hp=" .. healthString(runner))
            log("INVENTORY BEFORE", inventoryString(run))

            -- Nexus is a timed route decision, not a combat room. Do not spend
            -- 1.5 seconds probing consumables here; choose the floor immediately.
            if nexus then
                log("NEXUS ITEMS", "skipped - route selection takes priority")
            else
                useSurvivalItems(run, roomIndex)
                if not alive() or not run.is_participating then
                    log("RUN ENDED during item stage")
                    continue
                end
            end

            local choice, summary
            if nexus then
                choice, summary = chooseNexus(choices)
                log("NEXUS CHOICES", summary)
            else
                choice, summary = chooseDoor(run)
                log("AFTER ITEMS", "hp=" .. healthString(getRunner(run)))
                log("INVENTORY", inventoryString(run))
                log("CHOICES", summary)
            end

            if not choice then
                log("CURRENT RUN HALTED - no legal known choice found; waiting for this run to end")
                stoppedForError = true
            end

            if not choice then
                -- lastHandledRoom prevents this room being retried/spammed.
                continue
            end

            local label = nexus and choice.area_kind or choice.kind
            log(nexus and "NEXUS PICK" or "PICK",
                choice.index .. ":" .. label, "score=" .. tostring(choice.score))

            if nexus then
                -- Nexus has no physical Door object in current_room. The previous
                -- normal-room FOLLOW already keeps us at the front of the route;
                -- after server selection, the next normal room FOLLOW catches the
                -- avatar up immediately.
                log("NEXUS FOLLOW", "server route selection; next room will reposition avatar")
            else
                local followed, followResult = followDoor(choice)
                if followed then
                    log("FOLLOW", "door=" .. choice.index, "position=" .. followResult)
                else
                    log("FOLLOW SKIP", followResult)
                end
            end
            task.wait(0.05)

            local sent, result = sendDoorChoice(run, choice.index)
            if not sent then
                log("CURRENT RUN HALTED - try_pick_door failed:", result)
                stoppedForError = true
            end

            if not sent then
                continue
            end

            log("SENT", "try_pick_door", choice.index, nexus and "(NEXUS)" or "")
            local progressed, outcome = waitForOutcome(run, roomIndex, choice.index)
            if progressed then
                log(nexus and "NEXUS RESULT" or "RESULT", outcome)
                if nexus then
                    nexusSnapshot = nil
                end
            else
                log("CURRENT RUN HALTED -", outcome, "| no retry sent; waiting for run end")
                stoppedForError = true
            end
        elseif roomIndex >= 10 and #choices == 0 and lastHandledRoom ~= roomIndex then
            lastHandledRoom = roomIndex
            log("SPECIAL ROOM WAIT", "room=" .. roomIndex, "no selectable doors exposed yet")
        end
    elseif attached then
        log("RUN ENDED / DETACHED")
        attached = false
        lastHandledRoom = nil
        stoppedForError = false
        nexusSnapshot = nil
        log("WAITING - armed for the next Hauntlet run")
    end
end

log("STOP REQUESTED or runner replaced")

-- Explicit teardown, including Nexus capture and anti-AFK.
if messageClientConnection then
    pcall(function()
        messageClientConnection:Disconnect()
    end)
    messageClientConnection = nil
end
nexusSnapshot = nil

if antiAfkConnection then
    pcall(function()
        antiAfkConnection:Disconnect()
    end)
    antiAfkConnection = nil
end

if env.ASTRAL_HAUNTLET_RUNNER_STOP == stopRunner then
    env.ASTRAL_HAUNTLET_RUNNER_STOP = nil
end

if env.ASTRAL_HAUNTLET_RUNNER_TOKEN == TOKEN then
    env.ASTRAL_HAUNTLET_RUNNER_TOKEN = nil
end
log("STOPPED - runner and anti-AFK fully unloaded")
