# ASTRAL 1.0 — Modular Rebuild

## 1.0.0-dev.4 — Hungry / Thirsty feeding fallback (experimental)

Preserves the dev.3.1 Play handler and adds two independently registered
pet ailments, `hungry` and `thirsty`.

Feeding priority:
1. If inside a loaded house and the active house slot can be resolved,
   discover a matching pet food/water bowl and attempt its UseBlock action.
2. Otherwise, use a compatible owned food/drink item.
3. If there is no compatible owned item, purchase **one** fallback item:
   - Hungry: `schospital_refresh_2023_cafeteria_sandwich`
   - Thirsty: `water`
4. Wait for the actual pet ailment to disappear before reporting success.

The module includes cancellation/pet-switch checks, purchase cooldowns,
and a safeguard against buying more items when an already-owned item fails.

### Important limits

This is an **experimental integration**, not live-tested. House slot detection
and the furniture UseBlock argument shape depend on current Adopt Me client
state; if the slot cannot be resolved, the bowl route is safely skipped.
The owned/purchased food object route relies on the normal client pet entity
to perform the consumption after CreatePetObject. If that interaction has
changed, the module will time out rather than claiming success.

### Files in this patch

- `src/core/FeedingAPI.lua` — new, extends existing `ASTRAL.Game`.
- `src/modules/autofarm/ailments/Feeding.lua` — new, registers both handlers.
- `dist/ASTRAL.lua` — replace existing loader with updated manifest/version.
- `README.md` — replace existing README with this documentation.

**Do not replace** `src/core/GameAPI.lua`, `Play.lua`, `Autofarm.lua`, or
`AilmentRegistry.lua` for this patch.

### Upload / test

1. Back up the current repository or create a branch.
2. Upload the **two new modules first** at the paths above.
3. Replace `README.md` and finally `dist/ASTRAL.lua`.
4. Rejoin and inject using the same loader URL as dev.3.1.
5. Confirm logs include `Loaded feeding_api`, `Loaded feeding`,
   `Ailment registered: hungry`, and `Ailment registered: thirsty`.
6. Test one ailment at a time with a bowl, an owned item, and no owned item.
   Watch for any Bucks spent and verify that the ailment really clears.
7. If a bowl is skipped, collect the `[ASTRAL FEEDING]` output and the
   current house-slot data; do not guess a furniture ID.

### Rollback

Restore the previous `dist/ASTRAL.lua` from GitHub history. The two new
modules will then remain unused and dev.3.1 behaviour will be restored.

## Executor loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Zogog/ASTRAL-V1.0/main/dist/ASTRAL.lua"))()
```
