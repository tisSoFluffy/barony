#!/usr/bin/env python3
"""Strip the baked-in ground plane from an image-to-3D (Hunyuan3D) export.

The concept-art references fed to the texture workflow show the subject standing
on a floor, so the shape stage reconstructs that floor as a wide flat disc welded
to the subject's feet. On our exports it eats 85-95% of the 40k triangle budget
and — worse — it dominates the mesh AABB, which is what `MeshFactory._fit()`
measures when it scales a model to its documented size. Left in, every asset
lands scaled to its *floor*, not to itself.

This rewrites the .glb with the floor removed, unused vertices dropped, and
vertex normals added (the workflow exports none). Geometry is otherwise
untouched: no recentring, no rescaling — `_fit()` still owns placement.

    python tools/clean_gen_mesh.py IN.glb OUT.glb [--yaw DEGREES] [--keep-floor]

`--yaw` rotates the model about Y on the way out, for pointing a character at
-Z (the facing every asset in docs/COMFYUI_ASSET_PROMPTS.md is authored to).

Needs numpy only. Handles the single-mesh, single-material, embedded-PNG glb
that the workflow's Hy3DExportMesh node writes; it is not a general glTF tool.
"""

import argparse
import json
import struct
import sys

import numpy as np

_COMPONENT_TYPES = {5126: "<f4", 5125: "<u4", 5123: "<u2", 5121: "<u1"}
_TYPE_COUNTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    """Returns (gltf_json, binary_chunk) for a binary glTF file."""
    data = open(path, "rb").read()
    magic, _, total = struct.unpack("<III", data[:12])
    if magic != 0x46546C67:
        raise SystemExit(f"{path}: not a .glb")
    offset, chunks = 12, {}
    while offset < total:
        length, kind = struct.unpack("<II", data[offset:offset + 8])
        chunks[kind] = data[offset + 8:offset + 8 + length]
        offset += 8 + length
    return json.loads(chunks[0x4E4F534A].decode("utf-8")), chunks[0x004E4942]


