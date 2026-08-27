"""Render Spriter SCML animations to PNG frames with Pillow.

Implements the standard SCML runtime math: mainline-driven sampling, bone
hierarchies with sign-adjusted angle inheritance, spin-aware angle
interpolation, and per-file pivots. Curve types other than instant are
treated as linear.

World space is Spriter's (y-up, degrees CCW); each sprite is composited onto
the canvas with an exact inverse-affine Image.transform, so arbitrary
rotation, non-uniform and negative scale all render correctly.
"""

from __future__ import annotations

import math
import os

from PIL import Image

from scml import file_lookup


# ---------------------------------------------------------------------------
# Sampling: animation state at time t -> list of world-space sprite ops
# ---------------------------------------------------------------------------

def _wrap_time(t, length, looping):
    if length <= 0:
        return 0
    if looping:
        return t % length
    return max(0, min(t, length))


def _key_pair(keys, t, length, looping):
    """Return (k1, k2, factor) for timeline keys around time t."""
    idx = 0
    for i, k in enumerate(keys):
        if k["time"] <= t:
            idx = i
        else:
            break
    k1 = keys[idx]
    if idx + 1 < len(keys):
        k2 = keys[idx + 1]
        t2 = k2["time"]
    elif looping and len(keys) > 1:
        k2 = keys[0]
        t2 = length
    else:
        return k1, None, 0.0
    span = t2 - k1["time"]
    if span <= 0 or k1.get("curve_type") == "instant":
        return k1, None, 0.0
    return k1, k2, (t - k1["time"]) / span


def _lerp(a, b, f):
    return a + (b - a) * f


def _lerp_angle(a, b, spin, f):
    if spin == 0:
        return a
    if spin > 0 and b < a:
        b += 360.0
    elif spin < 0 and b > a:
        b -= 360.0
    return _lerp(a, b, f)


def _sample_timeline(timeline, t, length, looping):
    """Interpolated object dict for a timeline at time t."""
    k1, k2, f = _key_pair(timeline["keys"], t, length, looping)
    o1 = k1["obj"]
    if k2 is None or f <= 0.0:
        return dict(o1)
    o2 = k2["obj"]
    out = dict(o1)
    for name in ("x", "y", "scale_x", "scale_y", "a"):
        out[name] = _lerp(o1.get(name, 1.0 if "scale" in name or name == "a" else 0.0),
                          o2.get(name, 1.0 if "scale" in name or name == "a" else 0.0), f)
    out["angle"] = _lerp_angle(o1.get("angle", 0.0), o2.get("angle", 0.0),
                               k1.get("spin", 1), f)
    return out


def _apply_parent(parent, child):
    """Standard SCML parent transform (matches SpriterDotNet)."""
    px = child["x"] * parent["scale_x"]
    py = child["y"] * parent["scale_y"]
    rad = math.radians(parent["angle"])
    cos_a, sin_a = math.cos(rad), math.sin(rad)
    out = dict(child)
    out["x"] = px * cos_a - py * sin_a + parent["x"]
    out["y"] = px * sin_a + py * cos_a + parent["y"]
    out["scale_x"] = child["scale_x"] * parent["scale_x"]
    out["scale_y"] = child["scale_y"] * parent["scale_y"]
    sign = 1.0 if parent["scale_x"] * parent["scale_y"] >= 0 else -1.0
    out["angle"] = (parent["angle"] + sign * child["angle"]) % 360.0
    out["a"] = child.get("a", 1.0) * parent.get("a", 1.0)
    return out


def sample_animation(project, entity, anim, time_ms):
    """Sample an animation. Returns draw ops sorted back-to-front.

    Each op: {file: filedict, x, y, angle, scale_x, scale_y, a,
              pivot_x, pivot_y, z}
    """
    files = file_lookup(project)
    length, looping = anim["length"], anim["looping"]
    t = _wrap_time(time_ms, length, looping)

    mainline = anim["mainline"]
    if not mainline:
        return []
    mkey = mainline[0]
    for k in mainline:
        if k["time"] <= t:
            mkey = k
        else:
            break

    timelines = {tl["id"]: tl for tl in anim["timelines"]}

    # Bones first: bone_ref parents index into this same list.
    bone_world = []
    for ref in mkey["bone_refs"]:
        obj = _sample_timeline(timelines[ref["timeline"]], t, length, looping)
        obj.setdefault("a", 1.0)
        if ref["parent"] is not None:
            obj = _apply_parent(bone_world[ref["parent"]], obj)
        bone_world.append(obj)

    ops = []
    for ref in mkey["object_refs"]:
        tl = timelines[ref["timeline"]]
        obj = _sample_timeline(tl, t, length, looping)
        if ref["parent"] is not None:
            obj = _apply_parent(bone_world[ref["parent"]], obj)
        fdict = files.get((obj.get("folder"), obj.get("file")))
        if fdict is None:
            continue
        ops.append({
            "file": fdict,
            "x": obj["x"], "y": obj["y"], "angle": obj["angle"],
            "scale_x": obj["scale_x"], "scale_y": obj["scale_y"],
            "a": max(0.0, min(1.0, obj.get("a", 1.0))),
            "pivot_x": obj.get("pivot_x", fdict["pivot_x"]),
            "pivot_y": obj.get("pivot_y", fdict["pivot_y"]),
            "z": ref.get("z_index", 0),
        })
    ops.sort(key=lambda o: o["z"])
    return ops


