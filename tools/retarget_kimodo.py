"""Blender headless: retarget a Kimodo SOMA BVH onto Kael's 19-bone rig.

Kael's rig (tools/autorig.py) has 5 spine/head bones where SOMA has 7
(Spine1+Spine2 -> Spine, Neck1+Neck2 -> Neck), and drops toes/fingers/eyes
entirely. Everything else is a 1:1 name mapping. Retargeting is done the
simple way: for each frame, read each SOMA bone's pose_bone.matrix_basis
(its rotation delta from that rig's own rest pose, in that bone's own local
space) and write the same delta onto Kael's matching bone. This assumes
both rigs' rest poses point each named limb in roughly the same anatomical
direction, which holds since both are upright humanoids with straight limbs
at rest. Composed pairs multiply parent-then-child (q_spine1 @ q_spine2).

Root motion: Kael's Hips is the literal armature root (no separate Root
node like the BVH has), so the source Hips bone's world-space head position
per frame becomes the target Armature object's location, scaled from the
BVH's centimeter convention back to Kael's meters.

Usage:
  blender --background --python tools/retarget_kimodo.py -- \
      --bvh out/demo_walk.bvh --target fractured-orbit/assets/models/player.glb \
      --out out/kael_walk.glb --anim-name walk
"""
import argparse
import sys

import bpy
from mathutils import Quaternion

MERGE_MAP = {
    "Hips": ("Hips",),
    "Spine": ("Spine1", "Spine2"),
    "Chest": ("Chest",),
    "Neck": ("Neck1", "Neck2"),
    "Head": ("Head",),
    "Shoulder.L": ("LeftShoulder",),
    "UpperArm.L": ("LeftArm",),
    "LowerArm.L": ("LeftForeArm",),
    "Hand.L": ("LeftHand",),
    "Shoulder.R": ("RightShoulder",),
    "UpperArm.R": ("RightArm",),
    "LowerArm.R": ("RightForeArm",),
    "Hand.R": ("RightHand",),
    "UpperLeg.L": ("LeftLeg",),
    "LowerLeg.L": ("LeftShin",),
    "Foot.L": ("LeftFoot",),
    "UpperLeg.R": ("RightLeg",),
    "LowerLeg.R": ("RightShin",),
    "Foot.R": ("RightFoot",),
}

BVH_TO_METERS = 0.01  # kimodo's soma-bvh export writes centimeter-scale offsets


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:]
    p = argparse.ArgumentParser()
    p.add_argument("--bvh", required=True)
    p.add_argument("--target", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--anim-name", default="retargeted")
    return p.parse_args(argv)


def find_armature(objs):
    for obj in objs:
        if obj.type == "ARMATURE":
            return obj
    raise RuntimeError("no armature found")


def main():
    args = parse_args()

    bpy.ops.wm.read_factory_settings(use_empty=True)

    before = set(bpy.context.scene.objects)
    bpy.ops.import_anim.bvh(filepath=args.bvh, global_scale=BVH_TO_METERS, use_fps_scale=False)
    src_arm = find_armature(set(bpy.context.scene.objects) - before)

    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=args.target)
    tgt_arm = find_armature(set(bpy.context.scene.objects) - before)

    src_pose = src_arm.pose.bones
    tgt_pose = tgt_arm.pose.bones
    for tgt_name in MERGE_MAP:
        tgt_pose[tgt_name].rotation_mode = "QUATERNION"

    base_loc = tgt_arm.location.copy()
    # scene.frame_end defaults to Blender's stock 250 regardless of the BVH's
    # actual length, so read the real range off the imported action instead.
    src_frame_range = src_arm.animation_data.action.frame_range
    frame_start = int(src_frame_range[0])
    frame_end = int(src_frame_range[1])
    print(f"retargeting frames {frame_start}..{frame_end}")

    hips_world0 = None
    prev_q = {}
    for f in range(frame_start, frame_end + 1):
        bpy.context.scene.frame_set(f)

        hips_world = src_arm.matrix_world @ src_pose["Hips"].matrix.translation
        if hips_world0 is None:
            hips_world0 = hips_world.copy()
        tgt_arm.location = base_loc + (hips_world - hips_world0)
        tgt_arm.keyframe_insert(data_path="location", frame=f)

        for tgt_name, src_names in MERGE_MAP.items():
            q = Quaternion((1, 0, 0, 0))
            for src_name in src_names:
                q = q @ src_pose[src_name].matrix_basis.to_quaternion()
            # q and -q represent the identical rotation, but to_quaternion()
            # picks a sign independently each frame. If two adjacent
            # keyframes land on opposite signs, interpolation (in Blender's
            # own playback and again in the glTF exporter's sampling) SLERPs
            # the *long* way around - nearly a full extra turn - instead of
            # the few degrees actually intended. Forcing continuity against
            # the previous frame keeps every bone on the short path.
            if tgt_name in prev_q and q.dot(prev_q[tgt_name]) < 0:
                q = -q
            prev_q[tgt_name] = q
            pb = tgt_pose[tgt_name]
            pb.rotation_quaternion = q
            pb.keyframe_insert(data_path="rotation_quaternion", frame=f)

    action = tgt_arm.animation_data.action
    if hasattr(action, "fcurves"):
        fcurves = action.fcurves
    else:
        # Blender 5.x layered/slotted Action API
        fcurves = []
        for layer in action.layers:
            for strip in layer.strips:
                for channelbag in strip.channelbags:
                    fcurves.extend(channelbag.fcurves)
    for fc in fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    action.name = args.anim_name

    bpy.data.objects.remove(src_arm, do_unlink=True)
    for a in list(bpy.data.actions):
        if a is not action:
            bpy.data.actions.remove(a)

    # Blender's glTF exporter bakes the CURRENT pose-bone state as part of the
    # skin's rest/bind reference, not the armature's true edit-bone rest - and
    # the frame loop above leaves the scene sitting on frame_end. Left alone,
    # whatever distortion exists at the last animated frame gets baked into
    # the mesh's base shape permanently, independent of (and invisible to) the
    # exported animation channels themselves, which are sampled separately.
    # Resetting current pose to identity here doesn't touch the keyframes
    # already recorded on each fcurve - only the transient state export reads
    # as "rest".
    for pb in tgt_pose:
        pb.rotation_quaternion = Quaternion((1, 0, 0, 0))
    tgt_arm.location = base_loc
    bpy.context.view_layer.update()

    bpy.ops.object.select_all(action="DESELECT")
    tgt_arm.select_set(True)
    for child in tgt_arm.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = tgt_arm

    bpy.ops.export_scene.gltf(
        filepath=args.out,
        use_selection=True,
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIVE_ACTIONS",
        export_frame_range=False,
        export_force_sampling=True,
        export_skins=True,
        export_yup=True,
    )
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
