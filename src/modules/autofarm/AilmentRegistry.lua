return function(ASTRAL)
    local Registry = {
        Version = "0.1.0",
        Items = {},
        Order = {},
    }

    function Registry:Register(handler)
        assert(type(handler) == "table", "Ailment handler must be a table")
        assert(type(handler.Id) == "string", "Ailment handler requires Id")
        assert(type(handler.Run) == "function", "Ailment handler requires Run")

        if not self.Items[handler.Id] then
            table.insert(self.Order, handler.Id)
        end

        self.Items[handler.Id] = handler

        table.sort(self.Order, function(a, b)
            local left = self.Items[a]
            local right = self.Items[b]
            return (left.Priority or 0) > (right.Priority or 0)
        end)

        if ASTRAL.State then
            ASTRAL.State:Log("Ailment registered: " .. handler.Id)
        end
    end

    function Registry:Get(id)
        return self.Items[id]
    end

    function Registry:SelectActive()
        for _, id in ipairs(self.Order) do
            local handler = self.Items[id]
            local active = ASTRAL.Game:PetHasAilment(id)

            if active then
                local canRun = true

                if handler.CanRun then
                    local ok, result = pcall(handler.CanRun, handler, ASTRAL)
                    canRun = ok and result ~= false
                end

                if canRun then
                    return handler
                end
            end
        end

        return nil
    end

    ASTRAL.Ailments = Registry
    return Registry
end
