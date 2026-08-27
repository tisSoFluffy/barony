"""Blender headless: import a pristine rig, set ONE bone to a captured
rotation (everything else literal identity, no frame_set tricks at all),
and render immediately. Cleanest possible single-bone isolation test.
Usage: blender --background --python-exit-code 1 --python tools/shoot_single_bone.py -- \
    <buggy.glb> <frame> <bone_name> <pristine.glb> <out.png>
"""
import sys

import bpy
import mathutils

argv = sys.argv[sys.argv.index("--") + 1:]
buggy_path, frame, bone_name, pristine_path, out_png = argv[0], int(argv[1]), argv[2], argv[3], argv[4]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=buggy_path)
buggy_arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
bpy.context.scene.frame_set(frame)
bpy.context.view_layer.update()
captured_q = buggy_arm.pose.bones[bone_name].rotation_quaternion.copy()
print(f"{bone_name} captured quat:", tuple(round(c, 4) for c in captured_q))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=pristine_path)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
for pb in arm.pose.bones:
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = mathutils.Quaternion((1, 0, 0, 0))
arm.pose.bones[bone_name].rotation_quaternion = captured_q
bpy.context.view_layer.update()

key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", type="SUN"))
key.data.energy = 5.0
key.rotation_euler = (0.9, 0.0, -2.4)
bpy.context.scene.collection.objects.link(key)
fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", type="SUN"))
fill.data.energy = 3.0
fill.rotation_euler = (1.2, 0.0, 1.0)
bpy.context.scene.collection.objects.link(fill)

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
