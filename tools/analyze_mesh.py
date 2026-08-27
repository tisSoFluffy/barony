"""Blender headless: report mesh stats (verts/tris/bbox) and texture resolution.
Usage: blender --background --python tools/analyze_mesh.py -- <file.glb>
"""
import sys

import bpy

path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
print(f"mesh objects: {len(meshes)}")
total_tris = 0
for o in meshes:
    m = o.data
    tris = sum(len(p.vertices) - 2 for p in m.polygons)
    total_tris += tris
    verts = [o.matrix_world @ v.co for v in m.vertices]
    xs = [v.x for v in verts]
    ys = [v.y for v in verts]
    zs = [v.z for v in verts]
    print(f"  {o.name}: verts={len(m.vertices)} tris={tris} "
          f"bbox_x=({min(xs):.3f},{max(xs):.3f}) bbox_y=({min(ys):.3f},{max(ys):.3f}) "
          f"bbox_z=({min(zs):.3f},{max(zs):.3f})")
    for slot in o.material_slots:
        mat = slot.material
        if mat and mat.use_nodes:
            for n in mat.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    print(f"    texture: {n.image.name} {n.image.size[0]}x{n.image.size[1]}")
print(f"TOTAL TRIS: {total_tris}")

# floor-plane check: Blender's glTF import lands Z-up, so Z is the true height
# axis here. What fraction of tris lie in a thin slab at the mesh's own minimum Z?
all_verts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
min_z = min(v.z for v in all_verts)
max_z = max(v.z for v in all_verts)
height = max_z - min_z
slab = min_z + height * 0.03
in_slab = sum(1 for v in all_verts if v.z <= slab)
print(f"height(Z)={height:.3f}  verts within bottom 3% Z-band: {in_slab}/{len(all_verts)} "
      f"({100*in_slab/len(all_verts):.1f}%)")
