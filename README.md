# ASTRAL 1.0.0-dev.1 — Foundation

Clean rebuild of ASTRAL. The previous v0.8.3b branch is intentionally untouched.

This release is a **UI + architecture foundation only**. Gameplay modules are stubs and do not automate Adopt Me yet.

## What works
- Responsive ASTRAL window with desktop/mobile layouts
- Sidebar navigation and page routing
- Dashboard, Autofarm, Pets, Eggs, Pet Pens, Neon Factory, Events, Inventory, Diagnostics and Settings pages
- Central runtime/state/config/module registry
- Module status cards and diagnostics activity log
- Minimise, close and draggable window
- Safe stub module interface for future migration
- Single-file `dist/ASTRAL.lua` for executor use

## What deliberately does not work yet
No pet automation, remotes, purchases, event farming, trading, teleporting or inventory modification is performed in dev.1.

## Development layout
- `src/core` — runtime/state/config/module infrastructure
- `src/modules` — empty feature modules
- `src/ui` — reusable UI and pages
- `tools/build.py` — bundles source modules into one release file
- `dist/ASTRAL.lua` — upload/executor-ready bundle

## Build
Run:

```bash
python tools/build.py
```

## Loader after uploading `dist/ASTRAL.lua` to GitHub
Replace OWNER/REPO/BRANCH as appropriate:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/OWNER/REPO/BRANCH/dist/ASTRAL.lua"))()
```

## Migration rule
Migrate one known-good feature at a time from the frozen v0.8.3b implementation. Each migrated module should be independently auditable and should not place gameplay logic in UI files.
