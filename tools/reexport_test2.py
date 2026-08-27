"""Blender headless: reproduce retarget_kimodo.py's export path with a no-op
(identity) animation - one keyframe, zero rotation, zero location - to see if
the export SETTINGS themselves (force_sampling + animated object location)
corrupt this mesh regardless of what the animated values actually are.
Usage: blender --background --python-exit-code 1 --python tools/reexport_test2.py -- <in.glb> <out.glb>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")

for f in (1, 2):
    bpy.context.scene.frame_set(f)
    arm.keyframe_insert(data_path="location", frame=f)
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert(data_path="rotation_quaternion", frame=f)

arm.animation_data.action.name = "walk"

bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
for child in arm.children:
    child.select_set(True)
bpy.context.view_layer.objects.active = arm

bpy.ops.export_scene.gltf(
    filepath=dst,
    use_selection=True,
    export_format="GLB",
    export_animations=True,
    export_animation_mode="ACTIVE_ACTIONS",
    export_frame_range=False,
    export_force_sampling=True,
    export_skins=True,
    export_yup=True,
)
print(f"wrote {dst}")
