# FPS Bedwars

Competitive multiplayer first-person survival shooter on Roblox. It keeps the Bedwars loop (team islands, beds that allow respawning, last team standing wins) but plays like a Rust-style survival FPS: resource gathering, modular building, firearms, atmospheric terrain. Rust is inspiration only; all models, textures, environments and UI are original.

- **Studio place:** "FPS Bedwars" (placeId 129535082094824)
- **Repo:** github.com/sterburger985/FPS-Bedwars
- **claude.ai Project:** "FPS Bedwars Roblox Development"
- **Rojo project:** this folder (`default.project.json`, `src/`)
- Back to [[Home]]

## Working rules (from Sterling)
1. Always ask questions before building.
2. Use the reference images as the visual target. Use Blender for the art.
3. One map for every mode (1–4 players per team).

## Current status
- **Phase 1: Map.** Built and tested in Studio on 2026-10-25. Waiting for Sterling's review. See [[Phase 1 - Map]].
- **Phase 1b: GLB team islands.** On 2026-10-27 the team islands were replaced with Sterling's blocky GLB island. Tested and saved. See [[Phase 1b - GLB Team Islands]].
- **Phase 1c: GLB centre island.** v1 went in on 2026-10-27. On 2026-10-28 it was replaced with Sterling's v2 GLB at ×1.5: walk-in huts, the gem dropper as the high-tier dispenser, and no centre shop. Tested and saved. See [[Phase 1c - GLB Centre Island]].
- **Phase 1d: GLB dispenser islands.** On 2026-10-28 the 5 resource platforms were replaced with Sterling's dispenser island (×1, fake drops removed). Tested and saved. See [[Phase 1d - GLB Dispenser Islands]].
- **Phase 1e: Map upgrade.** On 2026-10-28: starter building and bed in the middle (bed = team spawn), new shops, rim cover, thicker undersides, Amethyst Beacon, studs, scenery and lighting. Tested and saved. See [[Phase 1e - Map Upgrade]].
- **Phase 2a: Building and FPS controls.** On 2026-10-29: locked first person (FOV 85), a centred crosshair, and the B blueprint with 6 pieces (wall, floor, roof and true-L corner versions) on the 12-stud grid. Wood costs, server validation, piece health, a Studio dev hammer, and bridges. Tested solo and with 2 players, and saved. See [[Phase 2a - Building and FPS Controls]].
- **Phase 2b: Scrap stations and HUD.** On 2026-10-30 the team shops were replaced with Sterling's scrap dropper and vending machines (×1). Scrap drops every 5 s (max 5, 60 s life) and is collected with E. Materials vending sells Wood for Scrap. Also added: a Rust-style hotbar, a right-click piece wheel with new Stairs, a health bar, and a scrap counter. Tested solo and with 2 players, and saved. See [[Phase 2b - Scrap Stations and HUD]].
- Next: whatever Sterling picks (weapons for the Guns machine, beds/respawn rules, mid-map dispenser economy).

## Systems
- [[Map Design Spec]]: islands, structures, materials, lighting, Studio layout, gameplay tags
- [[Materials]]: suffix → material table and why each was picked
- [[Building System]]: blueprint building, grid, validation, resources, FPS camera and crosshair code
- [[Scrap and HUD System]]: scrap droppers, inventory, vending, hotbar and HUD code

## Decisions
See [[FPS Bedwars Decisions]]

![[studio_glb_aerial.jpg]]
