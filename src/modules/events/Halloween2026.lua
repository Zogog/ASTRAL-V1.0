return function(ASTRAL)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local HttpService = game:GetService("HttpService")
    local Workspace = game:GetService("Workspace")

    local player = Players.LocalPlayer
    local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
    local load = Fsys.load
    local ClientData = load("ClientData")
    local RouterClient = load("RouterClient")

    local okInteriors, InteriorsM = pcall(load, "InteriorsM")
    if not okInteriors then InteriorsM = nil end
    local okMinigames, MinigameClientManager = pcall(load, "MinigameClientManager")
    if not okMinigames then MinigameClientManager = nil end

    local okKindDB, KindDB = pcall(load, "KindDB")
    if not okKindDB then KindDB = nil end

    local NewNet = ReplicatedStorage:WaitForChild("adoptme_new_net", 10)

    local Halloween = {
        Id = "halloween_2026",
        Name = "Halloween 2026",
        Page = "Events",
        Description = "Ghost Gallery, Crypt, Twigs, Candy Corn, quests, event shop and session statistics.",
        Version = "0.1.7-dev.6.12.2-hauntlet-coexistence",
        Implemented = true,
        Enabled = false,
        Busy = false,
        CurrentAction = "Idle",

        GhostEnabled = false,
        CryptEnabled = false,
        TwigEnabled = false,
        CandyEnabled = true,
        QuestEnabled = true,
        CryptMode = "Fast Spider",

        StartTime = os.time(),
        StartCandy = nil,
        Candy = 0,
        CandyEarned = 0,
        CandyPerHour = 0,
        CandyPerDay = 0,
        Keys = 0,
        KeysLooted = 0,
        LastKeyCount = nil,
        PendingCandy = 0,
        Twigs = 0,
        TwigsContributed = 0,
        GhostSeconds = nil,

        Shop = {},
        PendingPurchase = nil,
        LastPurchase = "No purchases this session",
        LastError = nil,
        LastGhostMessage = 0,
        PendingCryptLocks = {},
        -- A final Crypt floor remains final after ClaimTombSpider. Never
        -- re-send that purchase/claim on worker ticks. Arm only after this
        -- session has observed an active non-final Crypt floor.
        CryptFinalClaimArmed = false,
        GhostTarget = nil,
        GhostUseToken = nil,
        GhostTargetIsProp = false,
        GhostLastPulse = 0,
        GhostLastTargetScan = 0,
        LastCandyClaim = 0,
        LastTwigAttempt = 0,
        TwigRetryAt = 0,
        TwigRetryReason = nil,
    }

    local function log(message)
        print("[ASTRAL HALLOWEEN] " .. tostring(message))
        if ASTRAL.State then
            ASTRAL.State:Log("Halloween: " .. tostring(message))
        end
    end

    local function safeGet(key, raw)
        local ok, value = pcall(function()
            if raw then
                return ClientData.get(key, "Raw")
            end
            return ClientData.get(key)
        end)
        return ok and value or nil
    end

    local function getRemote(name)
        return ASTRAL.Game and ASTRAL.Game:GetRemote(name) or nil
    end

    local function getNet(name)
        if not NewNet then return nil end
        return NewNet:FindFirstChild(name) or NewNet:WaitForChild(name, 1)
    end

    local function wrapperLocation(wrapper)
        if type(wrapper) ~= "table" then return nil end
        local location = wrapper.location
        if type(location) == "table" then
            return location.destination_id or location.id or location.location or location.name
        end
        return type(location) == "string" and location or nil
    end

    local function getLocation()
        -- InteriorsM is useful when it reports an interior, but in the live
        -- HauntedHotel test it returned no id even though the transition had
        -- visibly completed. D&S 4.1.3 tracks the authoritative destination
        -- from ClientData's char_wrapper.location.destination_id, so mirror
        -- that source before falling back to the older generic location key.
        if InteriorsM and InteriorsM.get_current_location then
            local ok, location = pcall(InteriorsM.get_current_location)
            if ok and type(location) == "table" and location.id then
                return location.id
            end
        end

        local id = wrapperLocation(safeGet("char_wrapper", true))
            or wrapperLocation(safeGet("char_wrapper"))
        if id then return id end

        local okData, data = pcall(function()
            return ClientData.get_data and ClientData.get_data() or nil
        end)
        if okData and type(data) == "table" then
            local playerData = data[player.Name]
            if type(playerData) == "table" then
                id = wrapperLocation(playerData.char_wrapper)
                if id then return id end
            end
        end

        local location = safeGet("location")
        if type(location) == "table" then
            return location.destination_id or location.id or location.location or location.name or ""
        end
        return type(location) == "string" and location or ""
    end

    local function enterInterior(id, door, options)
        if getLocation() == id then return true end
        if not InteriorsM or not InteriorsM.enter_smooth then
            return false, "InteriorsM unavailable"
        end

        if getLocation() == "housing" then
            local unsubscribe = getRemote("HousingAPI/UnsubscribeFromHouse")
                or getRemote("HousingAPI/Unsubscribe")
            if unsubscribe then pcall(function() unsubscribe:InvokeServer() end) end
        end

        local ok, err = pcall(function()
            InteriorsM.enter_smooth(id, door or "MainDoor", options or {})
        end)
        if not ok then return false, err end

        local deadline = os.clock() + 10
        repeat
            if getLocation() == id then
                local download = getRemote("DownloadsAPI/Download")
                if download then
                    pcall(function() download:InvokeServer("Interiors", id) end)
                end
                return true
            end
            task.wait(0.25)
        until os.clock() >= deadline

        return false, "Timed out entering " .. tostring(id)
    end

    local function mainMap()
        if getLocation() == "MainMap" then return true end
        if InteriorsM and InteriorsM.enter_smooth then
            pcall(function() InteriorsM.enter_smooth("MainMap", "MainDoor", {}) end)
            local deadline = os.clock() + 8
            repeat
                if getLocation() == "MainMap" then return true end
                task.wait(0.25)
            until os.clock() >= deadline
        end
        return getLocation() == "MainMap"
    end

    local function character()
        local char = player.Character
        return char, char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
    end

    local function supportPlatform(root)
        local part = Workspace:FindFirstChild("ASTRAL_HalloweenPlatform")
        if not part then
            part = Instance.new("Part")
            part.Name = "ASTRAL_HalloweenPlatform"
            part.Anchored = true
            part.Size = Vector3.new(5, 1, 5)
            part.Transparency = 1
            part.CanCollide = true
            part.Parent = Workspace
        end
        if root then part.CFrame = root.CFrame * CFrame.new(0, -3.5, 0) end
        return part
    end

    local function inventory()
        return safeGet("inventory", true) or safeGet("inventory") or {}
    end

    local function countKind(kind)
        local count = 0
        for _, category in pairs(inventory()) do
            if type(category) == "table" then
                for _, item in pairs(category) do
                    if type(item) == "table" and tostring(item.kind or item.id) == kind then
                        count += 1
                    end
                end
            end
        end
        return count
    end

    local function findKindUniques(kind)
        local found = {}
        for _, category in pairs(inventory()) do
            if type(category) == "table" then
                for unique, item in pairs(category) do
                    if type(item) == "table" and tostring(item.kind or item.id) == kind then
                        table.insert(found, item.unique or unique)
                    end
                end
            end
        end
        return found
    end

    local function candyBalance()
        return tonumber(safeGet("candy_2026") or safeGet("candy") or 0) or 0
    end

    local function cycleSeconds()
        local data = safeGet("ghost_clusters_cycle_timestamp")
        if type(data) == "table" and data.timestamp then
            return tonumber(data.timestamp) - os.time()
        end
        return nil
    end

    local function currentMinigameId()
        if not MinigameClientManager or not MinigameClientManager.get then return nil end
        local ok, entry = pcall(function() return MinigameClientManager.get("ghost_clusters") end)
        if ok and entry and entry.instanced_minigame then
            return entry.instanced_minigame.minigame_id
        end
        return nil
    end

    local function stopGhostContribution()
        if Halloween.GhostTarget and Halloween.GhostUseToken then
            local id = currentMinigameId()
            local remote = getRemote("MinigameAPI/MessageServer")
            if id and remote then
                local action = Halloween.GhostTargetIsProp and "stop_prop_contribute" or "stop_contribute"
                local payload = {use_token = Halloween.GhostUseToken}
                if Halloween.GhostTargetIsProp then
                    payload.unique = Halloween.GhostTarget
                else
                    payload.ghost_id = Halloween.GhostTarget
                end
                pcall(function() remote:FireServer(id, action, payload) end)
            end
        end
        Halloween.GhostTarget = nil
        Halloween.GhostUseToken = nil
        Halloween.GhostTargetIsProp = false
    end

    local function ghostVisualPosition(id, fallback)
        local visuals = Workspace:FindFirstChild("GhostClustersVisuals")
        if visuals and id then
            for _, child in ipairs(visuals:GetChildren()) do
                if string.find(child.Name, tostring(id), 1, true) then
                    local part = child.PrimaryPart
                        or child:FindFirstChild("HumanoidRootPart")
                        or child:FindFirstChildWhichIsA("BasePart")
                    if part then return part.Position end
                end
            end
        end
        return fallback
    end

    local propRenderer
    pcall(function()
        propRenderer = require(
            ReplicatedStorage.SharedModules.ContentPacks.Halloween2026.Game.GhostClusters.GhostClustersPropRenderer
        )
    end)

    local function chooseGhostTarget(origin)
        local bestPart, bestId, bestProp
        local bestPriority, bestDistance = -1, math.huge
        local bossPresent = false
        local live = Workspace:FindFirstChild("GhostClustersLive")

        if live then
            for _, model in ipairs(live:GetDescendants()) do
                if model:IsA("Model") and model.PrimaryPart then
                    local id = model:GetAttribute("GhostClustersId")
                    if id then
                        local large = model:GetAttribute("GhostClustersSize") == "Large"
                        if large then bossPresent = true end
                        local progress = tonumber(model:GetAttribute("GhostClustersProgress")) or 0
                        local required = tonumber(model:GetAttribute("GhostClustersProgressRequired")) or 1
                        local isShield = model:GetAttribute("GhostClustersIsShield")
                        local shielded = model:GetAttribute("GhostClustersShielded")
                        local orbiting = model:GetAttribute("GhostClustersOrbiting")
                        local valid = progress < required and not orbiting
                        if large and shielded then valid = false end
                        if valid then
                            local priority = isShield and 4 or (large and 2 or 3)
                            local pos = ghostVisualPosition(id, model.PrimaryPart.Position)
                            local distance = (pos - origin).Magnitude
                            if priority > bestPriority or (priority == bestPriority and distance < bestDistance) then
                                bestPart, bestId, bestProp = model.PrimaryPart, id, false
                                bestPriority, bestDistance = priority, distance
                            end
                        end
                    end
                end
            end
        end

        if not bossPresent and propRenderer and propRenderer.get_targets and propRenderer.get_entry then
            pcall(function()
                for _, target in propRenderer.get_targets() do
                    local entry = propRenderer.get_entry(target.unique)
                    local model = target.model
                    if entry and entry.resolved == false and model then
                        local part = model:FindFirstChild("PlacementBlock") or model.PrimaryPart
                        if part then
                            local priority = entry.is_mural and 2 or 1
                            local distance = (part.Position - origin).Magnitude
                            if priority > bestPriority or (priority == bestPriority and distance < bestDistance) then
                                bestPart, bestId, bestProp = part, target.unique, true
                                bestPriority, bestDistance = priority, distance
                            end
                        end
                    end
                end
            end)
        end

        return bestPart, bestId, bestProp
    end

    local function equipVacuum()
        local char, _, humanoid = character()
        if not char or not humanoid then return false end
        local equipped = char:FindFirstChildWhichIsA("Tool")
        if equipped and string.find(string.lower(equipped.Name), "vacuum") then return true end
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") and string.find(string.lower(tool.Name), "vacuum") then
                    humanoid:EquipTool(tool)
                    return true
                end
            end
        end
        return false
    end

    local function runGhost()
        local seconds = cycleSeconds()
        Halloween.GhostSeconds = seconds
        if not seconds then
            Halloween.CurrentAction = "Ghost Gallery: waiting for event timer"
            return false
        end

        local location = getLocation()
        local minigameId = currentMinigameId()
        if minigameId or location == "ManorMinigameInterior" then
            Halloween.CurrentAction = "Ghost Gallery: farming arena"
            local char, root = character()
            if not char or not root then return false end
            equipVacuum()

            local part, id, isProp = chooseGhostTarget(root.Position)
            if not part or not id then
                stopGhostContribution()
                return true
            end

            if Halloween.GhostTarget ~= id or Halloween.GhostTargetIsProp ~= isProp then
                stopGhostContribution()
                Halloween.GhostTarget = id
                Halloween.GhostTargetIsProp = isProp
                Halloween.GhostUseToken = HttpService:GenerateGUID(false)
                Halloween.GhostLastPulse = 0
            end

            local position = isProp and part.Position or ghostVisualPosition(id, part.Position)
            local stand = position + Vector3.new(8, 12, 8)
            root.CFrame = CFrame.lookAt(
                Vector3.new(stand.X, math.clamp(stand.Y, 10, 35), stand.Z),
                position
            )
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            supportPlatform(root)

            if os.clock() - Halloween.GhostLastPulse >= 0.4 then
                Halloween.GhostLastPulse = os.clock()
                local remote = getRemote("MinigameAPI/MessageServer")
                if remote then
                    local action = isProp and "start_prop_contribute" or "start_contribute"
                    local payload = {use_token = Halloween.GhostUseToken}
                    if isProp then payload.unique = id else payload.ghost_id = id end
                    pcall(function() remote:FireServer(minigameId, action, payload) end)
                end
            end
            return true
        end

        stopGhostContribution()

        if location == "HauntedManor" then
            Halloween.CurrentAction = "Ghost Gallery: waiting in Haunted Manor"
            if seconds <= 15 and seconds > -135 then
                local _, root = character()
                local zone = Workspace:FindFirstChild("GhostClustersMinigameJoinZone", true)
                if root and zone then
                    local pivot = zone:GetPivot()
                    if (root.Position - pivot.Position).Magnitude > 8 then
                        root.CFrame = pivot * CFrame.new(0, 3, 0)
                    end
                end
            end
            return true
        end

        if seconds <= 15 and seconds > -135 then
            Halloween.CurrentAction = "Ghost Gallery: entering Haunted Manor"
            local ok = enterInterior("HauntedManor", "MainDoor", {
                spawn_cframe = CFrame.new(-5976.8955, 10010.6094, 9001.4785),
                start_transparency = 1,
            })
            return ok
        end

        Halloween.CurrentAction = string.format(
            "Ghost Gallery: next event %02d:%02d",
            math.max(0, math.floor(seconds / 60)),
            math.max(0, math.floor(seconds % 60))
        )
        return false
    end

    local CryptLayout
    pcall(function()
        CryptLayout = require(
            ReplicatedStorage.SharedModules.ContentPacks.Halloween2026.Game.TheCrypt.CryptLayout
        )
    end)

    local function hasRustyKey()
        return countKind("halloween_2026_rusty_key") > 0
    end

    local function equippedRustyKey()
        local char = player.Character
        local tool = char and char:FindFirstChild("Halloween2026RustyKey")
        return tool and tool:IsA("Tool") and tool or nil
    end

    local function equipRustyKey()
        if equippedRustyKey() then return true end
        local equip = getRemote("ToolAPI/Equip") or getRemote("InventoryAPI/Equip")
        local legacyEquip = getRemote("ToolAPI/Equip")
        local unique = findKindUniques("halloween_2026_rusty_key")[1]
        if not unique then return false end

        local candidates = {equip, legacyEquip}
        for _, remote in ipairs(candidates) do
            if remote then
                local ok = pcall(function() remote:InvokeServer(unique) end)
                if ok then
                    task.wait(0.5)
                    if equippedRustyKey() then return true end
                end
            end
        end

        -- D&S uses its cached API.Equip remote; resolve that exact name last.
        local exact = getRemote("ToolAPI/Equip") or getRemote("Equip")
        if exact then pcall(function() exact:InvokeServer(unique) end) end
        task.wait(0.5)
        return equippedRustyKey() ~= nil
    end

    local function emptyTable(value)
        return type(value) == "table" and next(value) == nil
    end

    local function runCrypt()
        if not hasRustyKey() then
            Halloween.CurrentAction = "Crypt: waiting for Rusty Keys"
            return false
        end

        local seconds = cycleSeconds()
        if Halloween.GhostEnabled and seconds and seconds <= 15 and seconds > -135 then
            Halloween.CurrentAction = "Crypt: yielding to Ghost Gallery"
            return false
        end

        if getLocation() ~= "TheCrypt" then
            Halloween.CurrentAction = "Crypt: loading The Crypt"
            local ok = enterInterior("TheCrypt", "MainDoor", {})
            if not ok then return false end
            task.wait(0.5)
        end

        local manager = safeGet("halloween_2026_crypt_manager")
        if type(manager) ~= "table" or type(manager.floors) ~= "table" or #manager.floors == 0 then
            Halloween.CurrentAction = "Crypt: waiting for floor state"
            return false
        end

        local floorIndex = #manager.floors
        local floor = manager.floors[floorIndex]
        local finalFloor = floor.is_final or floor.coffins == 0 or emptyTable(floor.coffins)

        if finalFloor then
            -- Runtime validation exposed an important server behaviour: the
            -- final manager state persists after a successful claim and the
            -- endpoint will accept another key on every call. ASTRAL used to
            -- hit this branch every worker pass, consuming every Rusty Key.
            -- Claim at most once after we have actually observed/progressed a
            -- non-final floor in this run. A fresh run rearms below.
            if not Halloween.CryptFinalClaimArmed then
                Halloween.CurrentAction = "Crypt: completed - waiting for a new run"
                return false
            end

            Halloween.CryptFinalClaimArmed = false
            Halloween.CurrentAction = "Crypt: claiming Tomb Spider"
            local claim = getNet("Halloween2026/ClaimTombSpider")
            if claim then
                local keysBefore = countKind("halloween_2026_rusty_key")
                local ok, result = pcall(function() return claim:InvokeServer() end)
                if ok then
                    Halloween.PendingCryptLocks = {}
                    task.wait(0.5)
                    local keysAfter = countKind("halloween_2026_rusty_key")
                    log(
                        "Tomb Spider claim sent once"
                        .. " | keys " .. tostring(keysBefore)
                        .. " -> " .. tostring(keysAfter)
                    )
                    return true
                end
                Halloween.LastError = tostring(result)
                log("Tomb Spider claim failed: " .. tostring(result))
            end
            return false
        end

        -- Seeing an active floor is the only thing that rearms the final
        -- reward. Merely toggling Crypt or changing modes cannot replay an
        -- already-completed final floor.
        Halloween.CryptFinalClaimArmed = true

        if not CryptLayout or not CryptLayout.floor_contents then
            Halloween.CurrentAction = "Crypt: layout module unavailable"
            return false
        end

        local okContents, contents = pcall(CryptLayout.floor_contents, floor)
        if not okContents or type(contents) ~= "table" then
            Halloween.CurrentAction = "Crypt: could not decode floor"
            return false
        end

        local opened = {}
        if type(manager.opened) == "table" then
            for _, index in ipairs(manager.opened) do opened[index] = true end
        end

        local ladder
        local rewards = {}
        for index, entry in pairs(contents) do
            local globalIndex = floorIndex * 16 + index
            if not opened[globalIndex] and not Halloween.PendingCryptLocks[globalIndex] then
                if entry.type == "ladder" then
                    ladder = index
                elseif Halloween.CryptMode == "All" then
                    table.insert(rewards, index)
                elseif Halloween.CryptMode == "Twigs + Spider"
                    and entry.reward
                    and entry.reward.kind == "halloween_2026_twig" then
                    table.insert(rewards, index)
                end
            end
        end

        if #rewards == 0 and not ladder then
            Halloween.CurrentAction = "Crypt: waiting for server sync"
            return false
        end

        if not equippedRustyKey() and not equipRustyKey() then
            Halloween.CurrentAction = "Crypt: could not equip Rusty Key"
            return false
        end

        local unlock = getNet("Halloween2026/UnlockPadlock")
        if not unlock then
            Halloween.CurrentAction = "Crypt: UnlockPadlock remote unavailable"
            return false
        end

        for _, index in ipairs(rewards) do
            if not hasRustyKey() then break end
            local globalIndex = floorIndex * 16 + index
            Halloween.PendingCryptLocks[globalIndex] = true
            Halloween.CurrentAction = "Crypt: looting coffin " .. tostring(index)
            pcall(function()
                unlock:InvokeServer({padlock_index = index, floor_index = floorIndex})
            end)
            task.wait(1.5)
        end

        if ladder and hasRustyKey() then
            local globalIndex = floorIndex * 16 + ladder
            Halloween.PendingCryptLocks[globalIndex] = true
            Halloween.CurrentAction = "Crypt: descending floor"
            pcall(function()
                unlock:InvokeServer({padlock_index = ladder, floor_index = floorIndex})
            end)
            task.wait(1.5)
        end

        return true
    end

    local function runTwigs()
        local nest = safeGet("halloween_2026_jacobean_pigeon_nest_manager")
        local contributed = type(nest) == "table" and tonumber(nest.twigs_contributed) or 0
        Halloween.TwigsContributed = contributed or 0
        local twigs = findKindUniques("halloween_2026_twig")
        Halloween.Twigs = #twigs

        if Halloween.TwigsContributed >= 8 then
            Halloween.TwigEnabled = false
            Halloween.CurrentAction = "Twigs: Jacobean Pigeon unlocked"
            return false
        end
        if #twigs == 0 then
            Halloween.CurrentAction = "Twigs: waiting for Twigs"
            return false
        end
        if os.clock() < Halloween.TwigRetryAt then
            Halloween.CurrentAction = "Twigs: retry paused - "
                .. tostring(Halloween.TwigRetryReason or "unknown reason")
            return false
        end

        Halloween.LastTwigAttempt = os.clock()
        local before = Halloween.TwigsContributed
        local wasInHotel = getLocation() == "HauntedHotel"

        if not wasInHotel then
            Halloween.CurrentAction = "Twigs: entering Haunted Hotel for pigeon nest"
            local ok, err = enterInterior("HauntedHotel", "MainDoor", {})
            if not ok then
                local reported = tostring(getLocation())
                Halloween.TwigRetryReason = "hotel entry not confirmed; location=" .. reported
                Halloween.LastError = "Twig: " .. Halloween.TwigRetryReason
                Halloween.TwigRetryAt = os.clock() + 10
                log(Halloween.TwigRetryReason .. " | " .. tostring(err))
                return false
            end

            log("Twig Hotel entry confirmed; location=" .. tostring(getLocation()))

            -- Match the D&S nest setup once on entry. Never stack this offset
            -- on repeated worker passes while already inside the Hotel.
            local _, root = character()
            if root then
                root.CFrame *= CFrame.new(0, 10, 0)
                root.AssemblyLinearVelocity = Vector3.zero
                supportPlatform(root)
            end
            task.wait(0.75)
        end

        local contribute = getNet("Halloween2026/JacobeanPigeonNestContributeTwig")
        if not contribute then
            local halloweenNames = {}
            if NewNet then
                for _, child in ipairs(NewNet:GetChildren()) do
                    local name = tostring(child.Name)
                    if string.find(string.lower(name), "halloween", 1, true)
                        or string.find(string.lower(name), "pigeon", 1, true)
                        or string.find(string.lower(name), "twig", 1, true) then
                        table.insert(halloweenNames, name)
                    end
                end
            end
            table.sort(halloweenNames)
            Halloween.TwigRetryReason = "contribution remote unavailable"
            Halloween.LastError = "Twig: " .. Halloween.TwigRetryReason
            Halloween.CurrentAction = "Twigs: " .. Halloween.TwigRetryReason
            Halloween.TwigRetryAt = os.clock() + 15
            log(
                Halloween.TwigRetryReason
                .. " | location=" .. tostring(getLocation())
                .. " | matching net children=["
                .. table.concat(halloweenNames, ",")
                .. "]"
            )
            return false
        end

        for _, unique in ipairs(twigs) do
            if Halloween.TwigsContributed >= 8 then break end
            Halloween.CurrentAction = string.format(
                "Twigs: placing %d/8",
                Halloween.TwigsContributed + 1
            )

            local callOk, result = pcall(function()
                return contribute:InvokeServer({unique = unique})
            end)
            if not callOk then
                Halloween.TwigRetryReason = "remote error: " .. tostring(result)
                Halloween.LastError = "Twig: " .. Halloween.TwigRetryReason
                log("Twig contribution " .. Halloween.TwigRetryReason)
                Halloween.TwigRetryAt = os.clock() + 15
                break
            end

            if type(result) == "table" and result.ok == false then
                local reason = tostring(result.reason or "unknown")
                Halloween.TwigRetryReason = "server rejected: " .. reason
                Halloween.LastError = "Twig: " .. Halloween.TwigRetryReason
                log(
                    "Twig contribution stopped: " .. reason
                    .. " | location=" .. tostring(getLocation())
                )
                Halloween.TwigRetryAt = os.clock() + (reason == "too_far" and 20 or 10)
                break
            end

            if type(result) == "table" and result.twigs_contributed then
                Halloween.TwigsContributed = tonumber(result.twigs_contributed)
                    or Halloween.TwigsContributed
            else
                Halloween.TwigsContributed += 1
            end
            Halloween.TwigRetryReason = nil
            log("Placed Twig: " .. tostring(Halloween.TwigsContributed) .. "/8")
            task.wait(1)
        end

        -- Re-read the authoritative manager instead of repeatedly assuming
        -- that a successful-looking remote call advanced the nest.
        task.wait(0.5)
        local afterNest = safeGet("halloween_2026_jacobean_pigeon_nest_manager")
        local after = type(afterNest) == "table"
            and tonumber(afterNest.twigs_contributed)
            or Halloween.TwigsContributed
        Halloween.TwigsContributed = after or Halloween.TwigsContributed

        if Halloween.TwigsContributed >= 8 then
            Halloween.TwigEnabled = false
            Halloween.CurrentAction = "Twigs: Jacobean Pigeon unlocked"
            log("Jacobean Pigeon twig requirement complete; Twig automation disabled")
        elseif Halloween.TwigsContributed <= before then
            Halloween.TwigRetryReason = Halloween.TwigRetryReason or "authoritative nest stayed at "
                .. tostring(before) .. "/8"
            Halloween.TwigRetryAt = math.max(Halloween.TwigRetryAt, os.clock() + 15)
            Halloween.CurrentAction = "Twigs: retry paused - " .. Halloween.TwigRetryReason
            log(
                "Twig attempt made no progress (" .. tostring(before)
                .. "/8) | " .. tostring(Halloween.TwigRetryReason)
            )
        end
        return true
    end

    local function runCandyClaim()
        local manager = safeGet("halloween_2026_candy_corn_pile_manager")
        local pending = type(manager) == "table" and tonumber(manager.pending) or 0
        Halloween.PendingCandy = pending or 0
        if Halloween.PendingCandy < 15000 then return false end
        if os.clock() - Halloween.LastCandyClaim < 15 then return false end

        local location = getLocation()
        -- Candy collection must never pull ASTRAL out of another Halloween
        -- activity. In dev.6.11.1 HauntedHotel was missing here, causing a
        -- loop: Twig worker -> HauntedHotel -> Candy claim -> MainMap -> repeat.
        local protectedHalloweenInterior = location == "ManorMinigameInterior"
            or location == "HauntedManor"
            or location == "HauntedHotel"
            or location == "TheCrypt"
            or string.find(location or "", "Minigame") ~= nil

        if protectedHalloweenInterior then
            return false
        end

        if not mainMap() then return false end
        local _, root = character()
        local pickup = Workspace:FindFirstChild("PickupArea", true)
        if not root or not pickup then
            Halloween.LastError = "Candy Corn PickupArea not found"
            return false
        end

        root.CFrame = pickup.CFrame * CFrame.new(0, 3, 0)
        root.AssemblyLinearVelocity = Vector3.zero
        supportPlatform(root)
        task.wait(0.5)

        local claim = getNet("Halloween2026/CandyCornPileClaim")
        if claim then
            Halloween.CurrentAction = "Candy Corn: claiming " .. tostring(Halloween.PendingCandy)
            local ok, err = pcall(function() claim:InvokeServer() end)
            Halloween.LastCandyClaim = os.clock()
            if not ok then Halloween.LastError = tostring(err) end
            task.wait(0.5)
            return ok
        end
        return false
    end

    local function runQuestClaims()
        local manager = safeGet("dailies_manager")
        local tab = type(manager) == "table"
            and type(manager.serialized_tabs) == "table"
            and manager.serialized_tabs.halloween_2026
            or nil
        if type(tab) ~= "table" then return false end

        local did = false
        if type(tab.active_dailies) == "table" then
            local claimDaily = getNet("adoptme_new.modules.Dailies.DailiesNetService:9")
            if claimDaily then
                for _, daily in pairs(tab.active_dailies) do
                    local state = type(daily) == "table" and daily.state
                    if type(state) == "table"
                        and tonumber(state.steps_completed or 0) >= tonumber(state.steps_to_complete or math.huge) then
                        pcall(function() claimDaily:FireServer("halloween_2026") end)
                        did = true
                        task.wait(0.25)
                    end
                end
            end
        end

        if tab.reward_claimed == false then
            local claimReward = getNet("adoptme_new.modules.Dailies.DailiesNetService:15")
            if claimReward then
                pcall(function() claimReward:FireServer("halloween_2026") end)
                did = true
            end
        end

        if did then Halloween.CurrentAction = "Halloween quests: rewards claimed" end
        return did
    end

    local SHOP_BLACKLIST = {
        halloween_2026_twig = true,
        halloween_2026_rusty_key = true,
        halloween_2026_polymorphing_cat_food = true,
        halloween_2026_jacobean_pigeon = true,
        halloween_2026_proton_pack = true,
        halloween_2026_ghost_vacuum = true,
        halloween_2026_ghost_vacuum_elite = true,
        halloween_2026_ghost_vacuum_grappling_hook = true,
        halloween_2026_nest_stroller = true,
        halloween_2026_prop_whip = true,
    }

    local function scanShop()
        local items = {}
        if type(KindDB) == "table" then
            for category, definitions in pairs(KindDB) do
                if type(definitions) == "table" then
                    for kind, data in pairs(definitions) do
                        if type(data) == "table"
                            and data.currency_id == "candy_2026"
                            and tonumber(data.cost)
                            and tonumber(data.cost) > 0
                            and data.donatable ~= false
                            and not SHOP_BLACKLIST[kind] then
                            table.insert(items, {
                                kind = kind,
                                name = data.name or kind,
                                price = tonumber(data.cost),
                                category = data.category or category or "toys",
                            })
                        end
                    end
                end
            end
        end
        table.sort(items, function(a, b)
            if a.price == b.price then return tostring(a.name) < tostring(b.name) end
            return a.price < b.price
        end)
        Halloween.Shop = items
    end

    local function runPurchase()
        local request = Halloween.PendingPurchase
        if not request then return false end
        Halloween.PendingPurchase = nil

        local item
        for _, candidate in ipairs(Halloween.Shop) do
            if candidate.kind == request.kind then item = candidate break end
        end
        if not item then
            Halloween.LastPurchase = "Purchase failed: item no longer in Halloween shop"
            return false
        end

        local amount = math.clamp(math.floor(tonumber(request.amount) or 1), 1, 100)
        local affordable = math.floor(candyBalance() / item.price)
        local actual = math.min(amount, affordable)
        if actual <= 0 then
            Halloween.LastPurchase = "Not enough Candy Corn for " .. tostring(item.name)
            return false
        end

        local buy = getRemote("ShopAPI/BuyItem")
        if not buy then
            Halloween.LastPurchase = "Purchase failed: ShopAPI unavailable"
            return false
        end

        Halloween.CurrentAction = "Shop: buying " .. tostring(actual) .. "x " .. tostring(item.name)
        local ok, result = pcall(function()
            return buy:InvokeServer(item.category, item.kind, {buy_count = actual})
        end)
        if ok then
            Halloween.LastPurchase = "Bought " .. tostring(actual) .. "x " .. tostring(item.name)
            log(Halloween.LastPurchase)
            return true
        end

        Halloween.LastPurchase = "Purchase failed: " .. tostring(result)
        Halloween.LastError = tostring(result)
        return false
    end

    function Halloween:QueuePurchase(kind, amount)
        if type(kind) ~= "string" or kind == "" then return false, "Item kind missing" end
        self.PendingPurchase = {
            kind = kind,
            amount = math.clamp(math.floor(tonumber(amount) or 1), 1, 100),
        }
        self.LastPurchase = "Queued purchase: " .. tostring(kind)
        return true
    end

    function Halloween:SetFeature(feature, enabled)
        enabled = enabled == true
        if feature == "ghost" then self.GhostEnabled = enabled
        elseif feature == "crypt" then self.CryptEnabled = enabled
        elseif feature == "twigs" then self.TwigEnabled = enabled
        elseif feature == "candy" then self.CandyEnabled = enabled
        elseif feature == "quests" then self.QuestEnabled = enabled
        else return false, "Unknown Halloween feature" end
        log(feature .. " = " .. (enabled and "ON" or "OFF"))
        return true
    end

    function Halloween:SetCryptMode(mode)
        if mode ~= "Fast Spider" and mode ~= "All" and mode ~= "Twigs + Spider" then
            return false, "Unknown Crypt mode"
        end
        self.CryptMode = mode
        log("Crypt mode = " .. mode)
        return true
    end

    function Halloween:SetEnabled(enabled)
        self.Enabled = enabled == true
        if not self.Enabled then
            self.Busy = false
            self.CurrentAction = "Idle"
            stopGhostContribution()
            ASTRAL.Scheduler:Release("halloween_2026")
            log("master disabled")
        else
            log("master enabled")
        end
        return true
    end

    function Halloween:GetShop()
        return self.Shop
    end

    function Halloween:GetStatus()
        return {
            enabled = self.Enabled,
            implemented = true,
            busy = self.Busy,
            message = self.Enabled and self.CurrentAction or "Off",
            ghost = self.GhostEnabled,
            crypt = self.CryptEnabled,
            twigs = self.TwigEnabled,
            candyClaim = self.CandyEnabled,
            quests = self.QuestEnabled,
            cryptMode = self.CryptMode,
            candy = self.Candy,
            earned = self.CandyEarned,
            perHour = self.CandyPerHour,
            perDay = self.CandyPerDay,
            keys = self.Keys,
            keysLooted = self.KeysLooted,
            pendingCandy = self.PendingCandy,
            twigsOwned = self.Twigs,
            twigsContributed = self.TwigsContributed,
            ghostSeconds = self.GhostSeconds,
            uptime = math.max(0, os.time() - self.StartTime),
            lastPurchase = self.LastPurchase,
            error = self.LastError,
        }
    end

    local function updateStats()
        local candy = candyBalance()
        if Halloween.StartCandy == nil then Halloween.StartCandy = candy end
        Halloween.Candy = candy
        Halloween.CandyEarned = math.max(0, candy - Halloween.StartCandy)
        local uptime = math.max(1, os.time() - Halloween.StartTime)
        Halloween.CandyPerHour = math.floor(Halloween.CandyEarned / uptime * 3600)
        Halloween.CandyPerDay = Halloween.CandyPerHour * 24

        local keys = countKind("halloween_2026_rusty_key")
        Halloween.Keys = keys
        if Halloween.LastKeyCount == nil then
            Halloween.LastKeyCount = keys
        elseif keys > Halloween.LastKeyCount then
            Halloween.KeysLooted += keys - Halloween.LastKeyCount
            Halloween.LastKeyCount = keys
        elseif keys < Halloween.LastKeyCount then
            -- Keys are consumable in the Crypt; preserve session loot count.
            Halloween.LastKeyCount = keys
        end

        local nest = safeGet("halloween_2026_jacobean_pigeon_nest_manager")
        Halloween.TwigsContributed = type(nest) == "table"
            and tonumber(nest.twigs_contributed or 0) or Halloween.TwigsContributed
        Halloween.Twigs = #findKindUniques("halloween_2026_twig")

        local pile = safeGet("halloween_2026_candy_corn_pile_manager")
        Halloween.PendingCandy = type(pile) == "table"
            and tonumber(pile.pending or 0) or 0
        Halloween.GhostSeconds = cycleSeconds()
    end

    scanShop()

    task.spawn(function()
        local statsTick = 0
        local questTick = 0
        while not ASTRAL.Runtime.Destroyed do
            if os.clock() - statsTick >= 1 then
                statsTick = os.clock()
                pcall(updateStats)
            end

            if Halloween.Enabled then
                local ok, err = pcall(function()
                    -- Hauntlet is a timed instanced run and owns scheduler priority 100.
                    -- Do not let Gallery/Crypt/Twig/shop actions teleport or mutate event
                    -- state while the integrated Hauntlet runner is participating.
                    local hauntlet = ASTRAL.Modules:Get("hauntlet_2")
                    if hauntlet and hauntlet.Attached then
                        Halloween.Busy = false
                        Halloween.CurrentAction = "Hauntlet 2 active - event actions paused"
                        ASTRAL.Scheduler:Release("halloween_2026")
                        return
                    end

                    if Halloween.PendingPurchase then
                        runPurchase()
                        return
                    end

                    if Halloween.QuestEnabled and os.clock() - questTick >= 5 then
                        questTick = os.clock()
                        runQuestClaims()
                    end

                    if Halloween.CandyEnabled and runCandyClaim() then return end

                    local farm = ASTRAL.Modules:Get("pet_farm")
                    if farm and farm.Busy then
                        Halloween.CurrentAction = "Waiting for current pet ailment"
                        return
                    end

                    local seconds = cycleSeconds()
                    local ghostDue = Halloween.GhostEnabled
                        and seconds
                        and seconds <= 15
                        and seconds > -135

                    local wantsAction = ghostDue
                        or Halloween.TwigEnabled
                        or Halloween.CryptEnabled
                        or Halloween.GhostEnabled

                    if not wantsAction then
                        Halloween.CurrentAction = "Monitoring quests, Candy Corn and shop"
                        return
                    end

                    if not ASTRAL.Scheduler:Request("halloween_2026", 90) then
                        Halloween.CurrentAction = "Waiting for scheduler"
                        return
                    end

                    Halloween.Busy = true
                    if ghostDue then
                        runGhost()
                    elseif Halloween.TwigEnabled
                        and Halloween.TwigsContributed < 8
                        and Halloween.Twigs > 0 then
                        runTwigs()
                    elseif Halloween.CryptEnabled and hasRustyKey() then
                        runCrypt()
                    elseif Halloween.GhostEnabled then
                        runGhost()
                    elseif Halloween.CryptEnabled then
                        Halloween.CurrentAction = "Crypt: waiting for Rusty Keys"
                    elseif Halloween.TwigEnabled then
                        Halloween.CurrentAction = Halloween.TwigsContributed >= 8
                            and "Twigs: Jacobean Pigeon unlocked"
                            or "Twigs: waiting for Twigs"
                    end
                    Halloween.Busy = false
                    ASTRAL.Scheduler:Release("halloween_2026")
                end)
                if not ok then
                    Halloween.Busy = false
                    ASTRAL.Scheduler:Release("halloween_2026")
                    Halloween.LastError = tostring(err)
                    Halloween.CurrentAction = "Error - see console"
                    warn("[ASTRAL HALLOWEEN] Cycle error:", err)
                end
            end

            task.wait(0.25)
        end
        stopGhostContribution()
        ASTRAL.Scheduler:Release("halloween_2026")
    end)

    ASTRAL.Modules:Register(Halloween)
    return Halloween
end
