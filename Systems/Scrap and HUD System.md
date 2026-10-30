# Scrap and HUD System

Code reference for scrap, inventory, vending and the HUD. Built in [[Phase 2b - Scrap Stations and HUD]]. Building is in [[Building System]]. Back to [[FPS Bedwars]].

## Files

| File | Runs on | Job |
|---|---|---|
| `src/shared/ScrapConfig.luau` | both | interval 5 s, 1 per drop, max 5, lifetime 60 s, value 1, prompt range 8, resting spots |
| `src/shared/ShopConfig.luau` | both | machines and items (Materials: Wood ×10 / ×50 for 5 / 20 Scrap; Guns: empty) |
| `src/shared/Items.luau` | both | hotbar items (Blueprint, Dev Hammer for Studio only) and the starting loadout |
| `src/server/Resources.luau` | server | the one balance store: Wood and Scrap as player attributes. `get`, `add`, `canAfford`, `trySpend` |
| `src/server/InventoryService.luau` | server | hotbar slots (`Hotbar` attribute), item in hand (`Equipped`), `Remotes.Equip`, `give`, `take`, `has`, `equipped` |
| `src/server/ScrapDropperService.luau` | server | drops, cap, expiry, collect validation, `Remotes.ScrapCollected` |
| `src/server/ShopService.luau` | server | `Remotes.ShopBuy`, `purchase(player, machine, item)` |
| `src/client/HUDStyle.luau` | client | shared colours, fonts, panel and label helpers, resolution scaling, drawn item icons |
| `src/client/HotbarController.luau` | client | slots, 1–6, mouse wheel, B / H / Q, the Equip remote, tells BuildingController |
| `src/client/HUDController.luau` | client | health (bottom right) and the scrap counter |
| `src/client/ScrapPickupController.luau` | client | pickup spin and bob, claw dip |
| `src/client/VendingController.luau` | client | vending menu |

The entry scripts start everything in order. The client entry turns off Roblox's Backpack and Health bars; only the display goes, and the Humanoid is untouched.

## Who decides what
- **Balances.** Only `Resources` writes them; clients read their own attributes. Scrap pickups, vending purchases and building costs all go through it.
- **Item in hand.** The client asks with `Remotes.Equip(slot)`. The server checks the slot holds an item and sets `Equipped`. BuildingService refuses builds unless it's `Blueprint`, and the dev hammer needs `Hammer`.
- **Collecting.** The pickup's ProximityPrompt fires on the server. The server checks the pickup is not taken and still exists, and that the player is alive and within 8 + 4 studs. It marks the pickup taken, removes it, adds the Scrap, then tells that player.
- **Buying.** The server checks:
  - the machine is a real `VendingMachine` in the workspace
  - it sells that item
  - the player is alive and within 14 studs of the machine front
  - a 0.2 s cooldown

  Then `trySpend` takes the whole price or nothing, and the goods are added.

## Map hooks (MapBuilder)
- **Station placement.** `buildScrapStation(folder, cf, team)` places the station, claw, vending machines, colliders, labels, prompts and tags.
- **Position.** `LAYOUT_GLB.scrapStation` puts the footprint centre where the old shop was.
- **Pickup point.** `SCRAP_OUTPUT` is the top of the pad in station space.
- **Switching shops.** `SHOP_STYLE = "Scrap" | "Kit"`; `rebuildShops()` swaps only the shops.

## Adding things later
- **A new resource:** add it to `Resources.KINDS` and `START`.
- **Weapons:**
  1. add them to `Items.DEFS`
  2. sell them in `ShopConfig.MACHINES.Guns.items` with a `give` that calls `InventoryService.give(player, "Rifle")` (extend `ShopService.purchase` for item goods)
  3. draw an icon in `HUDStyle.icon`
  4. teach HotbarController's `setTool` path to equip it
- **Crosshair spread:** `CrosshairController.kick()` is ready for firing.
