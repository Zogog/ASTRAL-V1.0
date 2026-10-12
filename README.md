# ASTRAL 1.0 — Modular Rebuild

This repository is the clean ASTRAL V1.0 rebuild. The previous v0.8.3b version remains untouched.

## How it works

`dist/ASTRAL.lua` is a small bootstrap. Delta/executor loads that one file, and the bootstrap then downloads the individual ASTRAL modules from this repository.

There is **no Python build step**.

## Executor loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Zogog/ASTRAL-V1.0/main/dist/ASTRAL.lua"))()
```

## Repository layout

```text
ASTRAL-V1.0/
├── dist/
│   ├── ASTRAL.lua
│   └── ASTRAL.txt
└── src/
    ├── core/
    │   ├── State.lua
    │   ├── Config.lua
    │   ├── Runtime.lua
    │   ├── Scheduler.lua
    │   ├── GameAPI.lua
    │   └── ModuleManager.lua
    ├── modules/
    │   └── Stubs.lua
    └── ui/
        └── Window.lua
```

## Development rule

Edit the individual module that owns the behaviour.

Examples:

- Pet Pen work belongs in `src/modules/PetPens.lua`
- Ghost Clusters belongs in `src/events/Halloween2026/GhostClusters.lua`
- Shared Adopt Me interaction wrappers belong in `src/core/GameAPI.lua`
- GUI shell/components belong under `src/ui/`

Modules should communicate through the shared `ASTRAL` context rather than reaching into each other's private implementation.

## Loader behaviour

The bootstrap has an ordered manifest and:
- fetches each module independently;
- retries failed HTTP requests up to three times;
- aborts if a required core/UI module fails;
- records optional-module failures in `ASTRAL.Boot.Failed`;
- exposes loaded modules in `ASTRAL.Boot.Loaded`.

## dev.2 scope

`1.0.0-dev.2` proves the remote modular architecture only. Gameplay automation is still intentionally absent.

The dev.1 window dimensions are retained. The Dashboard runtime card is now updated explicitly rather than remaining on `Initialising...`, and navigation avoids unsupported Unicode icon glyphs.

## Migration policy

Migrate one known-good feature at a time from the frozen v0.8.3b implementation. Test each migration independently on PC and S9/Delta before moving to the next subsystem.
