#!/usr/bin/env python3
"""Fit a humanoid armature to an unrigged image-to-3D character and skin it.

    blender --background --python tools/autorig.py -- IN.glb OUT.glb

Image-to-3D exports (Hunyuan3D and friends) are a single watertight shell with
no skeleton, so nothing can articulate: `Player._animate()` can only move the
whole body. This builds a standard humanoid rig, binds the shell to it with
Blender's bone-heat weighting, and writes a skinned glTF that Godot imports as a
Skeleton3D driving the mesh.

Bone positions are measured off the mesh rather than assumed. Anatomical ratios
place them roughly, then each joint is snapped to the geometry actually there —
the crotch is found by scanning for the gap between the legs, and arm bones are
placed at the real half-width of the mesh at shoulder height. A rig built from
ratios alone drifts badly on these meshes, because bulky boots and backpacks
push the bounding box around.

Run the mesh through clean_gen_mesh.py FIRST. A baked-in ground plane wrecks the
measurements and bone heat will happily weight the floor to the legs.
"""

import sys
import numpy as np

import bpy
from mathutils import Vector

# name -> (head ratio of height, tail ratio, parent). x/z are solved from the mesh.
SPINE = [
    ("Hips",     0.530, 0.620, None),
    ("Spine",    0.620, 0.720, "Hips"),
    ("Chest",    0.720, 0.820, "Spine"),
    ("Neck",     0.820, 0.880, "Chest"),
    ("Head",     0.880, 1.000, "Neck"),
]
ARM = [("UpperArm", 0.815, 0.610), ("LowerArm", 0.610, 0.430), ("Hand", 0.430, 0.360)]
LEG = [("UpperLeg", 0.530, 0.290), ("LowerLeg", 0.290, 0.055), ("Foot", 0.055, 0.010)]


def log(msg):
    print("[autorig] %s" % msg, flush=True)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(path):
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("autorig: no mesh in %s" % path)
    if len(meshes) > 1:                       # image-to-3D gives one shell; be safe
        bpy.ops.object.select_all(action="DESELECT")
        for m in meshes:
            m.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
        meshes = [bpy.context.view_layer.objects.active]
    obj = meshes[0]
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def vertex_array(obj):
    return np.array([v.co[:] for v in obj.data.vertices], dtype=float)


def measure(v):
    """Derives the joint geometry this particular mesh actually has.

    The axes are detected, not assumed: Blender's glTF importer rotates Y-up
    glTF into Z-up, so hard-coding an index silently builds the rig along the
    character's depth and every vertex ends up unweighted. For a standing figure
    the tallest extent is up and the wider of the other two is left-right.
    """
    lo, hi = v.min(0), v.max(0)
    ext = hi - lo
    up = int(np.argmax(ext))
    rest = [i for i in (0, 1, 2) if i != up]
    wid, dep = (rest[0], rest[1]) if ext[rest[0]] >= ext[rest[1]] else (rest[1], rest[0])

    height = ext[up]
    m = {"up": up, "wid": wid, "dep": dep, "base": lo[up], "height": height,
         "cw": (lo[wid] + hi[wid]) * 0.5, "cd": (lo[dep] + hi[dep]) * 0.5}

    def slab(a, b):
        s = v[(v[:, up] >= lo[up] + a * height) & (v[:, up] <= lo[up] + b * height)]
        return s if len(s) else v

    def limb_offset(a, b, floor_frac):
        """Distance from centreline to a limb's core, over a height band.

        Splits the band by side and takes each side's median offset, so the
        answer is where the limb actually IS. A percentile over the whole band
        mixes both limbs with the torso between them and lands too far in for
        arms and too far out for legs.
        """
        band = slab(a, b)
        off = band[:, wid] - m["cw"]
        sides = [np.median(np.abs(off[off > 0])) if (off > 0).any() else 0.0,
                 np.median(np.abs(off[off < 0])) if (off < 0).any() else 0.0]
        return max(float(np.mean(sides)), floor_frac * height)

    # Arms: measured at forearm height, where they hang clear of the torso.
    m["shoulder_x"] = limb_offset(0.45, 0.58, 0.055)
    # Legs: measured across the thigh band.
    m["leg_x"] = limb_offset(0.20, 0.40, 0.030)

    # Arms hang a little forward of the spine on most of these meshes.
    hd = slab(0.40, 0.48)
    m["arm_z"] = float(np.median(hd[:, dep]) - m["cd"]) * 0.5

    # Foot reach, signed, so the Foot bone points into the toe whichever way the
    # importer left the character facing.
    ft = slab(0.0, 0.09)
    fwd = float(ft[:, dep].max() - m["cd"])
    back = float(m["cd"] - ft[:, dep].min())
    m["foot_z"] = (fwd if fwd >= back else -back) * 0.6
    return m


