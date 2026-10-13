-- ASTRAL Lures v0.1.0
-- Evidence-backed lifecycle from Dusk & Shine 4.1.3:
-- inspect lures_2023_lure_manager -> enter/subscribe own house ->
-- ActivateFurniture UseBlock(false) to collect -> UseBlock({bait_unique=...}) to charge.
return function(ASTRAL)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Player = Players.LocalPlayer
    local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
    local ClientData = Fsys.load("ClientData")
    local InventoryDB = Fsys.load("InventoryDB")
    local LuresConfig
    pcall(function() LuresConfig = Fsys.load("LuresConfig") end)

    local Lures = {
        Id = "lures",
        Name = "Lures",
        Page = "Inventory",
        Description = "Automatically collect completed lures and recharge them for long sessions.",
        Version = "0.1.0-dev.6.12-lure-lifecycle",
        Implemented = true,
        Enabled = false,
        Busy = false,
        Interval = 10,
        LastCycle = 0,
        LastMessage = "Off",
        LastAction = "None",
        SelectedBait = nil, -- nil = AUTO (largest compatible owned stack)
        BaitSnapshots = {},
        LureSnapshots = {},
        SessionCollected = 0,
        SessionCharged = 0,
    }

    local function log(message)
        print("[ASTRAL LURES] " .. tostring(message))
        if ASTRAL.State then
            pcall(function() ASTRAL.State:Log("Lures: " .. tostring(message)) end)
        end
    end

    local function remote(name)
        return ASTRAL.Game and ASTRAL.Game:GetRemote(name) or nil
    end

    local function fire(name, ...)
        local r = remote(name)
        if not r then return false, name .. " unavailable" end
        local args = table.pack(...)
        local ok, err = pcall(function() r:FireServer(table.unpack(args, 1, args.n)) end)
        return ok, ok and nil or tostring(err)
    end

    local function invoke(name, ...)
        local r = remote(name)
        if not r then return false, name .. " unavailable" end
        local args = table.pack(...)
        local ok, result = pcall(function()
            return r:InvokeServer(table.unpack(args, 1, args.n))
        end)
        return ok, ok and result or tostring(result)
    end

    local function client(path)
        local ok, value = pcall(function() return ClientData.get(path) end)
        return ok and value or nil
    end

    local function lureManager()
        local value = client("lures_2023_lure_manager")
        return type(value) == "table" and value or {}
    end

    local function containsPremium(value, depth)
        if depth > 4 or type(value) ~= "table" then return false end
        for k, v in pairs(value) do
            if tostring(k) == "lures_2023_cozy_home_lure"
                or tostring(v) == "lures_2023_cozy_home_lure" then
                return true
            end
            if type(v) == "table" and containsPremium(v, depth + 1) then return true end
        end
        return false
    end

    local function lureDefinitions()
        local defs = {
            {mapName = "BasicLure", furniKind = "lures_2023_normal_lure"},
        }
        local manager = lureManager()
        local gamepasses = client("gamepass_manager") or {}
        local hasPremium = containsPremium(gamepasses, 0)
            or (type(manager.lures_map) == "table" and manager.lures_map.PremiumLure ~= nil)
        if hasPremium then
            table.insert(defs, {
                mapName = "PremiumLure",
                furniKind = "lures_2023_cozy_home_lure",
            })
        end
        return defs
    end

    local function baitDuration(kind)
        local duration = 14400
        pcall(function()
            local entry = (InventoryDB.food and InventoryDB.food[kind])
                or (InventoryDB.pets and InventoryDB.pets[kind])
                or (InventoryDB.toys and InventoryDB.toys[kind])
            if entry and tonumber(entry.lure_time) then
                duration = tonumber(entry.lure_time)
            elseif LuresConfig and LuresConfig.Baits and LuresConfig.Baits[kind] then
                duration = tonumber(LuresConfig.Baits[kind].Duration) or duration
            end
        end)
        return duration
    end

    local function isCompatibleBait(kind)
        if not kind then return false end
        if LuresConfig and type(LuresConfig.Baits) == "table" then
            return LuresConfig.Baits[kind] ~= nil
        end
        -- If LuresConfig cannot be loaded, do not guess which food can be bait.
        return false
    end

    function Lures:RefreshBaits()
        local inventory = client("inventory")
        local food = type(inventory) == "table" and inventory.food or {}
        local grouped = {}
        if type(food) == "table" then
            for unique, item in pairs(food) do
                if type(item) == "table" then
                    local kind = tostring(item.kind or item.id or "")
                    if kind ~= "" and isCompatibleBait(kind) then
                        local row = grouped[kind]
                        if not row then
                            row = {kind = kind, count = 0, uniques = {}}
                            grouped[kind] = row
                        end
                        row.count += 1
                        table.insert(row.uniques, tostring(unique))
                    end
                end
            end
        end

        local rows = {}
        for _, row in pairs(grouped) do
            table.sort(row.uniques)
            table.insert(rows, row)
        end
        table.sort(rows, function(a, b)
            if a.count == b.count then return a.kind < b.kind end
            return a.count > b.count
        end)
        self.BaitSnapshots = rows
        return rows
    end

    function Lures:GetBaits()
        local copy = {}
        for i, row in ipairs(self.BaitSnapshots) do
            copy[i] = {kind = row.kind, count = row.count}
        end
        return copy
    end

    function Lures:SetSelectedBait(kind)
        if kind == nil or kind == "" or kind == "AUTO" then
            self.SelectedBait = nil
            self.LastMessage = "Bait: AUTO"
            return true
        end
        for _, row in ipairs(self.BaitSnapshots) do
            if row.kind == kind and row.count > 0 then
                self.SelectedBait = kind
                self.LastMessage = "Bait: " .. kind
                return true
            end
        end
        return false, "Compatible bait is not currently owned"
    end

    function Lures:ChooseBait()
        self:RefreshBaits()
        if self.SelectedBait then
            for _, row in ipairs(self.BaitSnapshots) do
                if row.kind == self.SelectedBait and row.count > 0 then
                    return row.kind, row.uniques[1], row.count
                end
            end
            return nil, nil, 0
        end
        local row = self.BaitSnapshots[1]
        return row and row.kind, row and row.uniques[1], row and row.count or 0
    end

    local function isFinished(state)
        if type(state) ~= "table" then return false end
        if state.finished == true then return true end
        local kind = state.bait_kind or state.bait_id or state.bait
        local started = tonumber(state.lure_start_timestamp or state.start_timestamp or 0) or 0
        return kind ~= nil and started > 0 and started + baitDuration(kind) <= os.time()
    end

    function Lures:RefreshLures()
        local manager = lureManager()
        local map = type(manager.lures_map) == "table" and manager.lures_map or {}
        local rows = {}
        for _, def in ipairs(lureDefinitions()) do
            local state = map[def.mapName]
            local status = "EMPTY"
            local baitKind
            local remaining
            if type(state) == "table" then
                baitKind = state.bait_kind or state.bait_id or state.bait
                if isFinished(state) then
                    status = "READY"
                    remaining = 0
                else
                    status = "RUNNING"
                    local started = tonumber(state.lure_start_timestamp or state.start_timestamp or 0) or 0
                    if started > 0 and baitKind then
                        remaining = math.max(0, started + baitDuration(baitKind) - os.time())
                    end
                end
            end
            table.insert(rows, {
                mapName = def.mapName,
                furniKind = def.furniKind,
                status = status,
                baitKind = baitKind,
                remaining = remaining,
            })
        end
        self.LureSnapshots = rows
        return rows
    end

    function Lures:GetLures()
        local copy = {}
        for i, row in ipairs(self.LureSnapshots) do
            local out = {}
            for k, v in pairs(row) do out[k] = v end
            copy[i] = out
        end
        return copy
    end

    function Lures:GetStatus()
        return {
            enabled = self.Enabled,
            implemented = true,
            busy = self.Busy,
            message = self.LastMessage,
            action = self.LastAction,
            selectedBait = self.SelectedBait or "AUTO",
            collected = self.SessionCollected,
            charged = self.SessionCharged,
        }
    end

    function Lures:SetEnabled(enabled)
        self.Enabled = enabled == true
        self.LastCycle = 0
        self.LastMessage = self.Enabled and "Watching lure state" or "Off"
        log(self.Enabled and "enabled" or "disabled")
        return true
    end

    local function currentHouseFurniture()
        local data = ClientData.get_data()
        local interior
        if type(data) == "table" and type(data[Player.Name]) == "table" then
            interior = data[Player.Name].house_interior
        end
        interior = interior or client("house_interior")
        return type(interior) == "table" and type(interior.furniture) == "table"
            and interior.furniture or {}
    end

    local function findFurniture(kind)
        for unique, wrapper in pairs(currentHouseFurniture()) do
            local data = type(wrapper) == "table" and (wrapper.data or wrapper) or nil
            if type(data) == "table" and tostring(data.id or "") == kind then
                return tostring(data.unique or unique)
            end
        end
        return nil
    end

    function Lures:EnterHouse()
        local house = workspace:FindFirstChild("HouseInteriors")
        local blueprint = house and house:FindFirstChild("blueprint")
        if blueprint and blueprint:FindFirstChild(Player.Name) then return true end

        local ok, err = fire("LocationAPI/SetLocation", "housing")
        if not ok then return false, err end
        ok, err = fire("HousingAPI/SubscribeToHouse", Player)
        if not ok then return false, err end
        task.wait(1.5)
        return true
    end

    function Lures:LeaveHouse()
        pcall(function() invoke("HousingAPI/UnsubscribeFromHouse", Player) end)
        pcall(function() fire("LocationAPI/SetLocation", "MainMap", nil, "MainMap") end)
    end

    function Lures:Cycle()
        if not self.Enabled or self.Busy then return false end
        self.LastCycle = os.clock()
        self:RefreshBaits()
        local rows = self:RefreshLures()

        local target
        for _, row in ipairs(rows) do
            if row.status == "READY" then target = row break end
        end
        if not target then
            for _, row in ipairs(rows) do
                if row.status == "EMPTY" then target = row break end
            end
        end
        if not target then
            self.LastMessage = "All lures running"
            return true
        end

        if not ASTRAL.Scheduler:Request("lures", 20) then
            self.LastMessage = "Waiting for " .. tostring(ASTRAL.Scheduler:Status())
            return false
        end

        self.Busy = true
        local ok, err = pcall(function()
            local entered, enterReason = self:EnterHouse()
            if not entered then error(enterReason) end

            local unique = findFurniture(target.furniKind)
            if not unique then
                self.LastMessage = target.mapName .. " furniture not found in active house"
                log(self.LastMessage)
                return
            end

            if target.status == "READY" then
                self.LastAction = "Collecting " .. target.mapName
                self.LastMessage = self.LastAction
                log(self.LastAction .. " via " .. unique)
                local collected, reason = invoke(
                    "HousingAPI/ActivateFurniture",
                    Player, unique, "UseBlock", false, Player.Character
                )
                if not collected then error(reason) end
                self.SessionCollected += 1
                task.wait(1.5)
                self:RefreshLures()
                return
            end

            local baitKind, baitUnique, count = self:ChooseBait()
            if not baitUnique then
                error(self.SelectedBait
                    and ("Selected bait unavailable: " .. tostring(self.SelectedBait))
                    or "No compatible lure bait found")
            end

            self.LastAction = "Charging " .. target.mapName
            self.LastMessage = self.LastAction .. " with " .. baitKind
            log(self.LastMessage .. " (" .. tostring(count) .. " owned)")
            local charged, reason = invoke(
                "HousingAPI/ActivateFurniture",
                Player, unique, "UseBlock", {bait_unique = baitUnique}, Player.Character
            )
            if not charged then error(reason) end
            self.SessionCharged += 1
            task.wait(1.5)
            self:RefreshLures()
        end)

        self:LeaveHouse()
        ASTRAL.Scheduler:Release("lures")
        self.Busy = false

        if not ok then
            self.LastMessage = "Cycle failed: " .. tostring(err)
            log(self.LastMessage)
            return false, err
        end

        if self.LastAction ~= "None" then
            self.LastMessage = self.LastAction .. " complete"
        end
        return true
    end

    task.spawn(function()
        while not ASTRAL.Runtime.Destroyed do
            if Lures.Enabled and not Lures.Busy
                and os.clock() - Lures.LastCycle >= Lures.Interval then
                Lures:Cycle()
            elseif not Lures.Enabled and os.clock() - Lures.LastCycle >= 10 then
                Lures.LastCycle = os.clock()
                pcall(function()
                    Lures:RefreshBaits()
                    Lures:RefreshLures()
                end)
            end
            task.wait(1)
        end
    end)

    ASTRAL.Modules:Register(Lures)
    return Lures
end
