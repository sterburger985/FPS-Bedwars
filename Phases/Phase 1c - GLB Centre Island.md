# Phase 1c - GLB Centre Island

Back to [[FPS Bedwars]]. Previous: [[Phase 1b - GLB Team Islands]]. Decisions: [[FPS Bedwars Decisions]].

**Status:** v2 built, tested and saved to Roblox on 2026-10-28. It replaced v1 from 2026-10-27.

## Current: v2 (2026-10-28)
- **Source:** Sterling's new `imports/bedwars-central-island-v2.glb`, processed by `blender/fpsb_glb_centre.py`.
- **Scale ×1.5:** the v2 island is about 40% bigger than v1, so ×1.5 keeps the centre close to its old footprint.
  - It's about 195 × 153 studs, with the sand top at Y 206.
  - Edge-to-edge gaps, measured by raycast:
    - centre → team islands: 138–156
    - centre → resource platforms: 118–136
- **Huts:** the three huts already come with open doorways and windows, so the script doesn't cut anything (`HOLLOW_HUTS = False`).
  - Each hut piece is still exported as its own mesh, so the collision stays exact.
  - A radial ray scan from inside each hut escapes through the doorway at foot and chest height. Headroom is 13–14 studs.
- **Floating objects:** the settle pass found nothing floating. No side island or bridge exists in v2.
- **Gem dropper:** still the high-tier dispenser (`ResourceDispenser`, `Tier = High`, purple light).
- **No neutral shop** at the centre (Sterling, 2026-10-28). There are now 5 shops, one per team island.
  - `MapBuilder.LAYOUT_GLB_CENTRE.shop = nil` switches it off.
  - `MapBuilder.expectedShops()` gives MapChecks the right count.
  - To bring a centre shop back, set `shop` to a CFrame.

## How it's made
1. In Blender, import the GLB into the collection `FPSB_GLBCentreV2`. Then run:
   `exec(open(r"C:\Roblox Dev\FPS Bedwars\blender\fpsb_glb_centre.py").read()); build(); export(fbx, json)`
   - Settings at the top of the script: `SRC`, `SCALE`, `HOLLOW_HUTS`, `MAX_TRIS`.
   - v1 settings were `FPSB_GLBCentre`, 2.0, True.
2. Outputs:
   - `exports/FPSB_GLBCentreV2.fbx` and `exports/glbc2_origins.json`
   - Templates `GLBCentre` (island, huts, props, plaza) and `GLBDropper` (the gem dropper)
   - Parts: `GC_<Template>_<material>`; hut pieces `GC_Hut<Name><nn>_<material>`
   - Any mesh over `MAX_TRIS` (18,000; the Roblox limit is 20,000) is split into X strips (`GC_CentreA_rock` …). v2 didn't need it: the largest mesh is 15.6k tris.
3. Import 3D the FBX (Anchored). Then run `PrepareAssets.run({workspace.FPSB_GLBCentreV2})`, then `MapBuilder.build()`, then `MapChecks.run`.
   - Materials use the `GLBC:` keys: flat GLB colours (unchanged between v1 and v2).
   - Lamp glow and the banner don't collide.

## Test results (2026-10-28)
- **MapChecks: pass.** Counts:
  - Bed 5
  - Shop 5
  - ResourceDispenser 6, with exactly 1 High
  - SpawnPad 5
  - BuildFloor 6
  - KillHeight 1
- **Playtest walk:** every leg reached its target.
  - East, west and plateau huts: outside → doorway → middle → back wall → out.
  - 8-point lap around the dropper.
- Saved to Roblox.

![[studio_glb_centre_v2.jpg]]

## History: v1 (2026-10-27)
- **Source:** `imports/bedwars-central-island.glb` at ×2 (about 187 × 140 studs), with a neutral shop on the north lawn.
- **Changes made in Blender:**
  - Side island and bridge removed.
  - One floating tree lowered.
  - The solid huts were rebuilt as 4 walls with a doorway where the door panel was.
- **Collision lesson:** with each hut material joined into one mesh, PreciseConvexDecomposition wrapped slanted hulls across the plateau hut's doorway. Exporting one mesh per hut box fixed it, and v2 keeps that rule.

![[studio_glb_centre.jpg]]
