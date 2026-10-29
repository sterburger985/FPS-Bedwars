# Building System

How blueprint building and the first-person controls work in code. Built in [[Phase 2a - Building and FPS Controls]]. Back to [[FPS Bedwars]].

## Files (Rojo paths)

| File | Runs on | Job |
|---|---|---|
| `src/shared/BuildingConfig.luau` | both | every tunable value: grid, sizes, costs, health, distances, zone margins, rate limits, FOV, sensitivity |
| `src/shared/BuildGrid.luau` | both | the one placement calculation: `targetFor` (aim → slot), `footprint`, `evaluate` (allowed? why not?), slot `Registry`, zone and overlap tests |
| `src/server/Resources.luau` | server | Wood per player (player attribute, server-written). `get`, `add`, `canAfford`, `trySpend`; test stock on spawn |
| `src/server/BuildingService.luau` | server | publishes grids and zones, validates and builds, `damage(part, amount)`, `destroy`, dev hammer remote |
| `src/client/FPSController.luau` | client | LockFirstPerson, FOV, sensitivity, hides head and hats |
| `src/client/CrosshairController.luau` | client | four-line crosshair, `setMode`, `setValid`, `kick`, `aimRay` |
| `src/client/BuildUI.luau` | client | bottom bar, Wood count, status line, key hint |
| `src/client/BuildingController.luau` | client | input, aim, preview ghost, place requests, dev hammer |

The entry scripts `src/server/init.server.luau` and `src/client/init.client.luau` start the modules. The client entry also turns off the default Backpack hotbar.

## The grid
- **One grid per `BuildFloor`.** Each team island has one, and so does the centre. The grid's id is the island folder name ("Red", "Center", …).
  - Origin: the island's level ground (BuildFloor top), with the island's rotation.
  - Cells are 12 × 12, with edges on multiples of 12. The 120 × 96 team zone is 10 × 8 cells; the centre is 8 × 8.
  - A level is every 12 studs.
- **Slot keys:**
  - `S:i:j:k` is a floor or roof tile of cell (i, k) on level j.
  - `W:i:j:k:d` is the storey j wall on a cell edge. d = 0 runs along x at z = 12k; d = 1 runs along z at x = 12i.
- **Pieces keep the grid of what they attach to,** so a bridge stays on its home island's grid.

## A placement, end to end
1. **Client, every frame while the blueprint is out:**
   - Ray from the camera through the crosshair, up to 26 studs. On a miss, use where the ray crosses the player's foot level.
   - Pick the grid: the piece being looked at, else the nearest piece within 30 studs, else the nearest island zone.
   - `BuildGrid.targetFor` gives `{piece, grid, i, j, k, rot}` (integers only).
   - `BuildGrid.evaluate` decides the ghost colour and the reason text.
2. **Click:** the client sends that request to `Remotes.BuildPlace` (a RemoteFunction).
3. **Server:**
   - rebuilds the request from its six fields
   - checks the rate limit (one build per 0.12 s, burst of 5) and that the player is alive
   - runs the same `BuildGrid.evaluate`, from the player's real head position, with 6 studs of slack for latency
   - charges with `Resources.trySpend` only after every check passes
   - builds the model in `workspace.Builds` and adds it to its registry

   Nothing yields between the check and the build, so a piece can never be charged twice or built twice.
4. **Clients** pick the new model up through `Builds.ChildAdded`. Its attributes (`Grid`, `Keys`, `Piece`) feed each client's registry, even when its parts are streamed out.

## Evaluate order
1. request shape
2. level range and map radius
3. reach
4. occupied slots
5. connection
6. no-build zones
7. world overlap (exact collision with `GetPartsInPart`, boxes shrunk 0.2 per side; players are always blocking, non-colliding props never are)
8. resources

## No-build zones
The server publishes these to `ReplicatedStorage.BuildZones`: the bounding box of each item below, grown by its margin, and raised 24 studs.

| Item | Margin (studs) |
|---|---|
| starter building | −1 |
| bed | 2 |
| spawn pad | 4 |
| shop | 3 |
| dispenser | 6 |
| centre beacon plaza | 10 |

Zones are tested with an oriented-box (separating axis) test.

## Piece models
- **Attributes:** `Piece`, `Grid`, `Keys`, `Slot`, `Owner` (UserId), `Team`, `Health`, `MaxHealth`.
- **Tag:** `BuildPiece`.
- **Parts:** one collision part per box. Walls also get non-colliding, non-query frame trims.

## Hooks for later
- **Weapons:** call `BuildingService.damage(hitPart, amount, attacker)`. The piece darkens as it weakens and is removed at 0 HP.
- **Shops and dispensers:** use `Resources.add(player, "Wood", n)` and `Resources.trySpend(player, cost)`. Remove the test stock (`TEST_WOOD`) when they hand out Wood.
- **Weapon UI:** `CrosshairController.kick(amount)` spreads the crosshair; `setMode("default")` restores it.
- **Settings menu:** `FPSController.setSensitivity(n)`.
