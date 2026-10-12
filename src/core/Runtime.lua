return function(ASTRAL)
    local Runtime = { Connections = {}, Destroyed = false }
    function Runtime:Connect(signal, callback)
        local c = signal:Connect(callback)
        table.insert(self.Connections, c)
        return c
    end
    function Runtime:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
        table.clear(self.Connections)
        if ASTRAL.UI and ASTRAL.UI.Root then pcall(function() ASTRAL.UI.Root:Destroy() end) end
    end
    ASTRAL.Runtime = Runtime
    return Runtime
end