# ---------------------------------------------------------------------------
# Rasterizing: world-space ops -> PIL image
# ---------------------------------------------------------------------------

def _op_matrix(op):
    """Affine mapping image pixel (u, v) [y-down] -> world (x, y) [y-up]."""
    w, h = op["file"]["width"], op["file"]["height"]
    px = op["pivot_x"] * w
    py = op["pivot_y"] * h
    rad = math.radians(op["angle"])
    cos_a, sin_a = math.cos(rad), math.sin(rad)
    sx, sy = op["scale_x"], op["scale_y"]
    # local coords (y-up, pivot at origin): lx = u - px ; ly = (h - v) - py
    # world = rotate_ccw(angle) @ scale(sx, sy) @ local + (X, Y), expanded:
    a = cos_a * sx
    b = sin_a * sy
    c = sin_a * sx
    d = cos_a * sy
    return (a, b, op["x"] - a * px - b * (h - py),
            c, -d, op["y"] - c * px + d * (h - py))


def _op_corners(op):
    m00, m01, m02, m10, m11, m12 = _op_matrix(op)
    w, h = op["file"]["width"], op["file"]["height"]
    pts = []
    for u, v in ((0, 0), (w, 0), (0, h), (w, h)):
        pts.append((m00 * u + m01 * v + m02, m10 * u + m11 * v + m12))
    return pts


def frame_bbox(ops):
    """World-space bounding box (minx, miny, maxx, maxy) of one frame."""
    xs, ys = [], []
    for op in ops:
        for x, y in _op_corners(op):
            xs.append(x)
            ys.append(y)
    if not xs:
        return (0.0, 0.0, 1.0, 1.0)
    return (min(xs), min(ys), max(xs), max(ys))


def _invert_affine(m):
    m00, m01, m02, m10, m11, m12 = m
    det = m00 * m11 - m01 * m10
    if abs(det) < 1e-12:
        return None
    i00 = m11 / det
    i01 = -m01 / det
    i10 = -m10 / det
    i11 = m00 / det
    i02 = -(i00 * m02 + i01 * m12)
    i12 = -(i10 * m02 + i11 * m12)
    return (i00, i01, i02, i10, i11, i12)


class ImageCache:
    def __init__(self, base_dir):
        self.base_dir = base_dir
        self._cache = {}

    def load(self, name):
        img = self._cache.get(name)
        if img is None:
            path = os.path.join(self.base_dir, name.replace("/", os.sep))
            img = Image.open(path).convert("RGBA")
            self._cache[name] = img
        return img


def render_frame(ops, bbox, scale, cache, padding=0):
    """Composite ops onto an RGBA canvas covering world-space bbox."""
    minx, miny, maxx, maxy = bbox
    cw = max(1, int(math.ceil((maxx - minx) * scale)) + 2 * padding)
    ch = max(1, int(math.ceil((maxy - miny) * scale)) + 2 * padding)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))

    for op in ops:
        if op["a"] <= 0.001:
            continue
        src = cache.load(op["file"]["name"])
        m = _op_matrix(op)
        # world -> canvas: cx = (x - minx)*scale + pad ; cy = (maxy - y)*scale + pad
        m00, m01, m02, m10, m11, m12 = m
        c = (scale * m00, scale * m01, scale * (m02 - minx) + padding,
             -scale * m10, -scale * m11, scale * (maxy - m12) + padding)
        inv = _invert_affine(c)
        if inv is None:
            continue
        layer = src.transform((cw, ch), Image.Transform.AFFINE, inv,
                              resample=Image.Resampling.BILINEAR)
        if op["a"] < 0.999:
            alpha = layer.getchannel("A").point(lambda p: int(p * op["a"]))
            layer.putalpha(alpha)
        canvas.alpha_composite(layer)
    return canvas


def render_animation(project, entity, anim, frame_count=None, fps=None,
                     scale=1.0, padding=2):
    """Render an animation to a list of (time_ms, PIL.Image).

    All frames share one bounding box so the character doesn't jitter
    between frames. Looping animations skip the duplicate last frame.
    """
    length = anim["length"]
    if frame_count is None:
        if fps:
            frame_count = max(1, round(length * fps / 1000))
        else:
            frame_count = max(1, round(length / anim.get("interval", 100)))
    if anim["looping"]:
        times = [length * i / frame_count for i in range(frame_count)]
    else:
        times = [length * i / max(1, frame_count - 1) for i in range(frame_count)]

    all_ops = [sample_animation(project, entity, anim, t) for t in times]
    boxes = [frame_bbox(ops) for ops in all_ops if ops]
    if not boxes:
        raise ValueError(f"Animation {anim['name']!r} has no drawable objects.")
    bbox = (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))

    cache = ImageCache(os.path.dirname(project["path"]))
    frames = []
    for t, ops in zip(times, all_ops):
        frames.append((t, render_frame(ops, bbox, scale, cache, padding)))
    return frames, bbox


def build_sprite_sheet(frames, columns=None):
    """Pack equal-sized frames into a grid sheet. Returns (sheet, cols, rows)."""
    n = len(frames)
    if columns is None:
        columns = min(n, max(1, math.ceil(math.sqrt(n))))
    rows = math.ceil(n / columns)
    fw, fh = frames[0][1].size
    sheet = Image.new("RGBA", (columns * fw, rows * fh), (0, 0, 0, 0))
    for i, (_, img) in enumerate(frames):
        sheet.paste(img, ((i % columns) * fw, (i // columns) * fh))
    return sheet, columns, rows
