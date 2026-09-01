"""Turn raw TRELLIS.2 exports into game-ready GLBs.

The generator hands us ~500k-triangle meshes, Y-up, normalised into a unit cube,
often with the concept image's floor reconstructed as a flat disc welded to the
subject. Godot can technically render that, but the disc is the widest thing in
the mesh (so any auto-fit scales to the floor, not the character) and half a
million triangles per prop is absurd for a toybox platformer.

Each asset gets: decimate (in Blender, keeping the source UVs) -> drop floor
disc and stray specks -> force the material matte -> recentre on its own
footprint -> rebase to y=0 -> export.

**Decimation happens in Blender, not here.** A TRELLIS surface-net mesh is
~11k disconnected shell fragments. `fast_simplification` + a fresh xatlas
unwrap turned that into ~1500 tiny UV charts, and the re-bake across all those
seams rendered in-engine as a white crackle over every surface. Blender's
collapse decimator carries the original per-vertex UVs through, so the mesh
keeps pointing at TRELLIS's own coherent atlas and nothing is re-baked. See
`tools/blender_decimate.py`.

    python tools/import_assets.py [--src DIR] [--dry-run]
"""

import argparse
import os
import subprocess
import sys
import tempfile

import numpy as np
import trimesh

SRC = r"C:\Users\joshu\Documents\ComfyUI\output"
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
_HERE = os.path.dirname(os.path.abspath(__file__))

# TRELLIS timestamp -> (asset name, target triangle count)
# Identified by silhouette render + dominant texture colour, not by filename.
# TRELLIS timestamp -> (asset name, target triangle count after Blender collapse)
ASSETS = {
    "trellis2_20260827_180522.glb": ("bouncy_blue", 26000),
    "trellis2_20260827_181638.glb": ("spotty_doggy", 26000),
    "trellis2_20260827_185121.glb": ("rainbow_arch", 20000),
    "trellis2_20260827_092102.glb": ("castle_gate", 22000),
    "trellis2_20260827_092423.glb": ("ball", 6000),
    "trellis2_20260827_091823.glb": ("sparkle_cubes", 6000),
    "trellis2_20260828_171357.glb": ("star", 6000),
    # Fantasy set dressing (see DECOR in Game.gd).
    "trellis2_20260828_181030.glb": ("toadstool", 6500),
    "trellis2_20260828_181153.glb": ("crystal_cluster", 6500),
    "trellis2_20260828_183752.glb": ("candy_tree", 9000),
    "trellis2_20260828_181514.glb": ("giant_flower", 6500),
    "trellis2_20260828_181843.glb": ("sparkle_fountain", 9000),
    "trellis2_20260828_182759.glb": ("cloud_puff", 6500),
    # Ms. Bumbleflower, the wandering bunny (see Bunny.gd).
    "trellis2_20260828_224423.glb": ("bunny", 12000),
    # Dino Valley's three land dinosaurs (see DinoValley.gd).
    "trellis2_20260829_161931.glb": ("trex", 14000),
    "trellis2_20260829_162113.glb": ("triceratops", 14000),
    "trellis2_20260829_162244.glb": ("stegosaurus", 14000),
    # The Safari Plains (see SafariPlains.gd).
    "trellis2_20260830_123324.glb": ("giraffe", 14000),
    "trellis2_20260830_123449.glb": ("lion", 14000),
    "trellis2_20260830_123641.glb": ("hippo", 14000),
    "trellis2_20260830_123759.glb": ("elephant", 14000),
    "trellis2_20260830_123950.glb": ("zebra", 14000),
    # The Haunted House (see HauntedHouse.gd). The five ghosts come from ONE
    # body prompt with only the face sentence swapped, which is what lets the
    # island claim the face is the only difference between them.
    "trellis2_20260831_174646.glb": ("ghost_happy", 12000),
    "trellis2_20260831_174928.glb": ("ghost_sad", 12000),
    "trellis2_20260831_181154.glb": ("ghost_angry", 12000),
    "trellis2_20260831_175429.glb": ("ghost_scared", 12000),
    "trellis2_20260831_181611.glb": ("ghost_sleepy", 12000),
    "trellis2_20260831_180119.glb": ("haunted_house", 16000),
    "trellis2_20260831_180215.glb": ("spooky_tree", 10000),
    "trellis2_20260831_180517.glb": ("pumpkin", 6500),
    "trellis2_20260831_180707.glb": ("gravestone", 5000),
    "trellis2_20260831_180904.glb": ("lantern", 6000),
}

