return function(ASTRAL)
    local Config = {
        UIScale = 1,
        CompactMobile = true,
        ShowStubModules = true,
    }
    function Config:Get(key, fallback)
        local value = self[key]
        if value == nil then return fallback end
        return value
    end
    function Config:Set(key, value)
        self[key] = value
        if ASTRAL.State then ASTRAL.State:Log("Setting changed: " .. tostring(key)) end
    end
    ASTRAL.Config = Config
    return Config
end
