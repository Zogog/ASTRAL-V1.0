return function(ASTRAL)
    -- Intentionally empty in dev.2.
    -- Adopt Me remotes will be migrated into this boundary one known-good
    -- subsystem at a time rather than being called directly from UI modules.
    local GameAPI = {
        Ready = false,
        Message = "Game API not migrated yet",
    }

    ASTRAL.Game = GameAPI
    return GameAPI
end
