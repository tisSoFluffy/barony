"""Blender headless: apply ONLY Shoulder.L's captured rotation to the pristine
rig (single session, no export) and find the most-displaced vertices with
full weight breakdown.
Usage: blender --background --python-exit-code 1 --python tools/diagnose_shoulder_only.py -- \
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
shoulder_q = buggy_arm.pose.bones["Shoulder.L"].rotation_quaternion.copy()
print("Shoulder.L captured quat:", tuple(round(c, 4) for c in shoulder_q), "angle:",
      round(shoulder_q.angle * 57.2958, 1), "deg")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=pristine_path)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
mesh_obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
for pb in arm.pose.bones:
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = Quaternion((1, 0, 0, 0))
bpy.context.scene.frame_set(1)

depsgraph = bpy.context.evaluated_depsgraph_get()


def deformed_local():
    depsgraph.update()
    eval_obj = mesh_obj.evaluated_get(depsgraph)
    mesh = eval_obj.to_mesh()
    positions = [v.co.copy() for v in mesh.vertices]
    eval_obj.to_mesh_clear()
    return positions


rest = deformed_local()
arm.pose.bones["Shoulder.L"].rotation_quaternion = shoulder_q
bpy.context.view_layer.update()
posed = deformed_local()

group_names = {g.index: g.name for g in mesh_obj.vertex_groups}
disp = [(posed[i] - rest[i]).length for i in range(len(rest))]
order = sorted(range(len(rest)), key=lambda i: -disp[i])

print("\ntop 15 vertices by displacement from Shoulder.L rotation alone:")
for i in order[:15]:
    weights = sorted(mesh_obj.data.vertices[i].groups, key=lambda g: -g.weight)
    wstr = ", ".join(f"{group_names.get(g.group,'?')}={g.weight:.3f}" for g in weights)
    print(f"  v{i:5d}  disp={disp[i]:.3f}  rest={tuple(round(c,3) for c in rest[i])}  "
          f"posed={tuple(round(c,3) for c in posed[i])}  [{wstr}]")
