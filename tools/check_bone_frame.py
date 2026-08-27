"""Blender headless: print one pose bone's local rotation (matrix_basis quat)
at a given frame, for a BVH or glb.
Usage: blender --background --python-exit-code 1 --python tools/check_bone_frame.py -- <file> <bone> <frame>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
path, bone, frame = argv[0], argv[1], int(argv[2])

bpy.ops.wm.read_factory_settings(use_empty=True)
if path.lower().endswith(".bvh"):
    bpy.ops.import_anim.bvh(filepath=path, global_scale=0.01, use_fps_scale=False)
else:
    bpy.ops.import_scene.gltf(filepath=path)

arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
scene = bpy.context.scene
for f in range(max(1, frame - 2), frame + 3):
    scene.frame_set(f)
    pb = arm.pose.bones[bone]
    q = pb.matrix_basis.to_quaternion()
    angle_deg = q.angle * 57.29577951308232
    print(f"  f={f:4d}  quat=({q.w:.3f},{q.x:.3f},{q.y:.3f},{q.z:.3f})  angle={angle_deg:.1f}deg")
