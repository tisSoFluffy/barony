"""Blender headless: render a few frames of an animated glb for a visual check.
Usage: blender --background --python tools/shot_anim.py -- <file.glb> <out_dir>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
path, out_dir = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)

arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
action = arm.animation_data.action
f0, f1 = int(action.frame_range[0]), int(action.frame_range[1])

key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", type="SUN"))
key.data.energy = 4.0
key.rotation_euler = (0.9, 0.0, -2.4)  # roughly over the camera's shoulder
bpy.context.scene.collection.objects.link(key)

fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", type="SUN"))
fill.data.energy = 1.5
fill.rotation_euler = (1.2, 0.0, 1.0)
bpy.context.scene.collection.objects.link(fill)

world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.18, 0.19, 0.22, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
bpy.context.scene.world = world

cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
bpy.context.scene.collection.objects.link(cam)
bpy.context.scene.camera = cam

scene = bpy.context.scene
scene.render.resolution_x = 480
scene.render.resolution_y = 640
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
scene.view_settings.view_transform = "Standard"

n = 6
for i in range(n):
    f = f0 + round((f1 - f0) * i / (n - 1))
    scene.frame_set(f)
    # camera follows the armature's root motion so a running/leaping clip stays framed
    focus = arm.matrix_world.translation.copy()
    focus.z += 0.9
    cam.location = focus + type(focus)((3.0, -4.0, 0.7))
    direction = focus - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{out_dir}/frame_{i}_{f}.png"
    bpy.ops.render.render(write_still=True)
    print(f"rendered frame {f} -> {scene.render.filepath}")
