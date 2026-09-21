# Continuous cutting edges

Original native CSG geometry for the sickle arc and sword/dagger points.
`create_cutting_edges.luau` authors each solid at 100x scale to preserve thin tips,
asserts one connected body with GeometryService, then scales to held-item dimensions.
The saved result is `src/ReplicatedStorage/Shared/Art/CuttingEdges.rbxm`.

Runtime only clones the saved solids. No asset upload, runtime CSG, or EditableMesh
permission is required. No Blender file was used; the Luau file is the editable source.

`scripts/check-cutting-edges.luau` validates serialized geometry along the sickle
curve and across blade/tip junctions, plus negative probes in the hook interior
and outside the taper. Final zero-area needle points are excluded from physics rays.
