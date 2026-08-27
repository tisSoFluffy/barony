"""Blender headless: reexport_test2 but ALSO imports (and deletes) the source
BVH first, exactly like retarget_kimodo.py does, to test whether that import
leaves residual scene state (unit scale, etc.) that corrupts the later export.
Usage: blender --background --python-exit-code 1 --python tools/reexport_test3.py -- <bvh> <target.glb> <out.glb>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
bvh_path, src, dst = argv[0], argv[1], argv[2]

bpy.ops.wm.read_factory_settings(use_empty=True)

before = set(bpy.context.scene.objects)
bpy.ops.import_anim.bvh(filepath=bvh_path, global_scale=0.01, use_fps_scale=False)
src_arm = next(iter(set(bpy.context.scene.objects) - before))

bpy.ops.import_scene.gltf(filepath=src)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE" and o is not src_arm)

bpy.data.objects.remove(src_arm, do_unlink=True)

for f in (1, 2):
    bpy.context.scene.frame_set(f)
    arm.keyframe_insert(data_path="location", frame=f)
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert(data_path="rotation_quaternion", frame=f)

arm.animation_data.action.name = "walk"

bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
for child in arm.children:
    child.select_set(True)
bpy.context.view_layer.objects.active = arm

bpy.ops.export_scene.gltf(
    filepath=dst,
    use_selection=True,
    export_format="GLB",
    export_animations=True,
    export_animation_mode="ACTIVE_ACTIONS",
    export_frame_range=False,
    export_force_sampling=True,
    export_skins=True,
    export_yup=True,
)
print(f"wrote {dst}")
