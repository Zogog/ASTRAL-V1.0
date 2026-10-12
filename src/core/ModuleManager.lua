return function(ASTRAL)
    local Manager = { Items = {}, Order = {} }
    function Manager:Register(module)
        assert(type(module) == "table" and module.Id, "Invalid ASTRAL module")
        self.Items[module.Id] = module
        table.insert(self.Order, module.Id)
        if module.Init then pcall(module.Init, module, ASTRAL) end
    end
    function Manager:Get(id) return self.Items[id] end
    function Manager:SetEnabled(id, enabled)
        local m = self.Items[id]
        if not m then return false, "Unknown module" end
        if not m.Implemented then return false, "Not implemented in " .. ASTRAL.Version end
        if m.SetEnabled then return m:SetEnabled(enabled) end
        return false, "Module has no enable handler"
    end
    function Manager:Counts()
        local total, implemented = #self.Order, 0
        for _, id in ipairs(self.Order) do if self.Items[id].Implemented then implemented += 1 end end
        return implemented, total
    end
    ASTRAL.Modules = Manager
    return Manager
end
