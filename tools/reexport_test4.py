"""Blender headless: no BVH at all - just a synthetic, genuinely-varying
rotation (identity -> 60deg on UpperArm.R) across several frames, exported
with the same flags as retarget_kimodo.py, to see if real value variation
(vs. my no-op tests' 2 identical frames) alone triggers the artifact.
Usage: blender --background --python-exit-code 1 --python tools/reexport_test4.py -- <target.glb> <out.glb>
"""
import sys

import bpy
from mathutils import Quaternion

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")

for pb in arm.pose.bones:
    pb.rotation_mode = "QUATERNION"

for f in range(1, 11):
    bpy.context.scene.frame_set(f)
    arm.keyframe_insert(data_path="location", frame=f)
    angle = (f - 1) / 9.0 * 1.0472  # 0 -> 60deg
    for pb in arm.pose.bones:
        if pb.name == "UpperArm.R":
            pb.rotation_quaternion = Quaternion((1, 0, 0), angle)
        else:
            pb.rotation_quaternion = Quaternion((1, 0, 0, 0))
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
