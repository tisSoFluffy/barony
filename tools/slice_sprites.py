#!/usr/bin/env python3
"""
Slice HD 2D sprite sheets into individual frame PNGs for Godot import.

Detects frame boundaries via white-column/white-row gaps, keys out the white
background, tight-crops all frames in an animation to a shared bounding box
(so frames are consistent in size and don't jitter), then saves to:
    godot/sprites/sliced/<character>/<anim>_<N>.png

Usage:
    python3 tools/slice_sprites.py
"""

from pathlib import Path
import numpy as np
from PIL import Image

GODOT = Path(__file__).parent.parent / "godot"
OUT   = GODOT / "sprites" / "sliced"

# (source_relative_to_GODOT, character, anim_names, frames_per_row, n_rows)
# Single-row sheets: n_rows=1, one anim name, one frame count.
# Two-row (hurt-death): n_rows=2, two anim names, two frame counts.
SHEETS = [
    # Warrior filenames untangled 2026-07-02 — every sheet now matches its name.
    ("sprites/warrior-idle.png",       "warrior", ["idle"],          [3], 1),
    ("sprites/warrior-walk.png",       "warrior", ["walk"],          [3], 1),
    ("sprites/warrior-attack.png",     "warrior", ["attack"],        [3], 1),
    ("sprites/warrior-hurt-death.png", "warrior", ["hurt", "death"], [2, 5], 2),
    # Weaponless base sheets for weapon-overlay paper-doll system (2026-07-02).
    ("sprites/warrior-base-idle.png",       "warrior-base", ["idle"],          [3], 1),
    ("sprites/warrior-base-walk.png",       "warrior-base", ["walk"],          [3], 1),
    ("sprites/warrior-base-attack.png",     "warrior-base", ["attack"],        [3], 1),
    ("sprites/warrior-base-hurt-death.png", "warrior-base", ["hurt", "death"], [2, 5], 2),
    ("sprites/kobold-idle.png",        "kobold",  ["idle"],          [3], 1),
    ("sprites/kobold-walk.png",        "kobold",  ["walk"],          [3], 1),
    ("sprites/kobold-attack.png",      "kobold",  ["attack"],        [3], 1),
    ("sprites/kobold-hurt-death.png",  "kobold",  ["hurt", "death"], [2, 5], 2),
    ("sprites/murloc-idle.png",        "murloc",    ["idle"],          [3], 1),
    ("sprites/murloc-walk.png",        "murloc",    ["walk"],          [3], 1),
    ("sprites/murloc-attack.png",      "murloc",    ["attack"],        [3], 1),
    ("sprites/murloc-hurt-death.png",  "murloc",    ["hurt", "death"], [2, 5], 2),
    ("sprites/skeleton-idle.png",      "skeleton",  ["idle"],          [3], 1),
    ("sprites/skeleton-walk.png",      "skeleton",  ["walk"],          [3], 1),
    ("sprites/skeleton-attack.png",    "skeleton",  ["attack"],        [3], 1),
    ("sprites/skeleton-hurt-death.png","skeleton",  ["hurt", "death"], [2, 5], 2),
    ("sprites/orc-idle.png",           "orc",       ["idle"],          [3], 1),
    ("sprites/orc-walk.png",           "orc",       ["walk"],          [3], 1),
    ("sprites/orc-attack.png",         "orc",       ["attack"],        [3], 1),
    ("sprites/orc-hurt-death.png",     "orc",       ["hurt", "death"], [2, 5], 2),
    ("sprites/troll-idle.png",         "troll",     ["idle"],          [3], 1),
    ("sprites/troll-walk.png",         "troll",     ["walk"],          [3], 1),
    ("sprites/troll-attack.png",       "troll",     ["attack"],        [3], 1),
    ("sprites/troll-hurt-death.png",   "troll",     ["hurt", "death"], [2, 5], 2),
    ("sprites/necro-idle.png",         "necro",     ["idle"],          [3], 1),
    ("sprites/necro-walk.png",         "necro",     ["walk"],          [3], 1),
    ("sprites/necro-attack.png",       "necro",     ["attack"],        [3], 1),
    ("sprites/necro-hurt-death.png",   "necro",     ["hurt", "death"], [2, 5], 2),
    ("sprites/gormaul-idle.png",       "gormaul",   ["idle"],          [3], 1),
    ("sprites/gormaul-walk.png",       "gormaul",   ["walk"],          [3], 1),
    ("sprites/gormaul-attack.png",     "gormaul",   ["attack"],        [3], 1),
    ("sprites/gormaul-hurt-death.png", "gormaul",   ["hurt", "death"], [2, 5], 2),
    ("sprites/thrown-axe.png",         "projectiles", ["axe"],         [3], 1),
    ("sprites/shadow-bolt.png",        "projectiles", ["bolt"],        [3], 1),
    ("sprites/props.png",              "props",       ["prop"],        [6], 1),
    ("sprites/standing-torch.png",     "sconce",      ["flame"],       [3], 1),
    ("sprites/floor-decals.png",       "decals",      ["decal"],       [4], 1),
]

