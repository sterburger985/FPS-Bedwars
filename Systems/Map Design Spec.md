# FPS Bedwars — Map Design Spec

Back to [[FPS Bedwars]]. Repo copy: `docs/superpowers/specs/2026-10-25-map-design.md`

Date: 2026-10-25
Status: Draft, awaiting Sterling's review
Scope: map geometry, materials, textures, lighting and placement of gameplay landmarks only. No combat, inventory, economy, shop UI or bed logic.

Source material: `FPS BEDWARS — MAP BUILDING AND TEXTURE SPECIFICATION` (original brief) and two reference boards (map overview, starter build, shop, dispensers, central island, material swatches, atmosphere). Where the brief and the images disagreed, the decisions below record which one wins.

## 1. Decisions

| Topic | Decision | Source |
|---|---|---|
| Team count | 5 team islands + 1 center island | Images (brief said 4) |
| Island base | Truly floating, tapered rocky undersides, open air below | Brief |
| Team size | One map for 1–4 player modes; islands sized for 4-player squads with expansion room | Sterling |
| Building grid | 12 studs per unit; starter shed = 2×2 = 24×24 studs | Sterling |
| Resource platforms | 5, one between each pair of neighbouring bases | Sterling |
| Starter shed look | Rusted corrugated metal | Images (brief said wood) |
| Lighting | Neutral daylight, pale blue sky, light haze | Brief (images were golden hour) |
| Construction | All Blender meshes for islands, structures and props | Sterling |
| Island variety | Identical playfield, unique cliff silhouette/underside per island | Sterling |
| Dispenser glow | Amber on resource platforms, cyan at center | Sterling |
| Center arch | Keep a low rock arch | Sterling |
| Repo contents | Blender sources, exported meshes, textures, Luau scripts, docs | Sterling |

Team colours: Red, Blue, Green, Yellow, Purple.

## 2. Layout and scale (studs)

- Coordinate origin = map center. Team island centers at radius **250**, angles 90°, 18°, −54°, −126°, 162° (Red at 90°, then clockwise Blue, Green, Yellow, Purple — i.e. 72° steps).
- Team island: ~140 across overall. Flat build zone ~120 × 96 (10 × 8 grid cells), top at **Y = 200**.
- Center island: ~180 across, top at **Y = 206**.
- Resource platforms: 36 × 36 (3 × 3 cells), top at Y = 200, at the midpoint of the chord between neighbouring bases (radius ≈ 202, on the angle halfway between the two bases).
- Edge-to-edge gaps: base→center ≈ 90; base→nearest platform ≈ 59; platform→center ≈ 94; base→neighbour base ≈ 154. Arena ≈ 640 across.
- Undersides taper to a jagged point ≈ 80–90 below the top (team), ≈ 100 (center).
- Ocean surface **Y = 0**. Kill height **Y = 60**, marked by a tagged part (`KillHeight`), not enforced by map code.

### Team island playfield (identical on all five, in island-local space; −Z faces the center)

- Bed shed on the outer/back side, doorway facing the yard and center.
- Spawn pad in the yard between the shed and the front edge.
- Shop stall to one side of the spawn pad, ≥ 18 studs from the shed so traffic doesn't bunch up.
- Team banner mast beside the shed.
- 3–4 low rock outcrops (≤ 6 studs tall) at the build-zone edges for cover; none inside the central build area or on the route to the front edge.
- Front edge left open with a clear line toward the center island.

## 3. Island geometry (Blender)

Each main island is split into mesh pieces, each under Roblox's per-mesh triangle limit:

1. **Top surface**: sand/dirt, ±1 stud undulation outside the build zone, perfectly flat inside it.
2. **Cliff rim**: layered sedimentary strata, chipped ledges, cracks, angular breaks.
3. **Underside**: tapered rock with strata bands, ending in a jagged point. CanCollide off.
4. **Outcrops**: separate rocks/shelves from a pool of ≥ 8 distinct shapes so no shape is reused on the same island.

Variation: the five team islands share the same playfield and cover positions; cliff rim and underside are unique per island (different seeds and hand edits) with matching footprint area.

Center island: dispenser pad at exact center, five low rock shelves at 5-fold symmetry facing each team's approach, neutral shop on one in-between angle, and a **low rock arch** on that same in-between angle, curving over the back of the dispenser pad. The arch keeps clearance ≥ 14 studs, stays off every team's direct approach line, and must not hide the dispenser from any approach.

Collision:
- Invisible, anchored, CanCollide flat parts at Y = 200 aligned to the 12-stud grid under each build zone (cheap, perfectly level, snappable).
- Cliff rim and outcrops: `CollisionFidelity = PreciseConvexDecomposition`.
- Top surface mesh: visual only where a flat collision part covers it; collision on elsewhere.

## 4. Structures (Blender models)

