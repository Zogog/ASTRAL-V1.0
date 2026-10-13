return function(ASTRAL)
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer

    local Config = {
        UIScale = 1,
        CompactMobile = true,
        ShowStubModules = true,

        PersistenceEnabled = true,
        PersistenceAvailable = type(readfile) == "function"
            and type(writefile) == "function",
        PersistenceLoaded = false,
        LastPersistenceMessage = "Not loaded yet",
        SaveInterval = 5,
        LastSave = 0,
        _restoring = false,
        _autosaveStarted = false,
    }

    local rootFolder = "ASTRAL"
    Config.PersistencePath = type(makefolder) == "function"
        and (rootFolder .. "/settings_" .. tostring(player.UserId) .. ".json")
        or ("ASTRAL_settings_" .. tostring(player.UserId) .. ".json")

    local function copy(value, depth)
        depth = depth or 0
        if depth > 8 then return nil end
        local kind = typeof(value)
        if kind == "nil" or kind == "boolean" or kind == "number" or kind == "string" then
            return value
        end
        if kind ~= "table" then return nil end
        local out = {}
        for k, v in pairs(value) do
            local keyType = typeof(k)
            if keyType == "string" or keyType == "number" then
                local clean = copy(v, depth + 1)
                if clean ~= nil then out[k] = clean end
            end
        end
        return out
    end

    local function ensureFolder()
        if type(makefolder) ~= "function" then return end
        local exists = type(isfolder) == "function" and isfolder(rootFolder)
        if not exists then pcall(makefolder, rootFolder) end
    end

    function Config:Get(key, fallback)
        local value = self[key]
        if value == nil then return fallback end
        return value
    end

    function Config:Set(key, value)
        self[key] = value
        if ASTRAL.State then ASTRAL.State:Log("Setting changed: " .. tostring(key)) end
        self:Save()
    end

    function Config:Snapshot()
        local data = {
            schema = 1,
            persistenceEnabled = self.PersistenceEnabled == true,
            savedAt = os.time(),
            settings = {
                UIScale = self.UIScale,
                CompactMobile = self.CompactMobile,
                ShowStubModules = self.ShowStubModules,
            },
            modules = {},
            moduleData = {},
        }

        if not ASTRAL.Modules then return data end

        for _, id in ipairs(ASTRAL.Modules.Order or {}) do
            local module = ASTRAL.Modules:Get(id)
            if module and module.Implemented then
                data.modules[id] = { enabled = module.Enabled == true }
            end
        end

        local queue = ASTRAL.Modules:Get("pet_queue")
        if queue then
            data.moduleData.pet_queue = {
                mode = queue.Mode,
                manualOrder = copy(queue.ManualOrder or {}),
            }
        end

        local factory = ASTRAL.Modules:Get("neon_factory")
        if factory then
            data.moduleData.neon_factory = {
                targets = copy(factory.Targets or {}),
            }
        end

        local lures = ASTRAL.Modules:Get("lures")
        if lures then
            data.moduleData.lures = {
                selectedBait = lures.SelectedBait or "AUTO",
            }
        end

        local halloween = ASTRAL.Modules:Get("halloween_2026")
        if halloween then
            data.moduleData.halloween_2026 = {
                ghost = halloween.GhostEnabled == true,
                crypt = halloween.CryptEnabled == true,
                twigs = halloween.TwigEnabled == true,
                candy = halloween.CandyEnabled == true,
                quests = halloween.QuestEnabled == true,
                cryptMode = halloween.CryptMode,
            }
        end

        return data
    end

    function Config:Save(force)
        if self._restoring then return true end
        if not self.PersistenceAvailable then
            self.LastPersistenceMessage = "Unavailable in this executor"
            return false, self.LastPersistenceMessage
        end
        if not force and os.clock() - self.LastSave < 0.35 then return true end

        ensureFolder()
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(self:Snapshot())
        end)
        if not ok then
            self.LastPersistenceMessage = "Encode failed: " .. tostring(encoded)
            return false, self.LastPersistenceMessage
        end

        local wrote, err = pcall(writefile, self.PersistencePath, encoded)
        if not wrote then
            self.LastPersistenceMessage = "Write failed: " .. tostring(err)
            return false, self.LastPersistenceMessage
        end
        self.LastSave = os.clock()
        self.LastPersistenceMessage = self.PersistenceEnabled
            and "Saved for this Roblox account"
            or "Persistence disabled"
        return true
    end

    function Config:SetPersistenceEnabled(enabled)
        self.PersistenceEnabled = enabled == true
        local ok, err = self:Save(true)
        if ASTRAL.State then
            ASTRAL.State:Log("Session persistence " .. (self.PersistenceEnabled and "enabled" or "disabled"))
        end
        return ok, err
    end

    function Config:Restore()
        if self.PersistenceLoaded then return true end
        self.PersistenceLoaded = true

        if not self.PersistenceAvailable then
            self.LastPersistenceMessage = "Unavailable in this executor"
            return false, self.LastPersistenceMessage
        end
        if type(isfile) == "function" and not isfile(self.PersistencePath) then
            self.LastPersistenceMessage = "No saved settings yet"
            return true
        end

        local ok, raw = pcall(readfile, self.PersistencePath)
        if not ok or type(raw) ~= "string" or raw == "" then
            self.LastPersistenceMessage = "No readable saved settings"
            return false, tostring(raw)
        end

        local decodedOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if not decodedOk or type(data) ~= "table" then
            self.LastPersistenceMessage = "Saved settings are invalid"
            return false, tostring(data)
        end

        if type(data.persistenceEnabled) == "boolean" then
            self.PersistenceEnabled = data.persistenceEnabled
        end
        if not self.PersistenceEnabled then
            self.LastPersistenceMessage = "Persistence disabled"
            return true
        end

        self._restoring = true

        local settings = type(data.settings) == "table" and data.settings or {}
        if tonumber(settings.UIScale) then self.UIScale = tonumber(settings.UIScale) end
        if type(settings.CompactMobile) == "boolean" then self.CompactMobile = settings.CompactMobile end
        if type(settings.ShowStubModules) == "boolean" then self.ShowStubModules = settings.ShowStubModules end

        local moduleData = type(data.moduleData) == "table" and data.moduleData or {}

        local queue = ASTRAL.Modules and ASTRAL.Modules:Get("pet_queue")
        local queueData = moduleData.pet_queue
        if queue and type(queueData) == "table" then
            if queueData.mode == "grow_all" or queueData.mode == "manual" then queue.Mode = queueData.mode end
            if type(queueData.manualOrder) == "table" then queue.ManualOrder = copy(queueData.manualOrder) or {} end
            pcall(function() queue:Snapshot() end)
        end

        local factory = ASTRAL.Modules and ASTRAL.Modules:Get("neon_factory")
        local factoryData = moduleData.neon_factory
        if factory and type(factoryData) == "table" and type(factoryData.targets) == "table" then
            factory.Targets = copy(factoryData.targets) or {}
            local env = getgenv and getgenv() or _G
            env.ASTRALNeonTargets = factory.Targets
            pcall(function() factory:Scan() end)
        end

        local lures = ASTRAL.Modules and ASTRAL.Modules:Get("lures")
        local lureData = moduleData.lures
        if lures and type(lureData) == "table" then
            lures.SelectedBait = lureData.selectedBait == "AUTO" and nil or lureData.selectedBait
        end

        local halloween = ASTRAL.Modules and ASTRAL.Modules:Get("halloween_2026")
        local eventData = moduleData.halloween_2026
        if halloween and type(eventData) == "table" then
            if type(eventData.ghost) == "boolean" then halloween.GhostEnabled = eventData.ghost end
            if type(eventData.crypt) == "boolean" then halloween.CryptEnabled = eventData.crypt end
            if type(eventData.twigs) == "boolean" then halloween.TwigEnabled = eventData.twigs end
            if type(eventData.candy) == "boolean" then halloween.CandyEnabled = eventData.candy end
            if type(eventData.quests) == "boolean" then halloween.QuestEnabled = eventData.quests end
            if eventData.cryptMode == "Fast Spider" or eventData.cryptMode == "All"
                or eventData.cryptMode == "Twigs + Spider" then
                halloween.CryptMode = eventData.cryptMode
            end
        end

        local savedModules = type(data.modules) == "table" and data.modules or {}
        if ASTRAL.Modules then
            -- Restore in registration order so ownership rules remain deterministic.
            -- Defaults are OFF, so only saved ON states need to execute handlers.
            for _, id in ipairs(ASTRAL.Modules.Order or {}) do
                local saved = savedModules[id]
                local module = ASTRAL.Modules:Get(id)
                if module and module.Implemented and type(saved) == "table" and saved.enabled == true then
                    local enabledOk, reason = ASTRAL.Modules:SetEnabled(id, true)
                    if not enabledOk and ASTRAL.State then
                        ASTRAL.State:Log("Persistence could not enable " .. id .. ": " .. tostring(reason))
                    end
                end
            end
        end

        self._restoring = false
        self.LastPersistenceMessage = "Restored saved settings"
        if ASTRAL.State then ASTRAL.State:Log("Persistence restored saved settings") end
        return true
    end

    function Config:StartAutosave()
        if self._autosaveStarted then return end
        self._autosaveStarted = true
        task.spawn(function()
            while not (ASTRAL.Runtime and ASTRAL.Runtime.Destroyed) do
                task.wait(self.SaveInterval)
                if self.PersistenceEnabled and ASTRAL.State and ASTRAL.State.Runtime == "READY" then
                    pcall(function() self:Save(true) end)
                end
            end
        end)
    end

    ASTRAL.Config = Config
    return Config
end
