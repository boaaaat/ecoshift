# Model graphics quality

The in-game **Graphics quality** preference controls optional surface details and decorative lighting. It does not force Roblox's engine graphics slider, resolution, texture memory budget, or device quality level. Mesh smoothness comes from the authored geometry and normals. Imported hero meshes use `RenderFidelity.Precise`, set in Studio before saving the asset; a client script cannot write that protected property.

| Setting | Optional model detail distance | Decorative fixture effects |
| --- | --- | --- |
| Low | 60 studs | Disabled |
| Medium | 130 studs | Up to 24 nearby fixtures, within 85 studs |
| High | 260 studs | Up to 40 nearby fixtures, within 150 studs |
| Ultra | 450 studs | Up to 56 nearby fixtures, within 220 studs |

Only noncolliding parts explicitly marked `ArtDetail` are distance-culled. Structure surfaces, collision, interaction targets, creature silhouettes and useful light radii remain unchanged. Equipped tools keep their details visible. High and Ultra retain the authored smooth meshes; raising this setting cannot smooth flat normals in an old mesh.

Art producers can assign `ArtDetail = true` to optional non-interactive decorations before parenting their model into Workspace. A numeric value instead scales the distance from 0.25 to 2. Small rivets or seams can use 0.5, while larger surface ornaments can use 1.25. Do not mark body parts, structural surfaces, handles, resource interaction geometry or attachments required by effects. The client uses a small distance hysteresis to avoid boundary flicker and restores transparency and shadow properties when parts leave Workspace.

World shadows still follow the **World shadows** preference. Low quality disables them. Reduced motion continues to suppress rotating fixture ornaments; model detail culling adds no motion. Weather particle budgets remain capped at the High amount for Ultra.

The subsequent user-requested model audit constructed all 40 placeables, 64 creatures, 66 armor displays, and 264 armor mounts (each armor item on R6/R15 proportions, intact and broken). All 38,697 structural checks passed across 8,751 generated parts. The audit uses isolated unparented models and checks finite geometry, assembly joints, noncolliding decoration and optional-detail flags. All 220 Luau source/check files compiled with the official Luau 0.739 compiler. These checks do not establish visual fit for every avatar bundle or measure the graphics budgets during gameplay.

Roblox references: [MeshPart.RenderFidelity](https://create.roblox.com/docs/reference/engine/classes/MeshPart#RenderFidelity) and [asset library mesh detail](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/assemble-an-asset-library).
