"""Blender headless: minimal reproduction - import a glb and immediately
re-export it with zero pose changes, to isolate whether Blender's own
import/export round-trip corrupts this mesh.
Usage: blender --background --python-exit-code 1 --python tools/reexport_test.py -- <in.glb> <out.glb>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=dst,
    use_selection=True,
    export_format="GLB",
    export_animations=False,
    export_skins=True,
    export_yup=True,
)
print(f"wrote {dst}")
