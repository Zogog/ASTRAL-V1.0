return function(ASTRAL)
    local Runtime = {
        Connections = {},
        Destroyed = false,
    }

    function Runtime:Connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(self.Connections, connection)
        return connection
    end

    function Runtime:Destroy()
        if self.Destroyed then
            return
        end

        self.Destroyed = true

        for _, connection in ipairs(self.Connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end

        table.clear(self.Connections)

        if ASTRAL.UI and ASTRAL.UI.Root then
            pcall(function()
                ASTRAL.UI.Root:Destroy()
            end)
        end
    end

    ASTRAL.Runtime = Runtime
    return Runtime
end
