# Phase 1e - Map Upgrade

Back to [[FPS Bedwars]]. Previous: [[Phase 1d - GLB Dispenser Islands]]. Decisions: [[FPS Bedwars Decisions]].

**Status:** built, tested and saved to Roblox on 2026-10-28.

The plan was agreed on the Claude Design board "FPS Bedwars Map Upgrade Plan", with Sterling's changes:
- the starter base and bed go in the middle of each island
- the bed is the team spawn
- the banner moves to the back

![[upgrade_aerial.jpg]]

## What changed (5 team islands, centre, 5 dispenser islands)
- **Starter building.** The GLB hut is replaced by an identical 24 × 24 wooden building (2 × 2 build cells) in the middle of every team island, on the build grid.
  - Doorway is 6 × 8 and faces the map centre.
  - Walls are 9 tall, with two side windows.
  - The roof is partial: solid over the bed half, open beams over the door half.
  - There's a lantern by the door.
- **The bed is the spawn.** The team SpawnLocation sits inside, in front of the bed (about 11 studs from it).
  - 5 Teams (Red, Blue, Green, Yellow, Purple) are auto-assignable.
  - Each spawn is locked to its team (`Neutral = false`, `TeamColor`), so players spawn only at their own bed.
- **Banner** moved from the front edge to the back edge, still facing inward.
- **Shop.** A new 20 × 12 wood and metal stall stands where the old shop was, with the counter facing the island middle. It has:
  - a waist-high counter with a metal top
  - shelves of wood and metal supply crates
  - stock crates behind the counter
  - a big SHOP sign with a team-colour stripe, plus lamps
- **Cover** on the rim, off the main routes. Team islands have 6 pieces:
  - 2 low stone walls flanking the GLB's tall front fence
  - 1 blocky rock on the right edge
  - 2 wooden barricades on the sides
  - 1 metal crate stack at the back
  The centre gets a low wall and a barricade beside the Red and Green approaches. Its other approaches already have the GLB's rocks, huts and tower.
- **Terrain.** Raised studded rim ledges (1.2–2.2 tall) and small rim rocks sit outside the build zone. The 120 × 96 zone stays perfectly level.
- **Undersides.** Stepped stone formations hang under every island and darken with depth:
  - team islands: down to about −100 (was −61)
  - centre: about −130
  - dispenser islands: about −48
  They are non-colliding.
- **Amethyst Beacon** (high-tier dispenser):
  - the gem dropper is ×1.3, re-seated on its plaza
  - a large spinning amethyst crystal and a gold halo sit above it
  - a soft purple light column rises 60 studs, visible from every base
  None of the beacon collides or stops shots.
- **Studs.** Classic 1-stud texture on walkable tops: island sand and grass, the centre's paths and plaza, dispenser decks. Native Studs surfaces on Plastic kit tops: floors, roof, ledges, wall caps, spawn.
- **Scenery and lighting.**
  - 4 far blocky mountain ranges and 8 small islets were added; the 6 old ridges are kept.
  - Haze starts further out (Atmosphere density 0.28, offset 0.3, haze 1.2, glare 0.15).
  - Lighting: clock 14:00, brightness 2.6, saturation +0.05, contrast 0.08, faint sun rays.
  - Water: clearer teal-blue (32, 92, 120), transparency 0.35, waves 0.18 / 8.

![[upgrade_starter.jpg]]
![[upgrade_inside.jpg]]
![[upgrade_shop.jpg]]
![[upgrade_beacon.jpg]]
![[upgrade_island.jpg]]

## How it's made
- **`scripts/MapKit.luau`** (new) is where the box pieces live, as plain Parts:
  - KitStarter, KitShop, CoverWall, CoverBarricade, CoverCrates, plus rim ledges
  - Exact box collision, so doorways can never be sealed by convex hulls.
  - `MapBuilder.build()` rebuilds these templates every time.
- **`blender/fpsb_detail.py`** (new) builds the organic and large pieces from boxes:
  - undersides (sampled from each island template's bottom)
  - CoverRock and rim rocks
  - beacon crystal and halo
  - mountains and islets
  - Output: `exports/FPSB_Detail.fbx` + `exports/detail_origins.json`, parts `GD_<Template>_<material>`.
- **`src/client/MapSpin.client.luau`** (new) spins parts tagged `FPSB_Spin` on each client (no network cost).
- **MapBuilder**
  - `LAYOUT_GLB`: starter, bed, spawn, shop, banner, cover, ledges and rim rocks, all ray-checked for flat ground with no props in the way
  - `CENTRE_COVER`, `BEACON`
  - `setupTeams()`, `applyWater()`
- **MapChecks**
  - new checks: spawn within 14 studs of the bed and locked to its team; cover is grounded
  - zone edge sampled 1 stud out (see below)

## Test results (2026-10-28)
- **MapChecks: pass.** Counts:
  - Bed 5, Shop 5, SpawnPad 5, BuildFloor 6, KillHeight 1
  - ResourceDispenser 6, with exactly 1 High
  The checks also cover symmetry, level build zones, bed access through the doorway, spawn at the bed (10.8 studs, team-locked), grounding and dispenser clearance.
- **Playtest**
  - Spawned as Red inside Red's starter building.
  - Walked bed → door → shop counter → front lane → both front corners → right side → back → banner: every leg reached.
  - 8-point lap around the beacon: all reached.
- **Shot lines**
  - Clear: over both low walls and the barricades at eye height; door to both front corners; door to the shop counter; straight through the beacon column.
  - Low walls stop crouch-height shots.
- **Part count:** about 760 for the whole map (384 MeshParts). Cover and kit pieces are reusable models.
- Saved to Roblox.

## Notes
- After the Studio update, setting PreciseConvexDecomposition again recomputed collision to follow the GLB island's real rim notches. The old hulls had covered them. The zone edge check now samples 1 stud past the zone (on the sand) instead of 2.
- The GLB's own front fence (about 5 tall, x −22..2) still stands in the front lane. Players step 3 studs right of it to reach the edge. The left low wall was moved to flank it instead of sitting behind it.
