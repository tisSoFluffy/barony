"""Blender headless: find which vertices move the most between rest and a
given posed frame, and report their vertex-group weights. Ground-truth version
of "what's causing this stretch" - compares actual deformed positions rather
than reasoning about weights indirectly.

Usage: blender --background --python-exit-code 1 --python tools/diagnose_stretch.py -- <animated.glb> <frame>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
path, frame = argv[0], int(argv[1])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)

mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
depsgraph = bpy.context.evaluated_depsgraph_get()


def deformed_positions(f):
    # Local (object) space only - deliberately NOT matrix_world, so normal
    # root-motion translation (the character walking forward) doesn't get
    # mistaken for mesh-shape stretching.
    bpy.context.scene.frame_set(f)
    depsgraph.update()
    eval_obj = mesh_obj.evaluated_get(depsgraph)
    mesh = eval_obj.to_mesh()
    positions = [v.co.copy() for v in mesh.vertices]
    eval_obj.to_mesh_clear()
    return positions

rest = deformed_positions(1)
posed = deformed_positions(frame)

displacement = [(posed[i] - rest[i]).length for i in range(len(rest))]
order = sorted(range(len(rest)), key=lambda i: -displacement[i])

group_names = {g.index: g.name for g in mesh_obj.vertex_groups}
print(f"top 25 vertices by displacement between frame 1 and frame {frame}:")
for i in order[:25]:
    weights = sorted(mesh_obj.data.vertices[i].groups, key=lambda g: -g.weight)
    wstr = ", ".join(f"{group_names.get(g.group,'?')}={g.weight:.2f}" for g in weights[:3])
    print(f"  v{i:5d}  disp={displacement[i]:.3f}  rest={tuple(round(c,3) for c in rest[i])}  [{wstr}]")
