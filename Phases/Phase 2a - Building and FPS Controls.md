# Phase 2a - Building and FPS Controls

Back to [[FPS Bedwars]]. Previous: [[Phase 1e - Map Upgrade]]. System reference: [[Building System]]. Decisions: [[FPS Bedwars Decisions]].

**Status:** built, tested solo and with a 2-player local server, and saved to Roblox on 2026-10-29.

This phase follows Sterling's spec "Building mechanics & first-person controls". His answers to the four questions:
- **Resources:** minimal Wood plus test stock. Wood is a server-owned value per player; each spawn tops it up to 100.
- **Wall height:** 12 studs, cube cells. A wall is 12 × 12 and each storey is 12 tall.
- **Build area:** anywhere connected, including enemy islands and bridges. Never inside spawns, starter buildings, shops, dispensers or the beacon plaza.
- **Destruction:** a server damage API plus a Studio-only dev hammer.

![[build_fort.jpg]]

## What a player gets
- **First person, always.** The camera is locked first person with FOV 85. Head and hats are hidden. Normal Roblox movement is kept, and it all comes back after a respawn.
- **Crosshair.** Four outlined lines, exactly centred, with a `kick()` spread ready for guns. In blueprint mode the lines tighten, a centre dot appears, and the colour turns green or red. The dev hammer turns it orange.
- **Blueprint** (key **B**). The bottom bar shows the six pieces with their key, name and cost, plus the Wood count. A status line reads "Can't build: <reason>" in red, or the piece name and controls in green.

| Key | Action |
|---|---|
| B | equip / put away the blueprint |
| 1–6 | Wall, Floor, Roof, Corner Wall, Corner Floor, Corner Roof |
| R | rotate 90° |
| Q / Esc | put the blueprint away |
| Left click | build |
| H | Studio only: dev hammer (60 damage per hit) |

  E is never bound, so shop and dispenser prompts keep working. The default Roblox tool hotbar is turned off so 1–6 are free; a custom weapon hotbar will replace it.
- **Preview.** A see-through green or red ghost with an outline. It lives under the local camera, so nobody else sees it.

![[build_preview_red.jpg]]

## Pieces (all in `BuildingConfig`)

| Piece | Shape | Cost | Health |
|---|---|---|---|
| Wall | 12 × 12 × 1 on a cell edge, framed | 10 Wood | 300 |
| Floor | 12 × 1 × 12 tile | 10 Wood | 250 |
| Roof | 12 × 1 × 12 slate tile; caps a building | 10 Wood | 250 |
| Corner Wall | true L: two walls on one cell corner plus a corner post | 15 Wood | 400 |
| Corner Floor | true L: three tiles of a 2 × 2 block | 15 Wood | 350 |
| Corner Roof | true L: three roof tiles of a 2 × 2 block | 15 Wood | 350 |

## Connection rules
- **Floors**:
  - on the island's level build zone
  - straight off its edge (the first bridge tile)
  - beside another floor or roof (bridges)
  - on top of walls, or at the foot of a wall
- **Walls**:
  - on the build zone
  - stacked on a wall
  - standing on a floor
  - hanging under a floor or roof
- **Roofs**: on top of walls, or beside another floor or roof. Nothing can stand on a roof.
- **Blocked**:
  - overlapping map geometry (terrain, props, cover)
  - overlapping a player
  - an occupied slot
  - more than 22 studs away
  - more than 5 storeys up, or below the ground level
  - outside the map
  - inside a no-build zone

## Test results (2026-10-29)

**Solo**
- **Placement** worked for all six pieces. First person, FOV 85, hidden head, the crosshair GUI and the bar all checked out, and R rotation changed the ghost.
- **Validation.** Each of these was refused with the right reason, and none cost any Wood:
  - occupied slot
  - a player in the way
  - a floor with no connection
  - a roof with no walls
  - a wall on a roof
  - too far away
  - below the ground level
  - the starter's doorway
  - near the shop
  - blocked by map props
  - forged requests: non-integer, string or out-of-range values, an unknown grid or piece, a non-table
- **Costs.** Wood went down exactly once per build (10 or 15).
- **Spam.** 8 requests for the same slot at once built 1 piece and took 10 Wood. The rest got "Building too fast".
- **Destruction.** The dev hammer broke a wall in 5 hits. The piece darkens as it weakens. Once it was gone the slot freed up, nothing was left in the way, and it could be rebuilt.
- **Respawn.** After dying there was still exactly one crosshair and one build bar, the camera was still locked first person, and B and 1–6 still worked.

**2 players (local server, Red and Blue)**
- Player 1's pieces showed up for Player 2 with all their parts. Player 2 got "Space already built" on Player 1's slots.
- Player 2 (Blue) extended Player 1's bridge on Red's island.
- Player 1's ghost existed only on Player 1. Player 2 and the server had none.
- Player 1 could not build a wall or a floor through Player 2's body.
- Player 2's hammer destroyed Player 1's wall, it disappeared for Player 1 too, and Player 1 rebuilt in the freed slot.
- The server console showed no errors.

## Notes
- **The rim outside the build zone is uneven.** The GLB grass, rim ledges and rocks sit above ground level on the sides and back. A first bridge tile there is refused ("Blocked by the map"). The front edge (towards the centre) is clear. Elsewhere, players can go up a level: build a wall on the zone edge, then a floor on top, then bridge outward.
- **The starter zone sits inside its 2 × 2 cells** (margin −1). Players can build right against its side and back walls. The front beams reach 0.9 studs past the cells, so the row of tiles straight in front of the door is no-build, which keeps the doorway clear.
- **Execute-Luau resets a Scriptable camera** back to Custom, so aiming tests moved the character instead. The edit-time `screen_capture` with camera_position still works during Play.
- **Testing two players:** the client-count box at the top left must be set to 2 before Test → Start Test Session → Server and Clients (it was 0). End with Test → End Session.
- A warning that existed before this phase, `rbxassetid://203785492 … Asset type does not match`, comes from an older asset and is harmless.