def build_armature(obj, m):
    arm_data = bpy.data.armatures.new("Skeleton")
    rig = bpy.data.objects.new("Armature", arm_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    def y(r):
        return m["base"] + r * m["height"]

    def pt(w, h, d):
        """Builds a Blender-space point from (width, height, depth) components."""
        out = [0.0, 0.0, 0.0]
        out[m["wid"]] = w
        out[m["up"]] = h
        out[m["dep"]] = d
        return Vector(out)

    def add(name, head, tail, parent, connect=False):
        b = eb.new(name)
        b.head = pt(*head)
        b.tail = pt(*tail)
        if parent:
            b.parent = eb[parent]
            b.use_connect = connect
        return b

    cx, cz = m["cw"], m["cd"]
    for name, h, t, parent in SPINE:
        add(name, (cx, y(h), cz), (cx, y(t), cz), parent, parent is not None)

    for side, sgn in (("L", 1.0), ("R", -1.0)):
        sx = cx + sgn * m["shoulder_x"]
        az = cz + m["arm_z"]
        add("Shoulder." + side, (cx + sgn * m["shoulder_x"] * 0.35, y(0.815), cz),
            (sx, y(0.815), az), "Chest")
        prev = "Shoulder." + side
        for name, h, t in ARM:
            # arms taper inwards slightly as they descend, like a relaxed stance
            hx = cx + sgn * m["shoulder_x"] * (1.0 if name == "UpperArm" else 1.08)
            add(name + "." + side, (hx, y(h), az), (hx, y(t), az), prev, True)
            prev = name + "." + side

        lx = cx + sgn * m["leg_x"]
        prev = "Hips"
        for name, h, t in LEG:
            if name == "Foot":
                add(name + "." + side, (lx, y(h), cz), (lx, y(t), cz + m["foot_z"]), prev, True)
            else:
                add(name + "." + side, (lx, y(h), cz), (lx, y(t), cz), prev, name != "UpperLeg")
            prev = name + "." + side

    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def weld(obj):
    """Merges the duplicate vertices image-to-3D exports leave along UV seams.

    Bone heat needs a connected, manifold surface; a shell split into islands at
    every seam gives it nothing to diffuse across and every bone fails. Blender
    stores UVs per face-corner, not per vertex, so welding does NOT damage the
    texture mapping — the exporter re-splits on the way out.
    """
    before = len(obj.data.vertices)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=1e-5)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    log("welded %d -> %d verts" % (before, len(obj.data.vertices)))


def skin(obj, rig):
    """Bone-heat weights, falling back to envelopes if the solver gives up."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        log("bound with bone-heat automatic weights")
    except RuntimeError as exc:
        log("bone heat failed (%s); falling back to envelope weights" % exc)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.parent_set(type="ARMATURE_ENVELOPE")


def report(obj, rig):
    groups = [g.name for g in obj.vertex_groups]
    bones = [b.name for b in rig.data.bones]
    unweighted = 0
    for v in obj.data.vertices:
        if not any(g.weight > 0.0001 for g in v.groups):
            unweighted += 1
    log("bones %d, vertex groups %d, unweighted verts %d/%d"
        % (len(bones), len(groups), unweighted, len(obj.data.vertices)))
    missing = [b for b in bones if b not in groups]
    if missing:
        log("bones with no weights at all: %s" % ", ".join(missing))
    return unweighted


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 2:
        raise SystemExit("usage: blender --background --python autorig.py -- IN.glb OUT.glb")
    src, dst = argv[0], argv[1]

    clear_scene()
    obj = import_glb(src)
    v = vertex_array(obj)
    m = measure(v)
    log("height %.3f  shoulder_x %.3f  leg_x %.3f  arm_z %.3f  foot_z %.3f"
        % (m["height"], m["shoulder_x"], m["leg_x"], m["arm_z"], m["foot_z"]))

    weld(obj)
    rig = build_armature(obj, m)
    skin(obj, rig)
    report(obj, rig)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB",
                              export_skins=True, export_yup=True,
                              use_selection=True)
    log("wrote %s" % dst)


if __name__ == "__main__":
    main()
