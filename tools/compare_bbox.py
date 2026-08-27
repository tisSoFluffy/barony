"""Blender headless: compare mesh bounding box (raw bind vertices, no pose)
between two glb files.
Usage: blender --background --python-exit-code 1 --python tools/compare_bbox.py -- <a.glb> <b.glb>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]


def bbox(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    verts = mesh_obj.data.vertices
    xs = [v.co.x for v in verts]
    ys = [v.co.y for v in verts]
    zs = [v.co.z for v in verts]
    return (min(xs), max(xs)), (min(ys), max(ys)), (min(zs), max(zs)), len(verts)


for path in argv:
    (x0, x1), (y0, y1), (z0, z1), n = bbox(path)
    print(f"{path}: verts={n}  x=({x0:.3f},{x1:.3f}) span={x1-x0:.3f}  "
          f"y=({y0:.3f},{y1:.3f}) span={y1-y0:.3f}  z=({z0:.3f},{z1:.3f}) span={z1-z0:.3f}")
