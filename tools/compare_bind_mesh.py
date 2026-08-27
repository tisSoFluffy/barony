"""Blender headless: compare raw (undeformed/bind) mesh vertex positions
between two glb files, by vertex index.
Usage: blender --background --python-exit-code 1 --python tools/compare_bind_mesh.py -- <a.glb> <b.glb>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
a_path, b_path = argv[0], argv[1]


def load_verts(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    return [v.co.copy() for v in mesh_obj.data.vertices]


a = load_verts(a_path)
b = load_verts(b_path)
print(f"{a_path}: {len(a)} verts")
print(f"{b_path}: {len(b)} verts")

if len(a) != len(b):
    print("VERTEX COUNT DIFFERS - not directly comparable by index")
else:
    diffs = [(i, (a[i] - b[i]).length) for i in range(len(a))]
    diffs.sort(key=lambda t: -t[1])
    print("top 15 by bind-position difference:")
    for i, d in diffs[:15]:
        print(f"  v{i:5d}  diff={d:.4f}  a={tuple(round(c,3) for c in a[i])}  b={tuple(round(c,3) for c in b[i])}")
    print(f"max diff: {diffs[0][1]:.4f}  mean diff: {sum(d for _,d in diffs)/len(diffs):.5f}")
