# Phase 1 - Map

Back to [[FPS Bedwars]]. Design: [[Map Design Spec]]. Repo: `docs/superpowers/plans/2026-10-25-map-build.md`.

**Status:** built and tested in Studio on 2026-10-25.

![[studio_aerial.jpg]]

## What was built
- **5 floating team islands** (Red 90°, Blue 18°, Green −54°, Yellow −126°, Purple 162°) on a ring of radius **260**, tops at Y 200, each facing the centre.
  - Identical 120 × 96 flat build zone (10 × 8 cells of 12 studs) on every island.
  - Each island has its own cliff outline and underside.
- **Centre island** (~185 across, top Y 206):
  - cyan high-tier dispenser under a steel gantry
  - neutral shop
  - low rock arch on the 54° half-angle
  - 5 low cover rocks, one on each team's approach
- **5 resource platforms** (36 × 36 deck, amber dispensers), one between each pair of neighbouring bases at radius ~210.
- On every team island:
  - 24 × 24 rusted-metal starter shed with a 6 × 9 doorway facing the yard
  - bed against the back wall with a team-colour blanket
  - shop stall with a "SHOP" sign in the team colour
  - banner mast with a team flag
  - spawn pad
  - 4 cover rocks
- Ocean (Terrain water, 8192 × 8192), neutral daylight, light haze, distant ridge silhouettes, and a kill-height marker at Y 60.

## How it's made
1. **Blender generators** (`blender/fpsb_islands.py`, `blender/fpsb_structures.py`): islands, rocks, platforms, sheds, shops and dispensers are all generated from code.
2. **FBX export** at `global_scale=0.01` (Studio's importer reads Blender FBX at 100×), then **Import 3D**.
3. **`ServerStorage.MapTools.PrepareAssets`**: turns imports into templates in `ServerStorage.MapAssets`. It restores Blender pivots, sets materials by name suffix and sets collision. `restyle()` re-applies looks.
4. **`MapTools.MapBuilder.build()`**: rebuilds `Workspace.Map` from the templates in under 0.1 s.
5. **`MapTools.MapChecks.run(MapBuilder)`**: layout tests.

Re-run from the command bar:
```lua
local function fresh(n) local m = game.ServerStorage.MapTools[n]:Clone(); m.Parent = game.ServerStorage.MapTools; local r = require(m); m:Destroy(); return r end
fresh("MapBuilder").build()
print(fresh("MapChecks").run(fresh("MapBuilder")).pass)
```

## Gameplay hooks (CollectionService)
| Tag | On | Attributes |
|---|---|---|
| `Bed` | each team Bed model | `Team` |
| `Shop` | 6 shop stalls | `Team` (or `Neutral`) |
| `ResourceDispenser` | 5 platform + 1 centre | `Tier` = `Basic` / `High` |
| `SpawnPad` | 5 SpawnLocations (neutral for now) | `Team` |
| `BuildFloor` | invisible level slab per island + centre | `GridSize` = 12 |
| `KillHeight` | invisible plane at Y 60 | — |

## Test results (2026-10-25)
- **MapChecks: pass.** Checks covered:
  - counts
  - ring radius and 72° symmetry (0.05 tolerance)
  - identical local offsets for shed, bed, shop, banner, spawn and floor on all 5 islands
  - build zones level with no holes, and no air gaps at their edges
  - bed reachable through the doorway on every island
  - nothing floating
  - every dispenser has room around it
  - heights
- A negative test (arch lifted 5 studs) fails as expected.
- **Playtest walk:**
  - spawn → into the shed to the bed → out → shop counter → around and behind the shed → banner → both front rocks → front edge: all clear
  - centre: lap around the dispenser, through the arch both ways, shop front, edge toward Red: all clear
  - all 5 platforms: lap around the dispenser: all clear
  - no stuck spots and no invisible walls; height stayed level everywhere

## Open items
- Studio's Rojo session didn't reload the project file, so the map tools were copied in through a temporary `src/server/MapToolsSync` folder. **Restart `rojo serve` and delete `src/server/MapToolsSync`.** The real source is `scripts/`, now mapped to `ServerStorage.MapTools`.
- SpawnPads are neutral SpawnLocations so playtests work. Switch them to team spawns when the team system lands.
- The output log shows `rbxassetid://203785492 ... Asset type does not match` lines. They were there before this work and nothing in the place references that id, so they're probably from a plugin.
- No gameplay logic (beds, shops, dispensers, kill height) by design. The map only provides tagged hooks.

![[studio_red_base.jpg]]
![[studio_center.jpg]]
