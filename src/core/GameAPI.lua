return function(ASTRAL)
    -- Intentionally empty in dev.1. No Adopt Me remotes are resolved or invoked.
    local GameAPI = { Ready = false, Message = "Game API not migrated yet" }
    ASTRAL.Game = GameAPI
    return GameAPI
end
