"""Blender headless: print bone names/hierarchy of an imported glTF/BVH.
Usage: blender --background --python tools/dump_bones.py -- <file.glb|file.bvh>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
path = argv[0]

bpy.ops.wm.read_factory_settings(use_empty=True)

if path.lower().endswith(".bvh"):
    bpy.ops.import_anim.bvh(filepath=path)
else:
    bpy.ops.import_scene.gltf(filepath=path)

arm = None
for obj in bpy.context.scene.objects:
    if obj.type == "ARMATURE":
        arm = obj
        break

if arm is None:
    print("NO ARMATURE FOUND")
    sys.exit(1)

print(f"ARMATURE: {arm.name}, {len(arm.data.bones)} bones")
for b in arm.data.bones:
    parent = b.parent.name if b.parent else None
    print(f"  {b.name!r:24s} parent={parent!r}")
