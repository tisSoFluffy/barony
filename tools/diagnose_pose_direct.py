"""Blender headless: apply a captured pose directly to the pristine rig (no
export round-trip) and compare deformed local vertex positions against
identity rest, in the same session. Definitive version of diagnose_stretch.py
now that we've confirmed this is a real posing effect.
Usage: blender --background --python-exit-code 1 --python tools/diagnose_pose_direct.py -- \
    <buggy.glb> <frame> <pristine.glb>
"""
import sys

import bpy
from mathutils import Quaternion

argv = sys.argv[sys.argv.index("--") + 1:]
buggy_path, frame, pristine_path = argv[0], int(argv[1]), argv[2]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=buggy_path)
buggy_arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
bpy.context.scene.frame_set(frame)
bpy.context.view_layer.update()
target_pose = {pb.name: pb.rotation_quaternion.copy() for pb in buggy_arm.pose.bones}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=pristine_path)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
for pb in arm.pose.bones:
    pb.rotation_mode = "QUATERNION"

depsgraph = bpy.context.evaluated_depsgraph_get()


def deformed_local():
    depsgraph.update()
    eval_obj = mesh_obj.evaluated_get(depsgraph)
    mesh = eval_obj.to_mesh()
    positions = [v.co.copy() for v in mesh.vertices]
    eval_obj.to_mesh_clear()
    return positions


for pb in arm.pose.bones:
    pb.rotation_quaternion = Quaternion((1, 0, 0, 0))
bpy.context.view_layer.update()
rest = deformed_local()

for pb in arm.pose.bones:
    if pb.name in target_pose:
        pb.rotation_quaternion = target_pose[pb.name]
bpy.context.view_layer.update()
posed = deformed_local()

group_names = {g.index: g.name for g in mesh_obj.vertex_groups}
disp = [(posed[i] - rest[i]).length for i in range(len(rest))]
order = sorted(range(len(rest)), key=lambda i: -disp[i])

print("top 20 vertices by local displacement (rest -> posed, same session, no export):")
for i in order[:20]:
    weights = sorted(mesh_obj.data.vertices[i].groups, key=lambda g: -g.weight)
    wstr = ", ".join(f"{group_names.get(g.group,'?')}={g.weight:.2f}" for g in weights[:3])
    print(f"  v{i:5d}  disp={disp[i]:.3f}  rest={tuple(round(c,3) for c in rest[i])}  [{wstr}]")
