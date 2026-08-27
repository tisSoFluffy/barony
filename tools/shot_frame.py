"""Blender headless: render one specific frame of an animated glb, well-lit
and framed close, for close inspection of a specific pose.
Usage: blender --background --python-exit-code 1 --python tools/shot_frame.py -- <file.glb> <frame> <out.png>
"""
import sys

import bpy
import mathutils

argv = sys.argv[sys.argv.index("--") + 1:]
path, frame, out_png = argv[0], int(argv[1]), argv[2]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)

arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
bpy.context.scene.frame_set(frame)
bpy.context.view_layer.update()

key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", type="SUN"))
key.data.energy = 5.0
key.rotation_euler = (0.9, 0.0, -2.4)
bpy.context.scene.collection.objects.link(key)
fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", type="SUN"))
fill.data.energy = 3.0
fill.rotation_euler = (1.2, 0.0, 1.0)
bpy.context.scene.collection.objects.link(fill)
back = bpy.data.objects.new("Back", bpy.data.lights.new("Back", type="SUN"))
back.data.energy = 2.0
back.rotation_euler = (2.0, 0.0, 0.5)
bpy.context.scene.collection.objects.link(back)

world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.75, 0.78, 1)
bpy.context.scene.world = world

focus = arm.matrix_world.translation.copy()
focus.z += 0.9
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
bpy.context.scene.collection.objects.link(cam)
bpy.context.scene.camera = cam
cam.location = focus + mathutils.Vector((2.2, -2.8, 0.6))
direction = focus - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

scene = bpy.context.scene
scene.render.resolution_x = 640
scene.render.resolution_y = 800
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
scene.view_settings.view_transform = "Standard"
scene.render.filepath = out_png
bpy.ops.render.render(write_still=True)
print(f"wrote {out_png}")
