# Forged pick head

Original EcoShift native CSG geometry, created with `create_head.luau` and saved as
`src/ReplicatedStorage/Shared/Art/ForgedPickHead.rbxm`.

The head is one connected solid with 48 curved profile sections, narrowing depth,
and pointed ends. Roblox's GeometryService `SplitApart=true` confirms a single body.
It replaces the separate shoulders and blunt wedge beaks on all Pickaxe and
Universal tools. Palette colors still come from each tool's grade.

No purchased asset, uploaded mesh, runtime CSG, or runtime EditableMesh dependency.
The native authoring file is the editable source; Blender was not used for this object.

`scripts/check-pick-head.luau` checks saved-asset round trips and dense ray coverage
along the actual solid, plus empty space above its curved silhouette. The final
0.06 studs of each mathematical needle point are excluded from physics ray checks
because convex collision decomposition simplifies extremely thin tips.
