#!/usr/bin/env python3
"""
strip_bg.py  —  remove AI sprite checkerboard background
Usage: python3 strip_bg.py <sprite.png> [<sprite2.png> ...]

Samples the background color from image corners, then flood-fills
only pixels that match those exact grey values (±tolerance).
Safe for dark-robed / low-saturation characters.
"""
import sys
from PIL import Image
import numpy as np
from collections import deque

def strip_bg(path, tol=18):
    img  = Image.open(path).convert("RGBA")
    data = np.array(img, dtype=np.int16)   # int16 to avoid unsigned underflow
    h, w = data.shape[:2]

    # Sample several corner + edge pixels to collect background palette
    samples = []
    for r in [0, 1, 2, h//4, h//2, 3*h//4, h-3, h-2, h-1]:
        for c in [0, 1, 2, w-3, w-2, w-1]:
            if 0 <= r < h and 0 <= c < w:
                px = data[r, c, :3]
                sat = int(px.max()) - int(px.min())
                if sat < 20 and data[r, c, 3] > 10:   # only unsaturated, opaque
                    samples.append(px.tolist())

    if not samples:
        print(f"  {path}: no background samples found — skipping")
        return

    # Representative background color = median of samples
    bg = np.median(samples, axis=0).astype(np.int16)
    print(f"  bg color: rgb({bg[0]},{bg[1]},{bg[2]})")

    def is_bg(r, c):
        if data[r, c, 3] < 10:   # already transparent
            return True
        diff = np.abs(data[r, c, :3].astype(np.int16) - bg)
        return int(diff.max()) <= tol

    # Flood fill from all four edges
    visited = np.zeros((h, w), dtype=bool)
    queue   = deque()
    for r in range(h):
        for c in [0, w-1]:
            if not visited[r, c] and is_bg(r, c):
                visited[r, c] = True; queue.append((r, c))
    for c in range(w):
        for r in [0, h-1]:
            if not visited[r, c] and is_bg(r, c):
                visited[r, c] = True; queue.append((r, c))

    while queue:
        r, c = queue.popleft()
        for dr, dc in ((-1,0),(1,0),(0,-1),(0,1)):
            nr, nc = r+dr, c+dc
            if 0 <= nr < h and 0 <= nc < w and not visited[nr, nc] and is_bg(nr, nc):
                visited[nr, nc] = True; queue.append((nr, nc))

    result = data.astype(np.uint8)
    result[visited, 3] = 0
    Image.fromarray(result, "RGBA").save(path)
    removed = visited.sum()
    print(f"  {path}: removed {removed} px ({100*removed/(w*h):.1f}%)")

for path in sys.argv[1:]:
    strip_bg(path)
