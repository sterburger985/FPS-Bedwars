# FPS Bedwars Decisions

Dated log of design and technical decisions and the reasons for them. Back to [[FPS Bedwars]].

- **2026-10-25: 5 team islands + 1 center island.** The reference images show 5 teams; the written brief said 4. Sterling chose the images.
- **2026-10-25: Islands truly float.** Tapered rocky undersides, open air below, ocean at Y = 0 far beneath. Kill height marked at Y = 60.
- **2026-10-25: One map for all modes (1–4 per team).** Islands are sized for 4-player squads with lots of room to expand bases and build defences.
- **2026-10-25: 12-stud building grid (Rust-like).** The "2×2" starter shed is 24×24 studs.
- **2026-10-25: Spacing.** Team island centres at radius 250 (widened from 230 at Sterling's request), at 72° steps. Gaps edge to edge: base→center ≈ 90, base→platform ≈ 59, platform→center ≈ 94, base→base ≈ 154. Arena ≈ 640 across.
- **2026-10-25: 5 resource platforms, one between each pair of neighbouring bases,** encouraging neighbour fights and keeping center routes clean.
- **2026-10-25: Starter shed is rusted corrugated metal** (images), not wood (brief).
- **2026-10-25: Neutral daylight** (brief), not golden hour (images), for FPS readability.
- **2026-10-25: Islands are all Blender meshes** (not Terrain or hybrid): closest match to the references. Islands are non-destructible.
- **2026-10-25: Same playfield on all 5 team islands, unique cliff edges and undersides,** so bases are fair but recognizable.
- **2026-10-25: Dispenser glow: amber on resource platforms, cyan at the center.**
- **2026-10-25: Keep a low rock arch at the center,** placed on the shop's in-between angle and curving over the back of the dispenser pad, so it stays off every team's direct approach.
- **2026-10-25: The GitHub repo holds Blender sources, exported meshes, textures, Luau scripts and docs.** The map itself lives in the place file.
- **2026-10-25: `C:\Roblox Dev\FPS Bedwars` is the local home of the GitHub repo** (Rojo code, Blender files, textures and notes in one place). Claude commits from the cloud and mirrors files into the folder; Sterling links it to GitHub once.
- **2026-10-25 (build): Team island ring radius is 260 (not 250).** A natural cliff edge around the fixed 120 × 96 build zone makes islands about 165 × 145. At 260 the gaps stay bridgeable and even: base→centre ~105, base→platform ~50, platform→centre ~100, base→base ~140. Promontories sit only on the back half of each island, so side and front gaps match between teams.
- **2026-10-25 (build): Geometry is generated from code in Blender** (`blender/fpsb_*.py`), so it's repeatable, and placed by `MapBuilder` so it's exactly symmetrical. Re-run the scripts to change shapes.
- **2026-10-25 (build): Surfaces use tiling MaterialVariants, not UV textures.** They tile cleanly at a fixed studs-per-tile with no stretching on 100+ stud cliffs. See [[Materials]].
- **2026-10-25 (build): Collision.** An invisible level `BuildFloor` slab covers each build zone (snaps to the 12-stud grid). Rock, sand, walls and frames use PreciseConvexDecomposition. Undersides, glow, cloth and the distant ridges are non-colliding.
- **2026-10-25 (build): Spawn pads are neutral SpawnLocations** (tagged `SpawnPad` with `Team`) so playtests spawn on islands until the team system exists.
- **2026-10-25 (build): The shop pivot is behind the counter (shopkeeper space).** Customers stand on the open front side.
