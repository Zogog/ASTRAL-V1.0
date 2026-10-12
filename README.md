# ASTRAL 1.0 — Modular Rebuild

## 1.0.0-dev.5-modular — 18 core pet ailments

This repository is rebuilt from the recovered `df95ea3` snapshot. The goal of this revision is structural: **every active core pet ailment now has its own module file** while shared mechanics live in `src/core`.

### Core ailments

`Mystery`, `Sick`, `Sleepy`, `Dirty`, `Toilet`, `School`, `Salon`, `Pizza Party`, `Cat Cafe`, `Camping`, `Beach Party`, `Walk`, `Ride`, `Bored`, `Hungry`, `Thirsty`, `Pet Me`, and `Play`.

### Protected known-good behaviour

- `Play.lua` is preserved from the recovered snapshot.
- Hungry/Thirsty use the dev.4.1 feeding pipeline, moved into `FeedingSupport.lua` so the two handlers can be independent files.
- `State.lua` retains the worker-thread-safe UI refresh `pcall` hotfix.
- `FeedingAPI.lua` is unchanged.

### Experimental handlers

The 15 handlers added in dev.5 are still experimental until tested in-game. They verify real ailment state before reporting completion and use cooldown/backoff after failure. No successful result should be treated as verified until runtime logs confirm it.

House furniture ailments may require a verified house slot. After injection, it can be set for the current session with:

```lua
getgenv().ASTRAL.Config.HouseSlot = 5
```

Only use a slot number you have verified for your own house. ASTRAL does not hard-code slot 5.

### Repository structure

- `dist/ASTRAL.lua` / `dist/ASTRAL.txt` — remote loader.
- `src/core/` — state, scheduler, game API and shared ailment mechanics.
- `src/modules/autofarm/ailments/` — exactly one active module per core ailment.
- `src/ui/Window.lua` — current ASTRAL UI.

### Restore to GitHub

Because the repository was intentionally cleared, upload the **contents of this ZIP** to the repository root, preserving the `dist/` and `src/` directories. Commit all source files before testing the loader.

### Executor loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Zogog/ASTRAL-V1.0/main/dist/ASTRAL.lua"))()
```

### First test

On boot, confirm all required modules load and all 18 ailment registrations appear without a compile/initialisation failure. Then enable Pet Autofarm and send the full console output for any ailment that runs. Test results should be used to fix handlers individually without touching already-working modules.
