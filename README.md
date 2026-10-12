# ASTRAL 1.0 — Modular Rebuild

## 1.0.0-dev.3 — First Automation

This release keeps the proven dev.2 remote-module architecture and migrates exactly one known-good gameplay feature: the **Play** pet ailment.

The Play implementation is based on ASTRAL v0.8.3b PlayFix and the controlled Cobalt capture:
1. ToolAPI/ServerUseTool(toyUnique, "START")
2. PetObjectAPI/CreatePetObject("__Enum_PetObjectCreatorType_1", ThrowToyReaction)
3. ToolAPI/Unequip(toyUnique, {from_throw_toy=true})
4. ToolAPI/ServerUseTool(toyUnique, "END", nil)
5. Wait for real Play progress before throwing again.

All other gameplay systems remain stubs.

## Executor loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Zogog/ASTRAL-V1.0/main/dist/ASTRAL.lua"))()
```

## New files

```text
src/modules/autofarm/
├── AilmentRegistry.lua
├── Autofarm.lua
└── ailments/
    └── Play.lua
```

`src/core/GameAPI.lua` now owns the Adopt Me data/remotes needed by Play. Feature modules should use `ASTRAL.Game` rather than resolving those dependencies themselves.

## Test

1. Commit every dev.3 file to GitHub.
2. Rejoin/reinject ASTRAL.
3. Confirm the loader prints `Loaded ailments`, `Loaded autofarm`, and `Loaded play`.
4. Open Autofarm and switch **Pet Autofarm** ON.
5. Wait for a pet Play need.
6. Confirm Play completes and the output reports progress advancing.

Do not migrate another ailment until this vertical slice is proven on PC.