def read_accessor(gltf, blob, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    count = acc["count"] * _TYPE_COUNTS[acc["type"]]
    dtype = np.dtype(_COMPONENT_TYPES[acc["componentType"]])
    flat = np.frombuffer(blob, dtype=dtype, count=count, offset=start)
    return flat.reshape(acc["count"], _TYPE_COUNTS[acc["type"]])


def floor_triangles(pos, tris, bins=240):
    """Returns (mask, band) for the triangles making up a baked-in ground plane.

    A floor shows up as a spike in the distribution of triangle heights: a large
    share of the mesh sitting in one thin horizontal band near the bottom, spread
    much wider in XZ than whatever stands on it.

    The whole band goes, including the sliver directly under the subject. Sparing
    that sliver only looks like it preserves the soles: the bake gives those
    triangles the *floor's* texels, so they render as bright puddles splayed
    around the boots. Cutting them leaves the model open at the very bottom,
    which nothing in a ground-level game ever sees.
    """
    centroid = pos[tris].mean(1)
    height = centroid[:, 1]
    counts, edges = np.histogram(height, bins=bins)
    peak = int(counts.argmax())
    # A real floor is both dominant and low; a dense band mid-model is the subject.
    if counts[peak] < 0.2 * len(tris):
        return None
    if edges[peak] > height.min() + 0.25 * (height.max() - height.min()):
        return None

    # Grow the band outwards while neighbouring bins are still densely populated.
    low = high = peak
    threshold = 0.01 * len(tris)
    while low > 0 and counts[low - 1] >= threshold:
        low -= 1
    while high < len(counts) - 1 and counts[high + 1] >= threshold:
        high += 1
    y_low, y_high = edges[low], edges[high + 1]
    return (height >= y_low) & (height <= y_high), (y_low, y_high)


def drop_floaters(pos, tris, min_share=0.01):
    """Drops connected components holding less than `min_share` of the triangles."""
    _, welded = np.unique(np.round(pos, 5), axis=0, return_inverse=True)
    parent = np.arange(welded.max() + 1)

    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for a, b, c in welded[tris]:
        ra, rb, rc = root(a), root(b), root(c)
        low = min(ra, rb, rc)
        parent[ra] = parent[rb] = parent[rc] = low

    labels = np.array([root(i) for i in welded[tris[:, 0]]])
    keep = np.ones(len(tris), dtype=bool)
    for label, count in zip(*np.unique(labels, return_counts=True)):
        if count < min_share * len(tris):
            keep &= labels != label
    return keep


def vertex_normals(pos, tris):
    """Area-weighted smooth normals — the workflow exports none at all."""
    normals = np.zeros_like(pos)
    corners = pos[tris]
    face = np.cross(corners[:, 1] - corners[:, 0], corners[:, 2] - corners[:, 0])
    for column in range(3):
        np.add.at(normals, tris[:, column], face)
    length = np.linalg.norm(normals, axis=1, keepdims=True)
    return normals / np.where(length < 1e-12, 1.0, length)


def write_glb(path, pos, normals, uv, tris, png, roughness):
    """Writes a single-mesh glb with the source texture embedded verbatim."""
    pos = pos.astype("<f4")
    normals = normals.astype("<f4")
    uv = uv.astype("<f4")
    tris = tris.astype("<u4")

    blob, views, accessors = bytearray(), [], []

    def add(array, target=None):
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": array.nbytes}
                     | ({"target": target} if target else {}))
        blob.extend(array.tobytes())
        return len(views) - 1

    for array, kind, target in ((pos, "VEC3", 34962), (normals, "VEC3", 34962),
                                (uv, "VEC2", 34962)):
        accessors.append({"bufferView": add(array, target), "componentType": 5126,
                          "count": len(array), "type": kind,
                          "min": array.min(0).tolist(), "max": array.max(0).tolist()})
    accessors.append({"bufferView": add(tris.reshape(-1), 34963), "componentType": 5125,
                      "count": tris.size, "type": "SCALAR"})
    image_view = add(np.frombuffer(png, dtype=np.uint8))

    gltf = {
        "asset": {"version": "2.0", "generator": "clean_gen_mesh.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "geometry_0", "mesh": 0}],
        "meshes": [{"primitives": [{
            "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
            "indices": 3, "material": 0}]}],
        "materials": [{"pbrMetallicRoughness": {
            "baseColorTexture": {"index": 0}, "baseColorFactor": [1, 1, 1, 1],
            "metallicFactor": 0.0, "roughnessFactor": roughness},
            "doubleSided": False}],
        "textures": [{"source": 0, "sampler": 0}],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "images": [{"bufferView": image_view, "mimeType": "image/png"}],
        "bufferViews": views,
        "accessors": accessors,
        "buffers": [{"byteLength": len(blob)}],
    }

    json_chunk = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_chunk += b" " * (-len(json_chunk) % 4)
    blob.extend(b"\0" * (-len(blob) % 4))
    body = (struct.pack("<II", len(json_chunk), 0x4E4F534A) + json_chunk
            + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))
    open(path, "wb").write(struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source")
    ap.add_argument("dest")
    ap.add_argument("--yaw", type=float, default=0.0,
                    help="rotate about Y by this many degrees on export")
    ap.add_argument("--keep-floor", action="store_true",
                    help="skip floor removal (normals/rotation only)")
    args = ap.parse_args(argv)

    gltf, blob = read_glb(args.source)
    primitives = [p for m in gltf["meshes"] for p in m["primitives"]]
    if len(primitives) != 1:
        raise SystemExit(f"{args.source}: expected one primitive, found {len(primitives)}")
    prim = primitives[0]
    pos = read_accessor(gltf, blob, prim["attributes"]["POSITION"]).astype(np.float64)
    uv = read_accessor(gltf, blob, prim["attributes"]["TEXCOORD_0"]).astype(np.float64)
    tris = read_accessor(gltf, blob, prim["indices"]).astype(np.int64).reshape(-1, 3)

    image = gltf["images"][0]
    view = gltf["bufferViews"][image["bufferView"]]
    png = bytes(blob[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]])
    roughness = gltf["materials"][0]["pbrMetallicRoughness"].get("roughnessFactor", 0.9)

    print(f"in   {len(tris):6d} tris  {len(pos):6d} verts  "
          f"size {np.ptp(pos, axis=0).round(3)}")

    if not args.keep_floor:
        floor = floor_triangles(pos, tris)
        if floor is None:
            print("     no ground plane detected — geometry kept as-is")
        else:
            on_floor, (y_low, y_high) = floor
            print(f"     floor band y {y_low:.3f}..{y_high:.3f}"
                  f" -> dropping {on_floor.sum()} tris ({100 * on_floor.mean():.1f}%)")
            tris = tris[~on_floor]
        floaters = drop_floaters(pos, tris)
        if not floaters.all():
            print(f"     dropping {(~floaters).sum()} floater tris")
            tris = tris[floaters]

    used, tris = np.unique(tris, return_inverse=True)
    tris = tris.reshape(-1, 3)
    pos, uv = pos[used], uv[used]

    if args.yaw:
        rad = np.radians(args.yaw)
        cos, sin = np.cos(rad), np.sin(rad)
        pos = pos @ np.array([[cos, 0, -sin], [0, 1, 0], [sin, 0, cos]]).T
        print(f"     rotated {args.yaw:g}deg about Y")

    write_glb(args.dest, pos, vertex_normals(pos, tris), uv, tris, png, roughness)
    low, high = pos.min(0), pos.max(0)
    print(f"out  {len(tris):6d} tris  {len(pos):6d} verts  size {(high - low).round(3)}")
    print(f"     base y {low[1]:.3f}  centre xz ({(low[0] + high[0]) / 2:.3f}, "
          f"{(low[2] + high[2]) / 2:.3f})  -> {args.dest}")


if __name__ == "__main__":
    sys.exit(main())
