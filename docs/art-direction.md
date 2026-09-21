# EcoShift 3D art direction

The September 20, 2026 graphics pass uses smooth stylized expedition art: rounded organic silhouettes, visible stone grain, worn wood, layered metal, biome colors and restrained magical accents. UI and item icons are outside this pass, apart from exposing the graphics quality preference.

## Active libraries

| Library | Responsibility |
| --- | --- |
| `Art/ExpeditionEnvironment.lua` | Resources across 16 campaign biomes; original PBR rock and foliage meshes, smooth fungi, bark details, plants and crystals |
| `Art/ExpeditionScenery.lua` | Textured cave cladding, coursed ruins, wooden platforms, fungal landmarks and beacon housings |
| `Shared/Art/OverhaulBuildModels.lua` | 26 non-light structures, stations and camp objects with joinery, braces, checking, seams and hardware |
| `Shared/Art/OverhaulGearModels.lua` | 44 weapons and tools across ten families, including six articulated bows; rounded shafts, grips, collars, wraps and rivets |
| `Art/OverhaulCreatures.lua` | 64 species profiles across 23 anatomical families; rounded shoulders/muzzles, fur, scales, claws, feathers and animated joints |
| `Art/ExpeditionArmor.lua` | Four-slot visuals for 16 sets plus SunVest and DesertCoat; layered plates, folds, buckles and laces |

Environment and scenery are integrated through OverhaulWorldService. Gear is integrated through PrototypePrefabService and ToolService; ArmorService mounts body-relative R6/R15 decoration. Existing collision, AI, durability, harvesting, interaction and combat authority remain in their respective services.

## Materials and geometry

The weathered boulder has 4,376 triangles, smooth normals, softened chipped edges and original 1024px color, normal and roughness maps. The material includes slate/quartz variation, mineral fractures and sparse muted lichen. It replaces the flat block-shaped prototype throughout resources and cave cladding.

The original 960-triangle leaf cluster replaces the faceted tree crowns. Trees use asymmetric clusters, bark knots, branching roots and forked branches. Conifers layer progressively smaller rounded clusters, with separate snow surfaces. Fungal caps and stems use smooth native geometry with gills and surface spots. Crystals, cut masonry and blade edges retain intentional sharp planes.

Imported meshes are saved with `RenderFidelity.Precise` in `src/ServerStorage/ArtAssets.rbxm`, including SurfaceAppearance maps. High and Ultra preserve these authored surfaces while extending optional detail and decorative lighting distances. See [graphics quality](model-graphics-quality.md). Roblox's own engine graphics slider remains independent.

## Animation and holding

`ItemPose` and `ItemAnimations.client.lua` pose R6 Motor6D and current R15 AnimationConstraint arms after Animator evaluation. Item families cover weapons, harvesting tools, buckets, food, drinks, medicine and carried items. Held arms use a forward forearm with aligned wrist. Bows have a right-hand grip and left-hand draw: the holding arm extends before the string is pulled. Flexing limbs, moving string halves, nocked arrows, release, two-hand support and action gestures are included. Picks and cutting tips use saved continuous CSG geometry. See [item presentation](item-presentation.md).

`CreatureAnimation.client.lua` animates walking legs, supporting arms, breathing, head movement, wings, tails and serpentine spines from server movement. Presentation is distance-culled and respects Reduced Motion. It does not alter AI or collisions.

## Source assets

| Geometry | Source | Roblox mesh ID |
| --- | --- | --- |
| Weathered boulder | Original `assets/models/environment/weathered-boulder/WeatheredBoulder.blend` | `126878994432051` |
| Smooth leaf cluster | Original `assets/models/environment/smooth-canopy/SmoothCanopy.blend` | `95185961634095` |
| Grass clump | Free [Low Poly Nature Pack by Proudism](https://create.roblox.com/store/asset/9682467046) | `535380308` |

Each Blender-authored object has its own project, packed textures, adjacent PNG maps and GLB/FBX exports. Original procedural material masters are retained in the projects. See [asset manifest](../assets/models/environment/README.md) for map IDs. Native Roblox models remain editable through their Luau factories; they were not authored as Blender files.

The original imports belong to EcoShift's group, Revolutionary Raft Riders (34468779). Only grass geometry remains from the free pack; no marketplace scripts were imported. The old `assets/models/expedition-rock` project is retained as an unused modeling source, superseded by WeatheredBoulder. No purchases or game publishing occurred.

## Review limits

Source inspection and static Studio Edit art displays covered resources, creature silhouettes, camp objects, armor and held gear. The second pass inspected R6/R15 drawn, relaxed and released bows, sword, spear and hammer poses from front and side. Blender material previews and imported PBR surfaces were inspected. Temporary displays were removed afterward.

The subsequent user-authorized validation pass ran Studio Play sessions and reusable item, resource, spawn, and world-model checks. The item suite covers all 733 held items on native R6/R15 rigs; the world-model audit covers all builds, creatures, armor displays and intact/broken armor mounts. Live input checks use the player's R15 avatar. See [item presentation](item-presentation.md), [model graphics quality](model-graphics-quality.md), and [validation results](art-validation.md). Multiplayer delivery, every avatar bundle, and gameplay performance are outside this validation. Terrain composition and the existing lobby were not rebuilt.
