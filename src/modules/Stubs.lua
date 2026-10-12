return function(ASTRAL)
    local definitions = {
        {"baby_farm",      "Baby Autofarm",   "Autofarm",     "Optional baby-needs automation."},
        {"friendship",     "Friendship",      "Pets",         "Full-grown friendship and Age-Up Potion progression."},
        {"potions",        "Potion Feeder",   "Pets",         "Controlled Age-Up Potion usage."},
        {"eggs",           "Egg Manager",     "Eggs",         "Purchase, equip, hatch and target management."},
        {"pet_pens",       "Pet Pens",        "Pet Pens",     "Assignment, XP/Bucks claiming and replacement queues."},
        {"neon_factory",   "Neon Factory",    "Neon Factory", "Normal -> Neon -> Mega production planning."},
        {"halloween_2026", "Halloween 2026",  "Events",       "Ghost Clusters, Crypt, Hauntlet and event goals."},
        {"inventory",      "Inventory",       "Inventory",    "Inventory metadata and collection tracking."},
        {"purchases",      "Purchases",       "Inventory",    "Shared budget-aware purchase engine."},
        {"lures",          "Lures",           "Inventory",    "Lure placement and reward collection."},
    }

    for _, definition in ipairs(definitions) do
        ASTRAL.Modules:Register({
            Id = definition[1],
            Name = definition[2],
            Page = definition[3],
            Description = definition[4],
            Version = "0.0.0",
            Implemented = false,
            Enabled = false,

            GetStatus = function(self)
                return {
                    enabled = self.Enabled,
                    implemented = self.Implemented,
                    message = "Coming soon",
                }
            end,
        })
    end

    return true
end
