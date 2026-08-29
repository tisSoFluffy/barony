"""Build a wing rig for the generated butterfly and export a skinned GLB.

    blender -b -P tools/rig_butterfly.py -- IN.glb OUT.glb

Everything else in this project is unrigged and animated by moving the whole
body (see Player._animate, Bunny._animate). That works for a hop or a squash,
but it cannot flap a wing: the two wings have to swing in opposite directions
about the body, and no whole-object transform does that. So the butterfly gets
a real skeleton — the one asset here that earns one.

The rig is deliberately tiny: three bones.

    Body    upright through the centre of the mesh, the root
      Wing_L  points out along +X from the body
      Wing_R  points out along -X from the body

Godot imports this as a Skeleton3D, and Butterfly.gd rotates the two wing bones
about their own length axis each frame to beat them.

Why weighting is done by hand rather than with bone heat: Blender's automatic
weights solve a diffusion over the surface, and on a butterfly — whose wings
touch the body over a broad seam and nearly touch each other — that bleeds one
wing's influence across the midline, so beating the left wing drags the right
one with it. Instead each vertex is weighted purely on its distance from the
body's centre plane: solidly body near the middle, solidly wing past the hinge,
and a short smoothstep between the two so the join bends instead of creasing.
That is exact, symmetric by construction, and needs no cleanup.
"""

import sys

import bpy
from mathutils import Vector

# Fractions of the half-wingspan. Inside HINGE_IN a vertex belongs entirely to
# the body; outside HINGE_OUT entirely to a wing; between them it blends.
HINGE_IN = 0.10
HINGE_OUT = 0.30


def log(msg):
    print("[rig_butterfly] %s" % msg, flush=True)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(path):
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("rig_butterfly: no mesh in %s" % path)
    if len(meshes) > 1:
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


def bounds(obj):
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    return (Vector((min(xs), min(ys), min(zs))),
            Vector((max(xs), max(ys), max(zs))))


def build_armature(obj):
    """Three bones sized off the mesh's own bounding box.

    import_assets.py already centred the mesh on XZ and sat it on y=0, and the
    concept is generated symmetrically, so the body's centre plane is x = 0.
    """
    lo, hi = bounds(obj)
    mid = (lo + hi) * 0.5
    half_span = max(hi.x - mid.x, 1e-4)

    arm_data = bpy.data.armatures.new("ButterflyRig")
    arm = bpy.data.objects.new("ButterflyRig", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")

    # Blender is Z-up. The incoming GLB is Y-up and sits on y=0, so after the
    # importer's conversion the model stands on z=0 here and "up" is +Z.
    body = arm_data.edit_bones.new("Body")
    body.head = Vector((0.0, mid.y, lo.z))
    body.tail = Vector((0.0, mid.y, hi.z))

    # Wing bones run straight out along X from the centre plane, at the body's
    # mid height and depth. A wing beat is then a rotation about the bone's own
    # length, which is the one motion no whole-object transform can produce.
    for name, sign in (("Wing_L", 1.0), ("Wing_R", -1.0)):
        b = arm_data.edit_bones.new(name)
        b.head = Vector((sign * half_span * HINGE_IN, mid.y, mid.z))
        b.tail = Vector((sign * half_span, mid.y, mid.z))
        b.parent = body
        b.use_connect = False

    bpy.ops.object.mode_set(mode="OBJECT")
    log("bones built, half-span %.3f" % half_span)
    return arm, half_span


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def weight_by_span(obj, arm, half_span):
    """Weight every vertex from its distance to the body's centre plane."""
    for name in ("Body", "Wing_L", "Wing_R"):
        if name in obj.vertex_groups:
            obj.vertex_groups.remove(obj.vertex_groups[name])
    g_body = obj.vertex_groups.new(name="Body")
    g_left = obj.vertex_groups.new(name="Wing_L")
    g_right = obj.vertex_groups.new(name="Wing_R")

    inner = half_span * HINGE_IN
    outer = half_span * HINGE_OUT

    for v in obj.data.vertices:
        x = v.co.x
        t = smoothstep((abs(x) - inner) / max(outer - inner, 1e-6))
        wing = g_left if x >= 0.0 else g_right
        g_body.add([v.index], 1.0 - t, "REPLACE")
        wing.add([v.index], t, "REPLACE")

    mod = obj.modifiers.new(name="Armature", type="ARMATURE")
    mod.object = arm
    obj.parent = arm
    log("weighted %d verts (hinge %.3f..%.3f)" % (len(obj.data.vertices), inner, outer))


def export_glb(path):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_yup=True,
        export_apply=False,      # baking would flatten the armature away
    )
    log("wrote %s" % path)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 2:
        raise SystemExit("usage: blender -b -P rig_butterfly.py -- IN.glb OUT.glb")
    src, dst = argv[0], argv[1]

    clear_scene()
    obj = import_glb(src)
    arm, half_span = build_armature(obj)
    weight_by_span(obj, arm, half_span)
    export_glb(dst)


if __name__ == "__main__":
    main()
