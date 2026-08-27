"""Blender headless: find low-height (hip-level or lower) vertices that carry
significant weight on the left-arm chain - the signature of a wide patch of
coat/hip geometry bound to the arm via heat diffusion from a touching hand,
rather than just a few edge vertices.
Usage: blender --background --python-exit-code 1 --python tools/find_arm_coat.py -- <file.glb>
"""
import sys

import bpy

path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)

mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
group_names = {g.index: g.name for g in mesh_obj.vertex_groups}

ARM_L = {"Shoulder.L", "UpperArm.L", "LowerArm.L", "Hand.L"}

verts = mesh_obj.data.vertices
zs = sorted(v.co.z for v in verts)
hip_z = zs[int(len(zs) * 0.45)]  # roughly hip height and below

flagged = []
for v in verts:
    if v.co.z > hip_z:
        continue
    for g in v.groups:
        name = group_names.get(g.group)
        if name in ARM_L and g.weight >= 0.3:
            flagged.append((v.index, v.co.z, name, g.weight))
            break

print(f"{len(flagged)} vertices at/below z={hip_z:.3f} with >=0.3 weight on left-arm-chain bones")
from collections import Counter
by_bone = Counter(f[2] for f in flagged)
for bone, n in by_bone.most_common():
    print(f"  {bone}: {n}")
zs_flagged = sorted(f[1] for f in flagged)
if zs_flagged:
    print(f"z range of flagged verts: {zs_flagged[0]:.3f} to {zs_flagged[-1]:.3f}")
