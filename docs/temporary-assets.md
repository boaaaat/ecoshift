# Temporary Creator Store art

Geometry-only prototypes used during gameplay development:

| Asset | Creator | Use |
| --- | --- | --- |
| [Low Poly Nature Pack](https://create.roblox.com/store/asset/9682467046) | Proudism | Tree, rock, mushroom, grass, log and bush meshes |
| [Pickaxe](https://create.roblox.com/store/asset/13690492118) | NoNoElevator | Held harvesting tool |
| [low poly wolf](https://create.roblox.com/store/asset/440929613) | RohninCode | Temporary creature silhouettes |

All three were returned as free by the Studio Creator Store search on 2026-09-07. Imported script containers were removed/checked; no third-party gameplay scripts are used. The selected geometry, colors, original mesh sizes and transforms are recorded in `src/ServerStorage/PrototypeVisuals.lua` and constructed by `PrototypePrefabService`. Mesh content remains hosted on Roblox and subject to asset availability. Monster variants currently reuse tinted wolf geometry; weapons and stations use simple temporary parts where final meshes are absent. These are placeholders for the planned Blender art.

Authored prefabs under ServerStorage take precedence over generated prototypes. Replace individual templates under ResourcePrefabs, PropPrefabs, EnemyPrefabs, Tools and BuildPrefabs without changing gameplay IDs. Rojo preserves unmanaged asset instances; commit final authored model files separately when available.

The alternative Pickaxe tool (6109084141) was inspected but its union geometry was not used. No paid assets were acquired.
