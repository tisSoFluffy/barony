"""Blender headless: report dominant vertex-group weights for the lowest
(hem-most) vertices in a mesh's rest pose - i.e. whatever's at the bottom of
a coat/skirt/cloak.
Usage: blender --background --python-exit-code 1 --python tools/find_hem.py -- <file.glb>
"""
import sys
from collections import Counter

import bpy

path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)

mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
group_names = {g.index: g.name for g in mesh_obj.vertex_groups}

verts = mesh_obj.data.vertices
zs = sorted(v.co.z for v in verts)
n = len(zs)
lo, hi = zs[int(n * 0.35)], zs[int(n * 0.60)]  # a mid-body band: hip/thigh height

dom_counts = Counter()
for v in verts:
    if not (lo <= v.co.z <= hi):
        continue
    if not v.groups:
        continue
    dom = max(v.groups, key=lambda g: g.weight)
    dom_counts[group_names.get(dom.group, "?")] += 1

print(f"dominant bone for vertices with z in [{lo:.3f}, {hi:.3f}] (hip/thigh band):")
for name, n in dom_counts.most_common():
    print(f"  {name:14s} {n}")