# Two of the ghosts are SECOND attempts, and the first ones are not listed above
# because they are not what shipped. Recorded here because both failures are
# worth recognising again rather than rediscovering:
#
#   ghost_angry   trellis2_20260831_175215.glb  the small scowling mouth
#                 reconstructed as a streaked smear with the red cheeks bled
#                 into a band across the face. Re-rolled on a concept whose
#                 mouth was larger and further from the cheeks.
#   ghost_sleepy  trellis2_20260831_175828.glb  the concept's slightly darker
#                 backdrop survived background removal and came back welded on
#                 as a flat slab behind the ghost - README trap 14. Re-rolled
#                 on a concept with a clean light background.

# The butterfly and the pteranodon are deliberately NOT in ASSETS. They are the
# two rigged assets here, and their pipeline has an extra stage: decimate to a
# scratch file, then run tools/rig_wings.py to skin it before it lands in
# assets/models. Listing either above would let a plain `import_assets.py` run
# overwrite the rigged GLB with an unrigged one and silently stop the wings.
#
#   butterfly   trellis2_20260828_231641.glb   rig_wings.py (default hinge)
#   pteranodon  trellis2_20260829_162349.glb   rig_wings.py -- ... 0.16 0.38
#
# The pteranodon needs its hinge further out than the butterfly's: it carries a
# fat body and a head between its wings, and the default hinge drags the torso
# along with the flap. See the rig_wings.py docstring.

# A component is floor if it is wide, wafer-thin, and sits at the bottom.
FLOOR_MAX_THICKNESS = 0.06   # relative to its own footprint
FLOOR_MIN_FOOTPRINT = 0.30   # relative to the whole mesh
SPECK_MIN_FACES = 12         # components smaller than this are generator noise

# TRELLIS writes metallicFactor 1.0 and relies on a metallic-roughness texture
# to pull it back down. That texture does not survive the round trip, so every
# asset arrives as a perfect mirror and reflects the sky as a milky haze.
# These are matte plastic toys - override the factors outright.
METALLIC = 0.0
ROUGHNESS = 0.85


def blender_decimate(src_glb, target):
    """Collapse `src_glb` to ~`target` triangles in Blender, keeping its UVs.

    Blender welds the coincident shell fragments (`remove_doubles`), drops
    degenerate slivers, then runs a COLLAPSE decimate modifier - which carries
    the per-vertex UV layer through untouched, so the result still samples
    TRELLIS's own atlas. Returns the path to a temp GLB the caller must delete.
    """
    fd, out = tempfile.mkstemp(suffix=".glb", prefix="bdec_")
    os.close(fd)
    script = os.path.join(_HERE, "blender_decimate.py")
    r = subprocess.run(
        [BLENDER, "-b", "-P", script, "--", src_glb, out, str(int(target))],
        capture_output=True, text=True,
    )
    if not os.path.exists(out) or os.path.getsize(out) == 0:
        tail = (r.stdout[-2000:] + "\n" + r.stderr[-2000:]).strip()
        raise RuntimeError("blender_decimate produced nothing:\n" + tail)
    return out


def _matte(mesh) -> None:
    """Drop the inherited full-metal look so albedo reads as painted plastic."""
    material = getattr(mesh.visual, "material", None)
    if material is None:
        return
    material.metallicFactor = METALLIC
    material.roughnessFactor = ROUGHNESS


def face_components(mesh):
    """Label every face with its connected component.

    trimesh's own .split() materialises a Trimesh per component; on a raw
    half-million-triangle export with hundreds of specks that runs out of
    memory, so label the adjacency graph directly and keep it to arrays.
    """
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components

    adj = mesh.face_adjacency
    n = len(mesh.faces)
    if len(adj) == 0:
        return np.arange(n), n
    g = coo_matrix(
        (np.ones(len(adj), np.int8), (adj[:, 0], adj[:, 1])), shape=(n, n)
    )
    count, labels = connected_components(g, directed=False)
    return labels, count


