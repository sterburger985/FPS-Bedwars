# Phase 2b - Scrap Stations, Inventory and HUD

Back to [[FPS Bedwars]]. Previous: [[Phase 2a - Building and FPS Controls]]. System reference: [[Scrap and HUD System]] and [[Building System]]. Decisions: [[FPS Bedwars Decisions]].

**Status:** built, tested solo and with a 2-player local server, and saved to Roblox on 2026-10-30.

Sterling asked to replace the team shops with his scrap dropper and vending machine model (`imports/scrap-dropper.obj`). He attached the "Scrap collection, inventory & Rust-style HUD" spec. His answers:
- **Scope:** do the model swap plus the full spec.
- **Scale:** ×1 (native size).
- **Vending:** Materials sells Wood for Scrap. Guns shows "No stock yet".
- **Building pieces:** a right-click piece wheel (Rust style), and stairs added to the build menu.

The spec mentions a Rust screenshot, but only the OBJ, MTL and spec text arrived. The HUD follows the written description.

![[scrap_station.jpg]]

## Scrap station (one per team island)
- **Placement.** It stands where the old shop stood, at the same 24 × 13 footprint, with the vending machines facing the island middle.
- **Model.** Sterling's model, converted with `blender/fpsb_scrap_station.py` into 5 templates:
  - ScrapStation
  - ScrapClaw (animated)
  - VendGuns
  - VendMaterials
  - ScrapPickup (the scrap pile from the pad)
- **Collision.** The meshes never collide. Exact invisible box colliders are used instead, so the open pavilion can't be sealed. Shots still hit the visible meshes.
- **Labels.** GUNS and MATERIALS are added as SurfaceGuis on the model's label plates.
- **Tags:**
  - `Shop`: keeps the no-build zone and MapChecks
  - `ScrapDropper`: carries a `ScrapOutput` attachment on the pad
  - `VendingMachine`: on each machine, with `Machine = Guns | Materials`
- **Old stall kept.** `MapBuilder.SHOP_STYLE = "Kit"` brings it back, and `MapBuilder.rebuildShops()` swaps just the shops.
- **MapChecks still pass** with 5 shops.

![[scrap_pad_hud.jpg]]

## How scrap works
- **Drops.** Every 5 s each station drops 1 pickup on its pad, up to 5 uncollected. When full it pauses, and the next drop comes 5 s after a pickup frees a spot.
- **Lifetime.** Pickups expire after 60 s.
- **Pickups.**
  - rusty brown and grey blocky pile
  - slow spin and bob, no glow
  - the claw dips each drop
- **Collecting.** Press E at "Collect Scrap (+1)". The server checks:
  - the pickup still exists and hasn't been taken
  - the player is alive and in range
  - it marks the pickup taken first, then adds the Scrap
- **Balances.** Scrap starts at 0. Wood and Scrap are both server-owned balances in the `Resources` module, and the shop uses the same module.

## Vending
- **Opening.** Press E at a machine to open its menu. The mouse is freed and the view holds still.
- **Materials:**
  - Wood ×10 for 5 Scrap
  - Wood ×50 for 20 Scrap
- **Guns:** "No stock yet. Weapons are coming soon."
- **Closing.** E again, the X button, Esc, walking away, or dying.

![[scrap_vending.jpg]]

## HUD
- **Hotbar.** Bottom centre, 6 square slots: dark see-through backgrounds, thin grey borders, small slot numbers, and a blue highlight on the selected slot. It shows only items the player owns: the Blueprint, plus the Dev Hammer in Studio.
- **Scrap counter** beside the hotbar, with a "+1" pop on pickup.
- **Health.** Bottom right: a green bar with a white cross and the number. It reads the Humanoid directly, and Roblox's default health bar is turned off. No other survival stats.
- **Scaling.** Everything scales with screen height (×0.7 to ×1.6 of 1080p).

| Input | Action |
|---|---|
| 1–6 | select a slot (press again to put it away) |
| Mouse wheel | cycle through slots that hold something |
| B | blueprint |
| H | dev hammer (Studio only) |
| Q | put away |
| Hold right-click (blueprint) | piece wheel: Wall, Floor, Roof, Stairs, Corner Wall, Corner Floor, Corner Roof |
| R | rotate |
| Left click | build or hit |
| E | collect scrap, use vending |

![[build_wheel.jpg]]

## Stairs (new piece)
- **Size and cost.** One cell, one storey (12 × 12 × 12), for 15 Wood and 300 health.
- **Direction.** It climbs away from you by default; R turns it.
- **Build.** A wedge collider under 8 visible steps, so walking up is smooth.
- **Placement.** It needs the island ground or a floor under it. The tile above it must stay open (it's the stairwell), and the landing at the top counts as a connection for floors.

## Test results (2026-10-30)

**Solo**
- **Drops.** All 5 stations dropped every 5 s and stopped at 5 each (25 pickups).
- **Expiry.** Pickups expired after 60 s.
- **Recovery.** After pickups were deleted by something else, the next drop came 5.2 s later.
- **Collecting.** E added +1 Scrap and the HUD updated straight away.
- **Range check.** A prompt opened up to 40 studs and triggered from 21.5 studs was refused by the server: no scrap, pickup kept.
- **Hotbar.**
  - 1 put the blueprint in hand: the server's `Equipped` value matched and slot 1 lit blue.
  - The wheel opened on right-click with the camera frozen; picking Stairs and releasing restored the view.
  - Left click built the stairs for 15 Wood.
  - The character walked up the stairs to 12 studs.
  - The mouse wheel switched to the hammer and removed the preview; Q emptied the hands.
  - A forged build request with empty hands got "Hold the blueprint to build".
- **Vending.**
  - Guns showed the no-stock message.
  - Materials with 2 Scrap got "Needs 5 Scrap".
  - With 23 Scrap: "Bought Wood x10", Scrap 23 → 18 and Wood 85 → 95, and the HUD updated.
- **Health.** The bar tracked damage (including regeneration) and healing, and showed 100 after respawn.
- **Respawn.** One of each GUI, menus closed, first person restored.

**2 players (Red, Blue)**
- **Near race.** Both players pressed E on the same pickup. Player 1 got it, Player 2 got nothing, and it vanished for both. Player 2's press arrived after the pickup was gone, so a true same-frame tie couldn't be reproduced. The server handles one trigger at a time and marks the pickup taken before paying.
- **Independent balances.** P1 1, P2 2, and each HUD shows only its own.
- **Building.** P2's build was refused until the blueprint was in hand. Floor and stairs then built, P1 saw both, and P1 never saw P2's preview.
- **Console.** No errors; only the old `rbxassetid://203785492` warning.

## Notes
- **Esc** closes our menus, but Roblox also opens its own game menu on Esc, and that can't be blocked. E or X close the vending menu cleanly.
- **Test stock.** Players still get 100 test Wood on every spawn (`BuildingConfig.TEST_WOOD`). Set it to 0 once Wood should only come from vending.
- **Default regeneration.** Roblox regenerates health slowly; remove the default Health script later if that's not wanted.
