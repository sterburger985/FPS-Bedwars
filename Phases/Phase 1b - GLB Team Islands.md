# Phase 1b - GLB Team Islands

Back to [[FPS Bedwars]]. Follows [[Phase 1 - Map]].

**Status:** built and tested in Studio on 2026-10-27, and saved to Roblox.

![[studio_glb_aerial.jpg]]

## What changed
All 5 team islands now use Sterling's blocky low-poly island (`imports/team-island-blocky.glb`). The centre island, resource platforms, ocean and lighting are unchanged.

Sterling's choices:
- **Keep the GLB's own buildings**: hut, shop, water tower, banner and fence, pines, bushes, crates and floating rocks.
- **Add our bed inside the hut** and **remove the hut door**, so the bed is reachable and attackable.
- **Scale ×1.75**: the sand top is 126.7 × 98.7, so the 120 × 96 build area (10 × 8 cells of 12) fits on it.
- **Keep the GLB's flat colours**: SmoothPlastic using the glTF base colours converted to sRGB. Glow parts are Neon.
- **Remove the ramp.**

My choice: the island is **rotated 180°** so the banner and fence face the centre and the hut sits on the back half.

## How it's made
1. `blender/fpsb_glb_island.py`:
   - takes the imported GLB
   - drops the ramp, door and handle
   - rotates, scales and sets the top to Y = 0
   - joins the 418 box meshes into 29 meshes, one per template and material (`GI_<Template>_<material>`)
   - produces 4 templates, all with their origin at the island top centre: `GLBIsland`, `GLBHut`, `GLBShop`, `GLBBanner`
2. FBX export: `exports/FPSB_GLBIsland.fbx` (scale 0.01). Pivots come from `exports/glb_origins.json`.
3. `PrepareAssets`:
   - `GI_` parts get a `GLB:<material>` look
   - collision is PreciseConvexDecomposition, because each mesh is many boxes and one hull would wrap them all
   - glow, banner cloth and the white emblem don't collide
4. `MapBuilder.TEAM_STYLE = "GLB"` (set it to `"Rust"` to go back to the old islands; both template sets are kept in `ServerStorage.MapAssets`). `LAYOUT_GLB` sets:
   - bed in the hut at local (−39.9, 0.53, 10.9), turned so the headboard is against the wall opposite the door
   - doorway facing the island's back edge (+Z)
   - shop "SHOP" sign as a thin part with a SurfaceGui in front of the GLB's sign board
   - spawn pad at (0, 0, 2)
   - build floor centred on the island
5. The team colour is applied to the banner cloth, the shop's red trim and the bed blanket.

## Test results (2026-10-27)
- **MapChecks: pass.** Covers counts, symmetry, flat build areas with no holes or edge gaps, the bed reachable through every hut doorway, nothing floating, dispenser clearance and heights.
- **Playtest walk on the Red island: 17/17 legs.**
  - spawn → hut doorway → inside to the bed → out → around the hut → yard → shop customer side
  - all four edges and corners → back to spawn
  - no stuck spots and no invisible walls

## Notes
- The hut is about 13.5 × 15.8 studs, smaller than the original 24 × 24 (2 × 2 grid) spec. This was accepted with the ×1.75 scale. The bed fits with about 3 studs between its foot and the doorway.
- **Spacing (updated 2026-10-27):** ring radius raised from 260 to 285. Measured gaps edge to edge: base → centre 136, base → platform 63, platform → centre 105.
- Rojo wasn't running this session, so the Studio modules were patched in place with `multi_edit` and checked byte for byte against `scripts/`.

![[studio_glb_hut.jpg]]
![[studio_glb_shop.jpg]]