| Model | Count | Size (studs) | Notes |
|---|---|---|---|
| StarterShed | 5 | 24 × 24 × ~12 | 1-stud concrete slab, 4 steel/timber corner posts, rusted corrugated walls, full corrugated roof, open doorway 6 W × 9 H facing yard, no door |
| Bed | 5 | ~4 × 7 | Against back wall, team-colour blanket, ≥ 3 studs clear on open sides |
| BannerMast | 5 | ~24 tall | Steel mast, team-colour flag |
| ShopStall | 6 | ~24 × 16 | Open front, slanted corrugated roof, counter, crates, shelving, NPC space behind counter, sign board with cart icon + `SurfaceGui` "SHOP" text; center version uses neutral grey sign |
| ResourceDispenser | 5 | ~6 × 6 × 8 | Industrial generator, glass core, amber glow (restrained PointLight + Neon core) |
| ResourcePlatform | 5 | 36 × 36 | Concrete deck, low rim, a few crates, short tapered rock/steel underside |
| CenterDispenser | 1 | ~12 × 12 × 14 | Under steel gantry canopy with banners, cyan core, larger and brighter than platform dispensers but not scene-dominating |
| DistantIslands | 1 set | n/a | Low-detail horizon silhouettes, no collision |

## 5. Materials and textures

Tiling PBR sets (color, normal, roughness, metalness where relevant) created in Blender, exported, uploaded and applied with `SurfaceAppearance`:

- Rock (warm tan/ochre/grey-brown, strata, cracks)
- Sand/dirt (pale tan, faint pebbles, visually quiet)
- Rusted corrugated metal
- Sheet/weathered steel
- Concrete
- Weathered wood

Rules: consistent UV texel density (target 1 texture tile ≈ 16 studs on terrain pieces); no stretched textures; no texture-imitating micro-parts; distinguish objects by shape and material, not colour alone.

## 6. Environment

- Terrain water slab at Y = 0 extending well beyond the arena; deep blue-grey water colour, low reflectance, gentle waves.
- Lighting: ClockTime ≈ 13, neutral exposure, natural shadows. (`Lighting.Technology` can't be set through the Studio connector and current Studio uses one unified lighting mode, so it isn't set by the map.)
- Atmosphere: light haze toward the horizon, low density so enemies stay readable.
- Sky: pale blue.
- Effects: remove DepthOfField and SunRays; keep Bloom, toned down.

## 7. Studio organisation

```
Workspace.Map
  TeamIslands/Red, Blue, Green, Yellow, Purple   (each: Island, StarterShed, Bed, ShopStall, BannerMast, SpawnPad, Outcrops, BuildFloor)
  Center                                         (Island, CenterDispenser, ShopStall, Arch, Outcrops, BuildFloor)
  ResourcePlatforms/RP_RedBlue, RP_BlueGreen, ... (Platform, ResourceDispenser)
  Environment                                    (DistantIslands, KillHeight)
ServerStorage.MapAssets                          (master templates for every model above)
```

A Luau placement script stamps templates from `MapAssets` into `Workspace.Map` at exact 72° steps around the origin. Re-running it rebuilds `Workspace.Map` without touching anything else in the place.

Gameplay hooks (CollectionService tags + attributes): `Bed` (Team), `Shop` (Team or "Neutral"), `ResourceDispenser` (Tier = "Basic" | "High"), `SpawnPad` (Team), `BuildFloor`, `KillHeight`.

Existing place contents (Baseplate, default SpawnLocation) are removed; nothing else in the place is touched. The Rojo `default.project.json` in the vault currently defines a Workspace Baseplate and Lighting properties; those entries must be removed so `rojo serve` doesn't recreate the Baseplate or overwrite map lighting.

## 8. Repo layout

`C:\Roblox Dev\FPS Bedwars` is the local home of the GitHub repo (Rojo project, assets and Obsidian notes together).

```
default.project.json, aftman.toml   Rojo project (Baseplate and Lighting entries removed)
src/                                Rojo-synced Luau (client / server / shared)
blender/                            .blend sources
exports/                            FBX meshes as imported into Studio
textures/                           tiling PBR maps
scripts/                            Luau map placement/build script
docs/                               this spec, plan
FPS Bedwars.md, Decisions, Systems/ Obsidian notes
```

Claude can't run git on Sterling's PC, so Claude commits from the cloud copy and mirrors files into the vault folder; Sterling links the folder to GitHub once (clone or GitHub Desktop).

## 9. Known risks

- Pivot gotcha: a Model with a PrimaryPart ignores `WorldPivot`; templates set pivots through `PrimaryPart.PivotOffset` (bottom-centre) before placement.
- Connector screenshots come back white if Studio is minimised; Studio must stay on screen during visual checks.

- Mesh import goes through Studio's 3D importer. If it can't be driven automatically, Sterling clicks Import once per batch.
- Uploaded mesh and image assets may sit in Roblox moderation briefly before they render.
- All-mesh islands can't be carved by players; islands are non-destructible.

## 10. Verification (definition of done)

Screenshots and checks from: (1) high aerial, (2) each team spawn, (3) each shed doorway, (4) each resource platform approach, (5) the center dispenser, (6) eye level in first person. Playtest walk with the character to confirm:

- no stuck spots or invisible barriers
- every doorway clear and every bed reachable and attackable
- every dispenser reachable with room to stand
- no floating props or clipping
- matching layouts on all five bases
- no obvious texture repetition or stretching
- landmarks identifiable from distance

Done when: 5 team islands + center all floating, balanced bases each with a 2×2 starter shed and bed, a shop on all 6 main islands, 5 resource platforms with dispensers, the cyan center dispenser, and consistent materials and lighting matching the references.
