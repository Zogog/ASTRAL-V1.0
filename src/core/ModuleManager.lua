return function(ASTRAL)
    local Manager = {
        Items = {},
        Order = {},
    }

    function Manager:Register(module)
        assert(type(module) == "table" and module.Id, "Invalid ASTRAL module")

        -- A stale/legacy stub must never overwrite a real implemented module.
        local existing = self.Items[module.Id]
        if existing and existing.Implemented and not module.Implemented then
            warn("[ASTRAL MODULES] Ignored stub for implemented module:", module.Id)
            return false, "Implemented module already registered"
        end

        if not self.Items[module.Id] then
            table.insert(self.Order, module.Id)
        end

        self.Items[module.Id] = module

        if module.Init then
            local ok, err = pcall(module.Init, module, ASTRAL)
            if not ok and ASTRAL.State then
                ASTRAL.State:Log("Module init failed: " .. module.Id .. " — " .. tostring(err))
            end
        end
    end

    function Manager:Get(id)
        return self.Items[id]
    end

    function Manager:SetEnabled(id, enabled)
        local module = self.Items[id]

        if not module then
            return false, "Unknown module"
        end

        if not module.Implemented then
            return false, "Not implemented in " .. ASTRAL.Version
        end

        if module.SetEnabled then
            local ok, reason = module:SetEnabled(enabled)
            if ok and ASTRAL.Config and ASTRAL.Config.PersistenceEnabled then
                pcall(function() ASTRAL.Config:Save() end)
            end
            return ok, reason
        end

        return false, "Module has no enable handler"
    end

    function Manager:Counts()
        local total = #self.Order
        local implemented = 0

        for _, id in ipairs(self.Order) do
            local module = self.Items[id]
            if module and module.Implemented then
                implemented += 1
            end
        end

        return implemented, total
    end

    ASTRAL.Modules = Manager
    return Manager
end
