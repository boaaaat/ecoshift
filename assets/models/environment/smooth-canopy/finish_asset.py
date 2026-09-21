"""Finish the UI-shaped UV sphere as an original, smooth stylized leaf cluster."""
import bpy, math
from pathlib import Path
ROOT = Path(__file__).resolve().parent
obj = bpy.context.object
obj.name = "SmoothCanopy"
obj.data.name = "SmoothCanopy"
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
# Broad asymmetric lobes retain a soft outline rather than a faceted sphere.
for v in obj.data.vertices:
    p = v.co
    angle = math.atan2(p.y, p.x)
    wave = 1 + .085*math.sin(angle*5 + p.z*4) + .045*math.cos(angle*3-p.z*7)
    p.x *= wave
    p.y *= wave
    p.z += .055*math.sin(p.x*5)*math.cos(p.y*4)
for p in obj.data.polygons: p.use_smooth = True
mat = bpy.data.materials.new("Leaf clusters - editable procedural master")
mat.use_nodes = True
mat.use_fake_user = True
n,l = mat.node_tree.nodes,mat.node_tree.links
bsdf = next(x for x in n if x.type == "BSDF_PRINCIPLED")
bsdf.inputs["Roughness"].default_value = .87
coord=n.new("ShaderNodeTexCoord")
stretch=n.new("ShaderNodeVectorMath");stretch.operation="MULTIPLY";stretch.inputs[1].default_value=(1,1,1.8)
l.new(coord.outputs["Generated"],stretch.inputs[0])
cells=n.new("ShaderNodeTexVoronoi");cells.inputs["Scale"].default_value=19
l.new(stretch.outputs[0],cells.inputs["Vector"])
ramp=n.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position=.08;ramp.color_ramp.elements[0].color=(.34,.43,.22,1)
ramp.color_ramp.elements[1].position=.85;ramp.color_ramp.elements[1].color=(.035,.10,.04,1)
ramp.color_ramp.elements.new(.46).color=(.16,.28,.095,1)
l.new(cells.outputs["Distance"],ramp.inputs[0])
noise=n.new("ShaderNodeTexNoise");noise.inputs["Scale"].default_value=5;noise.inputs["Detail"].default_value=3
mix=n.new("ShaderNodeMixRGB");mix.blend_type="MULTIPLY";mix.inputs[0].default_value=.34
l.new(ramp.outputs[0],mix.inputs[1]);l.new(noise.outputs["Fac"],mix.inputs[2]);l.new(mix.outputs[0],bsdf.inputs["Base Color"])
bump=n.new("ShaderNodeBump");bump.inputs["Strength"].default_value=.55;bump.inputs["Distance"].default_value=.055
l.new(cells.outputs["Distance"],bump.inputs["Height"]);l.new(bump.outputs["Normal"],bsdf.inputs["Normal"])
obj.data.materials.clear();obj.data.materials.append(mat)
for other in list(bpy.data.objects):
    if other.type == 'MESH' and other != obj: bpy.data.objects.remove(other,do_unlink=True)
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D': area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'SmoothCanopy.blend'))
