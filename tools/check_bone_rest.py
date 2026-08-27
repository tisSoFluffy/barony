"""Blender headless: print rest head/tail/length for named bones.
Usage: blender --background --python-exit-code 1 --python tools/check_bone_rest.py -- <file.glb> <bone1,bone2,...>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
path, names = argv[0], argv[1].split(",")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")

for name in names:
    b = arm.data.bones[name]
    head = arm.matrix_world @ b.head_local
    tail = arm.matrix_world @ b.tail_local
    length = (tail - head).length
    print(f"{name:12s} head={tuple(round(c,4) for c in head)} tail={tuple(round(c,4) for c in tail)} "
          f"length={length:.4f} roll={b.matrix_local.to_euler().z:.4f}")
