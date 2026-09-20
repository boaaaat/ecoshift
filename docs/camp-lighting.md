# Camp lighting

Torches use a solid cube ember head, not a wedge. All fixtures retain their steady colored illumination at every effects-quality setting. These are lights, not warmth or exposure-protection sources; they consume no ongoing fuel. The existing Trail Beacon still expires after 15 minutes.

## Graphics settings

Use **Settings > Graphics > Effects quality**:

- **Low:** static geometry and light; no fixture particles or flames.
- **Medium:** a few rising embers or colored motes.
- **High:** flame effects on torches, candles, and braziers; richer magical motes and animated orbital ornaments on applicable rare fixtures.

Reduced motion stops orbital animation. The shadows setting is respected. Cosmetics are local to each player and limited to the nearest 24 fixtures within 85 studs on Medium, or 40 within 150 studs on High. Distance and effect budgets do not reduce the actual light range.

## Ten additional recipes

Craft these in the Workbench's **Structures** category. Both campaign tier and workbench grade must meet the listed grade. All recipes produce one fixture.

| Light | Grade | Radius (studs) | Color and silhouette | Materials |
| --- | ---: | ---: | --- | --- |
| Candle Lantern | 1 | 10 | Cream-gold candle in a wooden cage | 2 Wood, 2 Resin, 1 Fiber |
| Mireglow Lantern | 2 | 18 | Soft green mushrooms inside a root cage | 4 Glowcap, 2 Glass, 1 Iron Bar |
| Frostglass Lamp | 2 | 22 | Ice-blue lens and frost-crystal crown | 4 Ice Crystal, 3 Glass, 2 Steel Bar |
| Ember Brazier | 3 | 26 | Red-orange coal bowl with metal claws | 3 Blacksteel Bar, 4 Black Glass, 3 Coal |
| Amethyst Obelisk | 3 | 28 | Violet crystal above an etched stone pedestal | 6 Clear Crystal, 3 Blacksteel Bar, 4 Enchanting Dust |
| Aurora Lantern | 4 | 32 | Mint lens, lavender ribbons, double brass arch | 4 Aurora Stone, 4 Glow Fiber, 3 Meteor Bar, 3 Glass |
| Starfall Orrery | 4 | 36 | Peach-gold star inside tilted satellite orbits | 2 Star Core, 4 Meteor Bar, 5 Impact Glass, 3 Gears |
| Stormcoil Beacon | 5 | 40 | Electric-blue reactor coils and lightning prongs | 5 Storm Bar, 6 Storm Ore, 4 Gears, 4 Clear Crystal |
| Abyssal Prism | 7 | 48 | Purple floating prism, four shrine pillars, runic halo | 6 Deep Metal, 8 Light Ore, 4 Pressure Glass, 1 Night Heart |
| Moonwell Beacon | 8 | 60 | Silver-lilac well, crescent crown, twin celestial halos | 8 Moon Bar, 6 Moon Thread, 1 Gravity Shard, 20 Enchanting Dust |

The existing Torch, Standing Lamp, and Trail Beacon retain their original recipes and light ranges (16, 24, and 16 studs). Standing lamps and trail beacons also receive square caged lamp heads.

## Placement and biome shifts

Creative mode has a dedicated **Lights** catalog section; lights no longer also appear in **Builds**. Every light can be placed anywhere on the generated map in Creative or Survival, while other structures remain restricted to camp. A light placed within the central camp radius is permanent. A light placed outside that radius is marked temporary and is automatically removed after the next successful biome generation.

The temporary flag is part of the world structure snapshot. Saving and rejoining before a shift restores the out-of-camp light with its pending expiration intact. Older saves infer the flag from a restored light's position, while in-camp lights save and restore normally.

## Implementation

`Shared/LightConfig.lua` owns fixture colors, ranges, recipes, and dimensions. `OverhaulCatalog.lua` registers them with the existing inventory, crafting, creative, and placement adapters. `Shared/Art/LightModels.lua` builds the low-poly models, and `LightEffects.client.lua` handles local graphics quality, culling, and cleanup. Both normal prefabs and build fallbacks use the same art generator. New servers and restored structures use the updated prefabs; explicitly authored `PrefabOverride` models remain untouched.

No tests or play sessions were run for this change.
