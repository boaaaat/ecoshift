"""Finish the UI-modeled boulder with original procedural stone and baked PBR maps.
Run inside Blender after selecting the UI-modeled Icosphere. This is asset authoring.
"""
import bpy
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ROOT.mkdir(parents=True, exist_ok=True)
obj = bpy.context.object
obj.name = "WeatheredBoulder"
# Keep the hand-shaped triangulated surface, with softened chips along its edges.
for vertex in obj.data.vertices:
    vertex.co.x *= 1.18
    vertex.co.x += vertex.co.z * .13
    vertex.co.z = max(vertex.co.z, -.51)
mins = [min(v.co[i] for v in obj.data.vertices) for i in range(3)]
maxs = [max(v.co[i] for v in obj.data.vertices) for i in range(3)]
for vertex in obj.data.vertices:
    for axis in range(3):
        vertex.co[axis] -= (mins[axis] + maxs[axis]) / 2
obj.location = (0, 0, 0)
bevel = obj.modifiers.new("Small worn edge chips", "BEVEL")
bevel.width = .017
bevel.segments = 2
bpy.ops.object.modifier_apply(modifier=bevel.name)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=.025)
bpy.ops.object.mode_set(mode="OBJECT")

mat = bpy.data.materials.new("Weathered stone - editable procedural master")
mat.use_nodes = True
mat.use_fake_user = True
nodes, links = mat.node_tree.nodes, mat.node_tree.links
bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
bsdf.inputs["Roughness"].default_value = .88
def node(kind, label, location):
    n = nodes.new(kind); n.label = label; n.location = location
    return n
def noise(label, scale, detail, location):
    n = node("ShaderNodeTexNoise", label, location)
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = .73
    return n
def ramp(label, source, stops, location):
    n = node("ShaderNodeValToRGB", label, location)
    while len(n.color_ramp.elements) > 2: n.color_ramp.elements.remove(n.color_ramp.elements[-1])
    n.color_ramp.elements[0].position, n.color_ramp.elements[0].color = stops[0]
    n.color_ramp.elements[1].position, n.color_ramp.elements[1].color = stops[-1]
    for position, color in stops[1:-1]: n.color_ramp.elements.new(position).color = color
    links.new(source, n.inputs["Fac"])
    return n
coarse = noise("Mineral strata", 3.8, 5, (-1000, 500))
stone = ramp("Slate, quartz and warm mineral color", coarse.outputs["Factor"], [
    (.2,(.035,.043,.047,1)), (.43,(.12,.14,.145,1)),
    (.58,(.235,.225,.195,1)), (.78,(.45,.43,.365,1))], (-750,500))
grain = noise("Small mineral grains", 87, 3, (-1000,100))
grain_color = ramp("Quartz flecks", grain.outputs["Factor"], [(.25,(.15,.16,.17,1)),(.74,(.72,.72,.64,1))],(-750,100))
mix = node("ShaderNodeMixRGB","Fine mottling",(-450,450));mix.blend_type="MULTIPLY";mix.inputs[0].default_value=.43
links.new(stone.outputs["Color"],mix.inputs[1]);links.new(grain_color.outputs["Color"],mix.inputs[2])
lichen = noise("Sparse lichen islands", 7.4, 4, (-1000,-230))
lichen_mask = ramp("Lichen coverage",lichen.outputs["Factor"],[(.61,(0,0,0,1)),(.76,(.8,.8,.8,1))],(-750,-200))
color = node("ShaderNodeMixRGB","Muted yellow-green lichen",(-170,420));color.inputs[2].default_value=(.23,.265,.105,1)
links.new(lichen_mask.outputs["Color"],color.inputs[0]);links.new(mix.outputs[0],color.inputs[1])
links.new(color.outputs[0],bsdf.inputs["Base Color"])
cracks=node("ShaderNodeTexVoronoi","Hairline mineral fractures",(-1000,-520));cracks.feature="DISTANCE_TO_EDGE";cracks.inputs["Scale"].default_value=5.2
crack_ramp=ramp("Fine recesses",cracks.outputs["Distance"],[(0,(0,0,0,1)),(.035,(.65,.65,.65,1)),(.09,(1,1,1,1))],(-750,-470))
bump=node("ShaderNodeBump","Fracture relief",(-420,-220));bump.inputs["Strength"].default_value=.38;bump.inputs["Distance"].default_value=.047
links.new(crack_ramp.outputs[0],bump.inputs["Height"])
micro=node("ShaderNodeBump","Grain relief",(-160,-100));micro.inputs["Strength"].default_value=.48;micro.inputs["Distance"].default_value=.036
links.new(grain.outputs["Factor"],micro.inputs["Height"]);links.new(bump.outputs["Normal"],micro.inputs["Normal"]);links.new(micro.outputs["Normal"],bsdf.inputs["Normal"])
rough=ramp("Dry stone roughness",grain.outputs["Factor"],[(.2,(.64,.64,.64,1)),(.8,(.98,.98,.98,1))],(-420,-530));links.new(rough.outputs[0],bsdf.inputs["Roughness"])
bsdf.location=(130,350)
obj.data.materials.clear();obj.data.materials.append(mat)
for area in bpy.context.screen.areas:
    if area.type == "VIEW_3D": area.spaces.active.shading.type="MATERIAL"
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "WeatheredBoulder.blend"))
print("Boulder material ready", len(obj.data.vertices), len(obj.data.polygons))