WHITE_THRESH = 245  # per-channel threshold for "white" pixels


def find_content_spans(arr_rgb: np.ndarray, axis: int, n_expected: int) -> list:
    """
    Return n_expected (start, end) pixel ranges that contain non-white content
    along the given axis (0=rows, 1=cols).  Falls back to even division if the
    gap-detection comes up short.
    """
    # Collapse the perpendicular axis and all channels to get a 1-D min signal.
    other = 1 - axis
    # arr_rgb shape: (H, W, 3)
    collapsed = arr_rgb.min(axis=other).min(axis=-1)  # (W,) or (H,)

    is_content = collapsed < WHITE_THRESH

    spans: list = []
    in_span = False
    start = 0
    for i, c in enumerate(is_content):
        if c and not in_span:
            in_span = True
            start = i
        elif not c and in_span:
            in_span = False
            spans.append([start, i])
    if in_span:
        spans.append([start, len(is_content)])

    # Merge spans separated by < 4 pixels (handles anti-alias fringing).
    merged: list = []
    for s in spans:
        if merged and s[0] - merged[-1][1] < 4:
            merged[-1][1] = s[1]
        else:
            merged.append(s)

    # Drop spans much narrower than the widest span — these are baked-in text
    # labels ("HURT", "DEATH") that appear as content but aren't sprite frames.
    if len(merged) > n_expected:
        max_w = max(s[1] - s[0] for s in merged)
        merged = [s for s in merged if (s[1] - s[0]) >= max_w * 0.5]

    if len(merged) == n_expected:
        return [(s[0], s[1]) for s in merged]

    # Fall back to even division.
    total = arr_rgb.shape[axis]
    step  = total / n_expected
    return [(int(i * step), int((i + 1) * step)) for i in range(n_expected)]


def key_white(img_rgba: Image.Image) -> Image.Image:
    """Replace near-white pixels (all channels ≥ WHITE_THRESH) with transparent."""
    arr = np.array(img_rgba)
    mask = np.all(arr[:, :, :3] >= WHITE_THRESH, axis=2)
    arr[mask, 3] = 0
    return Image.fromarray(arr, "RGBA")


def slice_sheet(
    src_path: Path,
    character: str,
    anims: list,
    frames_per_row: list,
    n_rows: int,
) -> None:
    img = Image.open(src_path).convert("RGBA")
    rgb = np.array(img)[:, :, :3]

    out_dir = OUT / character
    out_dir.mkdir(parents=True, exist_ok=True)

    if n_rows == 1:
        row_spans = [(0, img.height)]
    else:
        row_spans = find_content_spans(rgb, axis=0, n_expected=n_rows)

    for row_i, (y0, y1) in enumerate(row_spans):
        anim        = anims[row_i]
        n_frames    = frames_per_row[row_i]
        row_rgb     = rgb[y0:y1, :, :]
        col_spans   = find_content_spans(row_rgb, axis=1, n_expected=n_frames)

        # Pass 1 — key white on every frame, accumulate shared bounding box.
        frames_rgba: list = []
        union_box: list   = None  # [left, top, right, bottom]

        for x0, x1 in col_spans:
            frame = img.crop((x0, y0, x1, y1)).convert("RGBA")
            frame = key_white(frame)
            frames_rgba.append(frame)

            bbox = frame.getbbox()  # tight box of non-transparent pixels
            if bbox:
                if union_box is None:
                    union_box = list(bbox)
                else:
                    union_box[0] = min(union_box[0], bbox[0])
                    union_box[1] = min(union_box[1], bbox[1])
                    union_box[2] = max(union_box[2], bbox[2])
                    union_box[3] = max(union_box[3], bbox[3])

        # Pass 2 — crop all frames to the shared box + 4 px padding.
        if union_box:
            pad = 4
            w0  = frames_rgba[0].width
            h0  = frames_rgba[0].height
            cx0 = max(0,  union_box[0] - pad)
            cy0 = max(0,  union_box[1] - pad)
            cx1 = min(w0, union_box[2] + pad)
            cy1 = min(h0, union_box[3] + pad)
        else:
            cx0, cy0 = 0, 0
            cx1, cy1 = frames_rgba[0].width, frames_rgba[0].height

        for col_i, frame in enumerate(frames_rgba):
            out_frame = frame.crop((cx0, cy0, cx1, cy1))
            out_path  = out_dir / f"{anim}_{col_i}.png"
            out_frame.save(out_path)
            rel = out_path.relative_to(GODOT.parent)
            print(f"  → {rel}  ({out_frame.size[0]}×{out_frame.size[1]})")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for src_rel, character, anims, frames_per_row, n_rows in SHEETS:
        src_path = GODOT / src_rel
        if not src_path.exists():
            print(f"SKIP (not found): {src_rel}")
            continue
        print(f"\n{src_rel}  ({character}):")
        slice_sheet(src_path, character, anims, frames_per_row, n_rows)
    print("\nDone.")


if __name__ == "__main__":
    main()
