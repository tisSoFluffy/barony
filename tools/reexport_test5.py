"""Blender headless: read all pose-bone rotations at a given frame from an
existing (buggy) animated glb, then apply that EXACT combined pose directly
to a fresh import of the pristine rig via a plain 2-frame animation (identity
-> that pose), exported the same way. Isolates whether the full real-motion
combined pose is what's needed to trigger the artifact, independent of the
BVH-import/retarget pipeline itself.
Usage: blender --background --python-exit-code 1 --python tools/reexport_test5.py -- \
    <buggy.glb> <frame> <pristine.glb> <out.glb>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
buggy_path, frame, pristine_path, dst = argv[0], int(argv[1]), argv[2], argv[3]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=buggy_path)
buggy_arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
bpy.context.scene.frame_set(frame)
bpy.context.view_layer.update()
target_pose = {pb.name: pb.rotation_quaternion.copy() for pb in buggy_arm.pose.bones}
target_loc = buggy_arm.location.copy()
print("captured pose:", {k: tuple(round(c, 3) for c in v) for k, v in target_pose.items()})

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=pristine_path)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")

for pb in arm.pose.bones:
    pb.rotation_mode = "QUATERNION"

for f, is_target in ((1, False), (2, True)):
    bpy.context.scene.frame_set(f)
    arm.location = target_loc if is_target else (0, 0, 0)
    arm.keyframe_insert(data_path="location", frame=f)
    for pb in arm.pose.bones:
        pb.rotation_quaternion = target_pose.get(pb.name, (1, 0, 0, 0)) if is_target else (1, 0, 0, 0)
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
