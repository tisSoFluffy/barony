"""Blender-side decimation that KEEPS the source UVs and texture.

fast_simplification + a fresh xatlas unwrap shatters a TRELLIS surface-net mesh
(~11k disconnected shells) into ~1500 UV charts, and the re-bake across all
those seams renders in-engine as a white crackle over every surface. Blender's
collapse decimator carries the original per-vertex UVs through, so the mesh
keeps pointing at TRELLIS's own coherent atlas and nothing is re-baked.

    blender -b -P tools/blender_decimate.py -- <src.glb> <out.glb> <target_faces>
"""
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, out, target = argv[0], argv[1], int(argv[2])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active

# Weld the coincident shell fragments so the collapse has real edges to work
# along, then drop degenerate slivers.
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0008)
bpy.ops.mesh.dissolve_degenerate()
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")

before = len(obj.data.polygons)
if before > target:
    m = obj.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = max(target / before, 0.01)
    m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=m.name)

for p in obj.data.polygons:
    p.use_smooth = True

bpy.ops.export_scene.gltf(
    filepath=out,
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_yup=True,
)
print("DECIMATE %d -> %d tris" % (before, len(obj.data.polygons)))