def strip_floor(mesh, name):
    """Drop flat ground discs and specks. Returns (mesh, list of log lines)."""
    labels, count = face_components(mesh)
    if count <= 1:
        return mesh, ["  single component, nothing to strip"]

    total = len(mesh.faces)
    span = max(mesh.extents[0], mesh.extents[2])
    floor_y = mesh.bounds[0][1] + 0.10 * mesh.extents[1]
    tri = mesh.vertices[mesh.faces]           # [F, 3, 3]

    log = []
    drop = np.zeros(total, bool)
    for lab in range(count):
        sel = labels == lab
        nf = int(sel.sum())
        if nf == 0:
            continue
        pts = tri[sel].reshape(-1, 3)
        lo, hi = pts.min(0), pts.max(0)
        ex, ey, ez = hi - lo
        foot = max(ex, ez)
        pct = 100.0 * nf / total

        if ey < FLOOR_MAX_THICKNESS * max(foot, 1e-6) \
                and foot > FLOOR_MIN_FOOTPRINT * max(span, 1e-6) \
                and lo[1] <= floor_y:
            log.append("  - floor disc   %6d tris (%4.1f%%)  %.2f x %.3f x %.2f"
                       % (nf, pct, ex, ey, ez))
            drop |= sel
        elif nf < SPECK_MIN_FACES:
            drop |= sel

    specks = int(drop.sum()) - sum(
        int(s.split()[3]) for s in log if "floor disc" in s
    )
    if specks > 0:
        log.append("  - specks       %6d tris in small fragments" % specks)

    if drop.all():
        return mesh, log + ["  ! everything looked like floor - kept as-is"]
    if not drop.any():
        return mesh, log or ["  nothing to strip"]

    mesh.update_faces(~drop)
    mesh.remove_unreferenced_vertices()
    return mesh, log


def ground(mesh):
    """Centre on XZ, sit on y=0, so Godot can place it by its feet."""
    b = mesh.bounds
    mesh.apply_translation([
        -(b[0][0] + b[1][0]) / 2.0,
        -b[0][1],
        -(b[0][2] + b[1][2]) / 2.0,
    ])
    return mesh


def process(src_path, name, target, out_dir, dry_run):
    before = len(trimesh.load(src_path, force="mesh").faces)

    # Collapse in Blender (keeps the UVs), then everything else is on the light
    # mesh: drop any welded floor disc / stray specks, force matte, sit on y=0.
    #
    # process=False is load-bearing: trimesh's default load merges spatially
    # close vertices, which fuses the two sides of every UV seam onto one UV
    # coordinate and tears the atlas into a white crackle in-engine.
    tmp = blender_decimate(src_path, target)
    try:
        loaded = trimesh.load(tmp, process=False, force="scene")
        geoms = list(loaded.geometry.values())
        mesh = geoms[0] if len(geoms) == 1 else trimesh.util.concatenate(geoms)
    finally:
        os.unlink(tmp)

    # Blender already welded fragments and dropped degenerate slivers; these
    # concepts are generated on plain backgrounds so there is no floor disc to
    # cut. `strip_floor` would also re-split the mesh on its UV seams and can
    # over-trim, so it is deliberately not run on this path.
    _matte(mesh)
    mesh = ground(mesh)

    print("%-14s %7d -> %6d tris   size %.2f x %.2f x %.2f"
          % (name, before, len(mesh.faces), *mesh.extents))

    if not dry_run:
        out = os.path.join(out_dir, name + ".glb")
        mesh.export(out)
        print("  -> %s" % out)
    return mesh.extents


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(here, "assets", "models")
    os.makedirs(out_dir, exist_ok=True)

    missing = [f for f in ASSETS if not os.path.exists(os.path.join(args.src, f))]
    if missing:
        print("missing source exports in %s:" % args.src, file=sys.stderr)
        for f in missing:
            print("  " + f, file=sys.stderr)
        return 1

    for fname, (name, target) in ASSETS.items():
        process(os.path.join(args.src, fname), name, target, out_dir, args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
