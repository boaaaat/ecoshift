"""Bake and export the selected original canopy for Roblox; execute inside Blender."""
import bpy, json, traceback
from pathlib import Path

ROOT = Path(__file__).resolve().parent
def publish():
    status = ROOT / "export-status.json"
    try:
        obj = bpy.data.objects["SmoothCanopy"]
        for other in bpy.context.selected_objects: other.select_set(False)
        obj.hide_set(False); obj.select_set(True); bpy.context.view_layer.objects.active = obj
        # One authored mesh per project; the former block source has its own saved file.
        previous = bpy.data.objects.get("Expedition_ChiseledRock")
        if previous: bpy.data.objects.remove(previous, do_unlink=True)
        scene = bpy.context.scene
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 16
        scene.render.bake.margin = 12
        scene.render.bake.use_selected_to_active = False
        mat = obj.active_material
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
        output = next(n for n in nodes if n.type == "OUTPUT_MATERIAL")
        base_source = bsdf.inputs["Base Color"].links[0].from_socket
        emission = nodes.new("ShaderNodeEmission")
        links.new(base_source, emission.inputs["Color"])
        target = nodes.new("ShaderNodeTexImage")
        maps = {}
        for label, mode in [("BaseColor","EMIT"),("Normal","NORMAL"),("Roughness","ROUGHNESS")]:
            status.write_text(json.dumps({"stage":"baking "+label}))
            image = bpy.data.images.new("Canopy_"+label, width=1024, height=1024, alpha=False, is_data=label!="BaseColor")
            image.filepath_raw = str(ROOT / ("Canopy_"+label+".png")); image.file_format="PNG"
            target.image=image
            for n in nodes: n.select=False
            target.select=True;nodes.active=target
            links.new(emission.outputs[0] if mode=="EMIT" else bsdf.outputs[0], output.inputs["Surface"])
            bpy.ops.object.bake(type=mode)
            image.save();maps[label]=image
        links.new(bsdf.outputs[0], output.inputs["Surface"])
        nodes.remove(target);nodes.remove(emission)
        baked=bpy.data.materials.new("SmoothCanopy_PBR");baked.use_nodes=True
        bn,bl=baked.node_tree.nodes,baked.node_tree.links
        shader=next(n for n in bn if n.type=="BSDF_PRINCIPLED")
        for index,(label,img) in enumerate(maps.items()):
            tex=bn.new("ShaderNodeTexImage");tex.image=img;tex.label=label;tex.location=(-650,index*-270)
            if label=="Normal":
                normal=bn.new("ShaderNodeNormalMap");normal.location=(-270,-250)
                bl.new(tex.outputs["Color"],normal.inputs["Color"]);bl.new(normal.outputs["Normal"],shader.inputs["Normal"])
            else: bl.new(tex.outputs["Color"],shader.inputs["Base Color" if label=="BaseColor" else "Roughness"])
            img.pack()
        obj.data.materials.clear();obj.data.materials.append(baked)
        scene.render.engine="BLENDER_EEVEE"
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "SmoothCanopy.blend"))
        status.write_text(json.dumps({"stage":"exporting"}))
        bpy.ops.export_scene.gltf(filepath=str(ROOT / "SmoothCanopy.glb"), use_selection=True)
        bpy.ops.export_scene.fbx(filepath=str(ROOT / "SmoothCanopy.fbx"), use_selection=True, bake_anim=False)
        obj.data.calc_loop_triangles()
        status.write_text(json.dumps({"stage":"complete","vertices":len(obj.data.vertices),"triangles":len(obj.data.loop_triangles),"dimensions":list(obj.dimensions)}))
    except Exception:
        status.write_text(json.dumps({"stage":"error","details":traceback.format_exc()}))
    return None
bpy.app.timers.register(publish,first_interval=.2)

