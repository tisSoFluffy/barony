"""Blender headless: for vertices dominantly weighted to an arm-family bone,
check whether a hip/leg-family bone's rest SEGMENT (head-to-tail line, not
just head point) is actually much closer - the signature of bone-heat
favoring a touching-but-wrong bone over the anatomically correct one.

Usage: blender --background --python-exit-code 1 --python tools/check_dominant.py -- <file.glb>
"""
import sys

import bpy
from mathutils.geometry import intersect_point_line

path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)

arm_obj = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
group_names = {g.index: g.name for g in mesh_obj.vertex_groups}

ARM_FAMILY = {"UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R", "Hand.L", "Hand.R"}
LEG_FAMILY = {"Hips", "UpperLeg.L", "UpperLeg.R", "LowerLeg.L", "LowerLeg.R"}

bones = {b.name: b for b in arm_obj.data.bones}


def seg_dist(p, bname):
    b = bones[bname]
    head, tail = arm_obj.matrix_world @ b.head_local, arm_obj.matrix_world @ b.tail_local
    _, factor = intersect_point_line(p, head, tail)
    factor = max(0.0, min(1.0, factor))
    closest = head + (tail - head) * factor
    return (p - closest).length


flagged = []
for v in mesh_obj.data.vertices:
    if not v.groups:
        continue
    dom = max(v.groups, key=lambda g: g.weight)
    dom_name = group_names.get(dom.group)
    if dom_name not in ARM_FAMILY or dom.weight < 0.5:
        continue
    world_p = mesh_obj.matrix_world @ v.co
    d_arm = seg_dist(world_p, dom_name)
    d_leg_best = min((seg_dist(world_p, lb), lb) for lb in LEG_FAMILY)
    if d_leg_best[0] < d_arm * 0.7:  # meaningfully closer to a leg/hip bone
        flagged.append((v.index, dom_name, dom.weight, d_arm, d_leg_best[1], d_leg_best[0]))

print(f"{len(flagged)} vertices dominantly (>=0.5) arm-weighted but geometrically closer to a leg/hip bone")
from collections import Counter
by_pair = Counter((f[1], f[4]) for f in flagged)
for (arm_b, leg_b), n in by_pair.most_common():
    print(f"  {arm_b:12s} -> should favor {leg_b:12s}: {n} vertices")
print("\nsample:")
for row in flagged[:10]:
    print(f"  v{row[0]:5d}  dom={row[1]}(w={row[2]:.2f}, d={row[3]:.3f})  closer_leg={row[4]}(d={row[5]:.3f})")
