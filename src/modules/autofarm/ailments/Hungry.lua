return function(ASTRAL)
    local Feeding = assert(ASTRAL.FeedingSupport)
    local handler = { Id = "hungry", Name = "Hungry", Version = Feeding.Version, Priority = 60 }
    function handler:CanRun() return ASTRAL.Game:GetCurrentPetUnique() ~= nil end
    function handler:Run(_, context) return Feeding:Run("hungry", context) end
    ASTRAL.Ailments:Register(handler)
    return handler
end
