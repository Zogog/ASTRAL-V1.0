return function(ASTRAL)
    local defs = {
        {"pet_farm", "Pet Autofarm", "Autofarm", "Pet ailment detection and completion."},
        {"baby_farm", "Baby Autofarm", "Autofarm", "Optional baby-needs automation."},
        {"pet_queue", "Pet Queue", "Pets", "Shared progression and pet-selection queue."},
        {"friendship", "Friendship", "Pets", "Full-grown friendship and Age-Up Potion progression."},
        {"potions", "Potion Feeder", "Pets", "Controlled Age-Up Potion usage."},
        {"eggs", "Egg Manager", "Eggs", "Purchase, equip, hatch and target management."},
        {"pet_pens", "Pet Pens", "Pet Pens", "Assignment, XP/Bucks claiming and replacement queues."},
        {"neon_factory", "Neon Factory", "Neon Factory", "Normal → Neon → Mega production planning."},
        {"halloween_2026", "Halloween 2026", "Events", "Ghost Clusters, Crypt, Hauntlet and event goals."},
        {"inventory", "Inventory", "Inventory", "Inventory metadata and collection tracking."},
        {"purchases", "Purchases", "Inventory", "Shared budget-aware purchase engine."},
        {"lures", "Lures", "Inventory", "Lure placement and reward collection."},
    }
    for _, d in ipairs(defs) do
        ASTRAL.Modules:Register({
            Id=d[1], Name=d[2], Page=d[3], Description=d[4], Version="0.0.0", Implemented=false,
            Enabled=false,
            GetStatus=function(self) return {enabled=self.Enabled, implemented=self.Implemented, message="Coming soon"} end,
        })
    end
end
