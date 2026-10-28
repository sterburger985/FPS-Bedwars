# Phase 1c - GLB Centre Island

Back to [[FPS Bedwars]]. Previous: [[Phase 1b - GLB Team Islands]]. Decisions: [[FPS Bedwars Decisions]].

**Status:** built, tested and saved to Roblox on 2026-10-27.

## What changed
- The centre island is now Sterling's `imports/bedwars-central-island.glb`, processed by `blender/fpsb_glb_centre.py`:
  - Scaled ×2.0 (about 187 × 140 studs). The sand top sits at Y 206, the same height as before.
  - The side island and its bridge were removed, along with 21 props that stood on the side island.
  - The GLB's three huts were solid blocks. Each hut body is now rebuilt as 4 walls, 0.35 GLB units thick (0.7 studs), with a doorway about 5.4 × 8.2 studs where the door panel was. The door panel is gone, so players can walk in.
  - Floating props:
    - Every prop cluster (trees, lamps, crates and so on) was settled onto whatever is below it.
    - One tree was 7.8 GLB units in the air and was moved down.
    - Nothing was left hanging over open air, so nothing was deleted.
- The GLB's **amethyst gem dropper is the high-tier dispenser**. It's tagged `ResourceDispenser`, `Tier = High`, and has a soft purple light. The old cyan dispenser is gone.
- The **neutral shop** is the team islands' GLB shop with a grey sign. It sits on the open north lawn (centre-local (0, 0, 49)) facing the dropper. The only clear spot is on the side that faces the gap between Green and Yellow.
- The arch and the 5 cover outcrops are gone. The GLB has its own cover: huts, the watchtower, crates and trees.
- `MapBuilder.CENTRE_STYLE = "GLB"` picks the new centre. `"Rust"` brings back the old one; its templates are still in `MapAssets`.

## How it's made
1. In Blender, import the GLB into the collection `FPSB_GLBCentre`. Then run:
   `exec(open(r"C:\Roblox Dev\FPS Bedwars\blender\fpsb_glb_centre.py").read()); build(); export(...)`
2. The output is `exports/FPSB_GLBCentre.fbx` plus `exports/glbc_origins.json`. Templates:
   - `GLBCentre`: island, huts, props, plaza
   - `GLBDropper`: the gem dropper machine
3. Import 3D the FBX (Anchored), then run `PrepareAssets.run({workspace.FPSB_GLBCentre})`.
4. Run `MapBuilder.build()`, then `MapChecks.run`.

Part naming:
- `GC_<Template>_<material>`: one mesh per material.
- `GC_Hut<Name><nn>_<material>`: hut boxes, **one mesh per box** (see the collision note below).
- Materials use the `GLBC:<material>` keys in `PrepareAssets.MATERIALS`: flat GLB colours, SmoothPlastic, glow parts Neon.
- Lamp glow and the purple banner don't collide.

## Collision lesson
The first import joined each hut's material into one big mesh. Roblox's PreciseConvexDecomposition then wrapped slanted hulls across the plateau hut's doorway: it looked open, but a player couldn't get in. Splitting the hut boxes into separate meshes fixed it. Each box now collides exactly, and a ray scan of the plateau doorway shows a clean 5.5 × 8 stud opening.

## Test results (2026-10-27)
- **MapChecks: pass.** Counts:
  - Bed 5
  - Shop 6
  - ResourceDispenser 6, with exactly 1 High
  - SpawnPad 5
  - BuildFloor 6
  - KillHeight 1

  The checks also cover symmetry, build zones, bed access, grounding (dropper and shop included), dispenser clearance and heights.
- **Playtest walk:**
  - East hut: in and out, clear.
  - West hut: in and out, clear.
  - Plateau hut: up the steps, through the door, to the back wall and out, clear (a jump onto the floor-slab step).
  - 8-point lap around the dropper: clear. One point stopped 2 studs short at a plaza pillar.
  - Shop front: clear.
- Saved to Roblox.

![[studio_glb_centre.jpg]]
