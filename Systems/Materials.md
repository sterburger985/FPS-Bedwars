# Materials

Back to [[FPS Bedwars]]. Owned by `ServerStorage.MapTools.PrepareAssets` (`MATERIALS` table). Each mesh name ends in a suffix that picks its look. After changing the table, run `PrepareAssets.restyle()` and then `MapBuilder.build()`.

| Suffix | Material | MaterialVariant | Colour | Used on |
|---|---|---|---|---|
| `_Rock` | Rock | FPSB_CliffRock | 236,226,212 | cliff strata, outcrops, arch |
| `_RockDark` | Slate | FPSB_RockDark | 196,186,176 | island undersides, distant ridges |
| `_Sand` | Sand | FPSB_PaleDirt3 | 244,236,222 | island tops |
| `_Rust` | Metal | FPSB_Steel | 212,146,100 | corrugated walls and roofs |
| `_Steel` | Metal | FPSB_Steel | 190,186,180 | frames, posts, dispensers, platform rims |
| `_Concrete` | Concrete | FPSB_Concrete | 226,224,218 | slabs, pads, platform decks |
| `_Wood` | WoodPlanks | FPSB_Wood1 | 222,210,196 | bed, shop fittings, crates |
| `_Cloth` | Fabric | — | team colour | bed blanket, flag |
| `_Linen` / `_Canvas` | Fabric | — | pale / dark grey | pillow / centre banners |
| `_Glow` | Neon | — | amber 255,170,60 / cyan 60,220,255 | dispenser cores, lamps |
| `_Glass` | Glass | — | 0.55 transparency | dispenser tubes |

## How they were chosen (2026-10-25)
- All variants are AI-generated in Studio (`generate_material`, 4 options each), compared on swatch blocks and then **on the real sheds and islands**.
- **Rejected:**
  - first rock and sand: too orange and busy
  - generated rust: painted red panels that fought the real corrugation
  - built-in CorrodedMetal: blotchy pink/white "camo" on the corrugated meshes
  - cracked-mud dirt: too busy underfoot
- Rust is weathered steel tinted rust-brown. The corrugation is real geometry, so the texture doesn't repeat it.
- Lights are kept restrained: cyan PointLight range 14 / brightness 0.6, amber 10 / 0.6. Stronger settings flooded the centre pad cyan.
