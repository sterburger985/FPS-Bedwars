# Phase 1d - GLB Dispenser Islands

Back to [[FPS Bedwars]]. Previous: [[Phase 1c - GLB Centre Island]]. Decisions: [[FPS Bedwars Decisions]].

**Status:** built, tested and saved to Roblox on 2026-10-28.

## What changed
- The 5 resource platforms between the team islands are now Sterling's dispenser island (`imports/bedwars-dispenser-island.obj` + `.mtl`), processed by `blender/fpsb_glb_dispenser.py`.
  - Scale ×1: 53 × 53 studs, with a 45 × 45 stone deck (the old deck was 36 × 36). The deck top is at Y 200, as before.
  - The model has a gold-trimmed deck, corner pillars with lamps, low railings, crates and ore stacks for cover, and the dispenser machine in the middle.
  - The 4 loose "already dispensed" stone blocks and iron ingots on the trays were removed so they don't get mistaken for real drops.
- The machine is its own template (`GLBDispenser`), tagged `ResourceDispenser` with `Tier = Basic` and an amber light. The corner lamps get small warm lights.
- `MapBuilder.PLATFORM_STYLE = "GLB"` picks the new islands. `"Rust"` brings back the old concrete platforms; their templates are still in `MapAssets`.
- Edge-to-edge gaps, measured by raycast:
  - platform → each neighbouring base: 57 (was 63)
  - platform → centre: 111–129

## How it's made
1. In Blender, run `fpsb_glb_dispenser.py`: `build()` imports the OBJ itself, then `export(fbx, json)`.
2. Outputs:
   - `exports/FPSB_GLBDispenser.fbx` and `exports/glbd_origins.json`
   - Templates `GLBPlatform` and `GLBDispenser`, pivot at the deck-top centre
   - Parts named `GP_<Template>_<material>`
3. Import 3D the FBX (Anchored). Then run `PrepareAssets.run({workspace.FPSB_GLBDispenser})`, then `MapBuilder.build()`, then `MapChecks.run`.
   - Materials use the `GLBP:` keys: flat colours from the `.mtl` `Kd` values, converted from linear to sRGB.
   - `gold_glow` is Neon and doesn't collide. Everything else uses PreciseConvexDecomposition.

## Test results (2026-10-28)
- **MapChecks: pass.** This covers dispenser clearance (8 directions), grounding and deck height on all 5 platforms.
- **Playtest:** on every platform, an 8-point lap around the machine reached every point, and the walk to the deck edge was clear.
- Saved to Roblox.

![[studio_glb_dispenser.jpg]]
