"""Blender headless: find vertices whose dominant bone weight is anatomically
implausible - i.e. the vertex sits far from that bone's rest position relative
to the character's overall size. These are the classic cause of a "stretching
fin": bone-heat weighting assigned a disconnected or thin piece of geometry to
whatever bone diffused heat into it first, not the bone actually nearest it.

Usage: blender --background --python-exit-code 1 --python tools/diagnose_skin.py -- <file.glb>
"""
import sys
from collections import defaultdict

import bpy

path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)

arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")

bone_head_world = {b.name: arm.matrix_world @ b.head_local for b in arm.data.bones}

# character scale, for judging what counts as "far"
verts_world = [mesh_obj.matrix_world @ v.co for v in mesh_obj.data.vertices]
zs = [v.z for v in verts_world]
height = max(zs) - min(zs)

per_bone_dists = defaultdict(list)
per_bone_verts = defaultdict(list)
group_names = {g.index: g.name for g in mesh_obj.vertex_groups}

for i, v in enumerate(mesh_obj.data.vertices):
    if not v.groups:
        continue
    dom = max(v.groups, key=lambda g: g.weight)
    bname = group_names.get(dom.group)
    if bname is None or bname not in bone_head_world:
        continue
    dist = (verts_world[i] - bone_head_world[bname]).length
    per_bone_dists[bname].append(dist)
    per_bone_verts[bname].append(i)

print(f"character height: {height:.3f}")
print(f"{'bone':16s} {'n_verts':>8s} {'mean_d':>8s} {'max_d':>8s}  (distances as fraction of height)")
for bname, dists in sorted(per_bone_dists.items(), key=lambda kv: -max(kv[1])):
    mean_d = sum(dists) / len(dists)
    max_d = max(dists)
    print(f"{bname:16s} {len(dists):8d} {mean_d/height:8.3f} {max_d/height:8.3f}")

# flag the worst offenders concretely: vertices further from their dominant
# bone's rest position than half the character's height
threshold = 0.5 * height
flagged = [(b, i, d) for b, dists in per_bone_dists.items()
           for i, d in zip(per_bone_verts[b], dists) if d > threshold]
print(f"\n{len(flagged)} vertices further than {threshold:.3f} (0.5x height) from their dominant bone's rest head")
by_bone = defaultdict(int)
for b, i, d in flagged:
    by_bone[b] += 1
for b, n in sorted(by_bone.items(), key=lambda kv: -kv[1]):
    print(f"  {b}: {n} vertices")
