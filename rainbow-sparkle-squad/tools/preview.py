"""Render a contact sheet of the processed GLBs, so asset problems are visible
without opening Godot. Plain numpy z-buffer rasteriser - no GPU, no display.

    python tools/preview.py [--dir assets/models] [--out out/preview.png]
"""

import argparse
import glob
import os

import numpy as np
import trimesh
from PIL import Image

LIGHT = np.array([0.35, 0.65, 0.68])
LIGHT /= np.linalg.norm(LIGHT)


def raster(mesh, size=260, yaw=0.6):
    """Orthographic z-buffered render, front-ish three-quarter view."""
    v = mesh.vertices.copy()
    c, s = np.cos(yaw), np.sin(yaw)
    v = v @ np.array([[c, 0, -s], [0, 1, 0], [s, 0, c]]).T

    v -= (v.min(0) + v.max(0)) / 2.0
    v /= np.abs(v).max() * 2.15
    v[:, 0] += 0.5
    v[:, 1] = 0.5 - v[:, 1]          # screen y grows downward

    tri = v[mesh.faces]
    n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    ln = np.linalg.norm(n, axis=1)
    ln[ln == 0] = 1.0
    n /= ln[:, None]
    shade = np.clip(np.abs(n @ LIGHT), 0.0, 1.0) * 0.75 + 0.22

    img = np.ones((size, size), np.float32)
    zbuf = np.full((size, size), -1e9, np.float32)
    p = tri[:, :, :2] * size
    z = tri[:, :, 2]

    for i in range(len(p)):
        (x0, y0), (x1, y1), (x2, y2) = p[i]
        lo_x, hi_x = int(max(0, min(x0, x1, x2))), int(min(size - 1, max(x0, x1, x2)))
        lo_y, hi_y = int(max(0, min(y0, y1, y2))), int(min(size - 1, max(y0, y1, y2)))
        if lo_x > hi_x or lo_y > hi_y:
            continue
        d = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(d) < 1e-9:
            continue
        xs = np.arange(lo_x, hi_x + 1) + 0.5
        ys = np.arange(lo_y, hi_y + 1) + 0.5
        gx, gy = np.meshgrid(xs, ys)
        w0 = ((y1 - y2) * (gx - x2) + (x2 - x1) * (gy - y2)) / d
        w1 = ((y2 - y0) * (gx - x2) + (x0 - x2) * (gy - y2)) / d
        w2 = 1.0 - w0 - w1
        inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        if not inside.any():
            continue
        zz = w0 * z[i, 0] + w1 * z[i, 1] + w2 * z[i, 2]
        sub_z = zbuf[lo_y:hi_y + 1, lo_x:hi_x + 1]
        hit = inside & (zz > sub_z)
        sub_z[hit] = zz[hit]
        img[lo_y:hi_y + 1, lo_x:hi_x + 1][hit] = shade[i]
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))


def main():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=os.path.join(here, "assets", "models"))
    ap.add_argument("--out", default=os.path.join(here, "..", "out", "rss_preview.png"))
    ap.add_argument("--size", type=int, default=260)
    args = ap.parse_args()

    files = sorted(glob.glob(os.path.join(args.dir, "*.glb")))
    if not files:
        print("no GLBs in " + args.dir)
        return
    sheet = Image.new("L", (args.size * len(files), args.size), 255)
    for i, f in enumerate(files):
        sc = trimesh.load(f, force="scene")
        m = trimesh.util.concatenate(list(sc.geometry.values()))
        sheet.paste(raster(m, args.size), (args.size * i, 0))
        print("%-16s %6d tris  %.2f x %.2f x %.2f"
              % (os.path.basename(f)[:-4], len(m.faces), *m.extents))
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    sheet.save(args.out)
    print("-> " + os.path.abspath(args.out))


if __name__ == "__main__":
    main()
