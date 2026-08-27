"""Blender headless: verify an exported glb's armature + animation.
Usage: blender --background --python tools/dump_anim.py -- <file.glb>
"""
import sys

import bpy

path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)

arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
print(f"armature: {arm.name}, {len(arm.data.bones)} bones")
print(f"actions in file: {[a.name for a in bpy.data.actions]}")

action = arm.animation_data.action
print(f"active action: {action.name}, frame_range={action.frame_range[:]}")

if hasattr(action, "fcurves"):
    fcurves = list(action.fcurves)
else:
    fcurves = []
    for layer in action.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                fcurves.extend(cb.fcurves)
print(f"fcurve count: {len(fcurves)}")
paths = sorted({fc.data_path for fc in fcurves})
for p in paths:
    print(" ", p)

scene = bpy.context.scene
f0, f1 = int(action.frame_range[0]), int(action.frame_range[1])
print(f"\nsampling Chest and Hips rotation + armature location across frames {f0}..{f1}:")
for f in range(f0, f1 + 1, max(1, (f1 - f0) // 8)):
    scene.frame_set(f)
    chest = arm.pose.bones["Chest"].rotation_quaternion
    hips = arm.pose.bones["Hips"].rotation_quaternion
    print(f"  f={f:4d}  loc={tuple(round(x,3) for x in arm.location)}  "
          f"Hips_q={tuple(round(x,3) for x in hips)}  Chest_q={tuple(round(x,3) for x in chest)}")
