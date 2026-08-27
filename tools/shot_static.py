"""Blender headless: render a single front-view still of a (possibly unrigged) glb.
Usage: blender --background --python tools/shot_static.py -- <file.glb> <out.png>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
path, out_png = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
minv = [min(v[i] for o in meshes for v in [o.matrix_world @ c.co for c in o.data.vertices]) for i in range(3)]
maxv = [max(v[i] for o in meshes for v in [o.matrix_world @ c.co for c in o.data.vertices]) for i in range(3)]
center = [(minv[i] + maxv[i]) / 2 for i in range(3)]
size = max(maxv[i] - minv[i] for i in range(3))

key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", type="SUN"))
key.data.energy = 4.0
key.rotation_euler = (0.9, 0.0, -2.4)
bpy.context.scene.collection.objects.link(key)
fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", type="SUN"))
fill.data.energy = 1.5
fill.rotation_euler = (1.2, 0.0, 1.0)
bpy.context.scene.collection.objects.link(fill)

world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.6, 0.62, 1)
bpy.context.scene.world = world

cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
bpy.context.scene.collection.objects.link(cam)
bpy.context.scene.camera = cam
dist = size * 1.6
import mathutils
cam.location = mathutils.Vector(center) + mathutils.Vector((0, -dist, size * 0.15))
direction = mathutils.Vector(center) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

scene = bpy.context.scene
scene.render.resolution_x = 400
scene.render.resolution_y = 500
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
scene.view_settings.view_transform = "Standard"
scene.render.filepath = out_png
bpy.ops.render.render(write_still=True)
print(f"wrote {out_png}")
