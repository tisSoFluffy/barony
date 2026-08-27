"""Blender headless: find mesh edges that stretch the most (length ratio)
between rest and a posed frame - the real signature of a stretched panel, as
opposed to raw vertex displacement which just reflects normal joint motion.

Usage: blender --background --python-exit-code 1 --python tools/diagnose_edges.py -- <animated.glb> <frame>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
path, frame = argv[0], int(argv[1])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)

mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
depsgraph = bpy.context.evaluated_depsgraph_get()

edges = [(e.vertices[0], e.vertices[1]) for e in mesh_obj.data.edges]


def deformed_positions(f):
    bpy.context.scene.frame_set(f)
    depsgraph.update()
    eval_obj = mesh_obj.evaluated_get(depsgraph)
    mesh = eval_obj.to_mesh()
    positions = [v.co.copy() for v in mesh.vertices]
    eval_obj.to_mesh_clear()
    return positions

rest = deformed_positions(1)
posed = deformed_positions(frame)

group_names = {g.index: g.name for g in mesh_obj.vertex_groups}


def weight_str(i):
    weights = sorted(mesh_obj.data.vertices[i].groups, key=lambda g: -g.weight)
    return ", ".join(f"{group_names.get(g.group,'?')}={g.weight:.2f}" for g in weights[:2])


ratios = []
for a, b in edges:
    rest_len = (rest[a] - rest[b]).length
    if rest_len < 1e-6:
        continue
    posed_len = (posed[a] - posed[b]).length
    ratios.append((posed_len / rest_len, a, b, rest_len, posed_len))

ratios.sort(key=lambda t: -t[0])
print(f"top 20 most-stretched edges, frame 1 -> {frame}:")
for ratio, a, b, rl, pl in ratios[:20]:
    print(f"  ratio={ratio:6.2f}x  rest_len={rl:.4f} -> posed_len={pl:.4f}  "
          f"v{a}[{weight_str(a)}]  <->  v{b}[{weight_str(b)}]")
