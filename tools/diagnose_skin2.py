"""Blender headless: find vertices whose two heaviest bone weights belong to
anatomically unrelated bones (not parent/child/sibling in the rig). A vertex
split between two independently-moving joints stretches between them during
animation - the classic cause of a "flying fin" on otherwise-correct rigs.

Usage: blender --background --python-exit-code 1 --python tools/diagnose_skin2.py -- <file.glb>
"""
import sys
from collections import defaultdict

import bpy

path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)

arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")

parent = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}


def related(a, b):
    if a == b:
        return True
    if parent.get(a) == b or parent.get(b) == a:
        return True
    if parent.get(a) is not None and parent.get(a) == parent.get(b):
        return True  # siblings
    return False


group_names = {g.index: g.name for g in mesh_obj.vertex_groups}
bad = []
for i, v in enumerate(mesh_obj.data.vertices):
    groups = sorted(v.groups, key=lambda g: -g.weight)
    named = [(group_names.get(g.group), g.weight) for g in groups if group_names.get(g.group)]
    if len(named) < 2:
        continue
    (b1, w1), (b2, w2) = named[0], named[1]
    if w2 < 0.15:  # second bone barely contributes, not a real split
        continue
    if not related(b1, b2):
        bad.append((i, b1, w1, b2, w2))

print(f"{len(bad)} vertices split across unrelated bones (2nd weight >= 0.15)")
by_pair = defaultdict(int)
for i, b1, w1, b2, w2 in bad:
    pair = tuple(sorted((b1, b2)))
    by_pair[pair] += 1
for pair, n in sorted(by_pair.items(), key=lambda kv: -kv[1]):
    print(f"  {pair[0]:14s} <-> {pair[1]:14s}: {n} vertices")

if bad:
    print("\nsample vertex indices for the top pair (for a Blender vertex-group-select check):")
    top_pair = max(by_pair.items(), key=lambda kv: kv[1])[0]
    sample = [i for i, b1, w1, b2, w2 in bad if tuple(sorted((b1, b2))) == top_pair][:15]
    print(" ", sample)
