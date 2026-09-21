# Original environment models

One authored mesh object per Blender project. Both projects contain packed textures and editable procedural material masters. Cameras/lights are authoring aids. Base modeling used Blender's UI; material setup, baking and export used Blender scripting.

| Object | Blender project | Triangles | Roblox mesh |
| --- | --- | ---: | --- |
| Weathered boulder | `weathered-boulder/WeatheredBoulder.blend` | 4,376 | `126878994432051` |
| Smooth canopy | `smooth-canopy/SmoothCanopy.blend` | 960 | `95185961634095` |

Each folder also contains a GLB (embedded PBR maps), FBX, 1024px base-color/normal/roughness PNGs, and authoring scripts. Open the `.blend` in Material Preview to see its color and surface detail. The boulder project includes a configured preview camera and lighting.

## Imported texture IDs

| Map | Boulder | Canopy |
| --- | --- | --- |
| Color | `136929932601411` | `122623716283932` |
| Normal | `137495282180069` | `72862698146239` |
| Roughness | `110273088430065` | `79539535900338` |
| Metalness (black) | `83026043829482` | `83026043829482` |

The reusable Roblox templates are in `src/ServerStorage/ArtAssets.rbxm`, under ServerStorage.ArtAssets. Both MeshParts use Precise render fidelity, smooth normals, anchored noncolliding geometry and SurfaceAppearance. Environment/scenery factories clone them and provide gameplay colliders separately. Assets were uploaded to Revolutionary Raft Riders (34468779); no purchases were made.

`finish_asset.py` expects the corresponding UI-modeled starting object. `bake_export.py` expects its procedural material to be active; choose the retained procedural master before rebaking an already-baked project. These are asset-authoring scripts, not runtime or test code. The current `.blend` is the authoritative modeled source, including subsequent smoothing edits.
