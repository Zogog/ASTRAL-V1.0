return function(ASTRAL)
    local Feeding = assert(ASTRAL.FeedingSupport)
    local handler = { Id = "thirsty", Name = "Thirsty", Version = Feeding.Version, Priority = 59 }
    function handler:CanRun() return ASTRAL.Game:GetCurrentPetUnique() ~= nil end
    function handler:Run(_, context) return Feeding:Run("thirsty", context) end
    ASTRAL.Ailments:Register(handler)
    return handler
end
