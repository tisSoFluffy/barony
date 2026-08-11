#!/usr/bin/env python3
"""
Normalize sliced character frames so every animation of a character is cohesive.

The slicer (slice_sprites.py) tight-crops each *sheet* independently, so a
character ends up with e.g. a 421x593 idle frame and a 298x254 death frame.
SpriteFactory applies one `pixel_size` to all of them, so the character visibly
pops to a different size the moment it switches animation, and short frames
float above the floor.

This pass fixes that, per character:

  1. Re-key the background. The white-key in the slicer misses sheets that came
     back with an opaque black, gray, or checkerboard backdrop. A flood fill
     seeded from the frame border removes whatever the backdrop actually is.
  2. Rescale each animation to a common drawn-resolution, measured as the
     median sqrt(alpha area) over the animation's frames. `idle` is the anchor
     because SpriteFactory derives the sprite's ground offset from idle_0.
     `death` inherits `hurt`'s factor: they are cut from the same source sheet,
     so they already share a scale, and collapsed death poses make any
     pose-based size metric meaningless.
  3. Re-emit every frame on one shared canvas, horizontally centred on the
     body and bottom-anchored to a common ground line, so feet stay planted
     across animation changes.

Usage:
    python3 tools/normalize_frames.py                # all characters
    python3 tools/normalize_frames.py murloc orc     # only these
"""

from pathlib import Path
import sys

import numpy as np
from PIL import Image

GODOT = Path(__file__).parent.parent / "godot"
SLICED = GODOT / "sprites" / "sliced"

# Characters this pass owns. Props/decals/projectiles are excluded: they are not
# a single body across animations, so scale normalization is meaningless there.
CHARACTERS = [
    "warrior", "warrior-base", "kobold", "murloc",
    "skeleton", "orc", "troll", "necro", "gormaul",
]

ANIMS = ["idle", "walk", "attack", "hurt", "death"]

# `death` is cut from the same sheet as `hurt`, so it is already at hurt's
# drawn scale. Measuring a collapsed corpse against a standing idle would
# shrink the corpse to nothing.
SCALE_INHERITS = {"death": "hurt"}

PAD = 6            # transparent margin around the shared canvas, in px
BG_TOL = 26        # per-channel flood-fill tolerance for backdrop removal
ALPHA_SOLID = 10   # alpha above this counts as body


def load_frames(char_dir: Path, anim: str) -> list:
    """Return [(index, Image)] for one animation, ordered by frame index."""
    out = []
    for path in sorted(char_dir.glob(f"{anim}_*.png")):
        stem = path.stem[len(anim) + 1:]
        if not stem.isdigit():
            continue
        out.append((int(stem), Image.open(path).convert("RGBA")))
    out.sort(key=lambda t: t[0])
    return out


def strip_backdrop(img: Image.Image) -> Image.Image:
    """
    Clear whatever backdrop the sheet came with by flooding inward from the
    border. Handles white, black, gray and checkerboard backdrops alike, and
    leaves interior pixels of the same colour (eye whites, black outlines)
    untouched because they are not border-connected.
    """
    arr = np.array(img).astype(np.int16)
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3]

    # Already-transparent pixels are backdrop by definition and seed the flood.
    transparent = arr[:, :, 3] <= ALPHA_SOLID

    # Sample the border to find candidate backdrop colours.
    border = np.concatenate([
        rgb[0, :], rgb[-1, :], rgb[:, 0], rgb[:, -1],
    ])
    border_opaque = np.concatenate([
        arr[0, :, 3], arr[-1, :, 3], arr[:, 0, 3], arr[:, -1, 3],
    ]) > ALPHA_SOLID
    border = border[border_opaque]

    # If the slicer's white-key already cleared the border, there is no opaque
    # backdrop left to remove — bail out. Without this guard the colour match
    # below also selects body pixels that happen to sit near the backdrop
    # colour (pale armour, bone, highlights); when such a region touches the
    # cleared area the flood eats straight through the sprite. That silently
    # destroyed 20-60% of several warrior frames.
    if border_opaque.mean() < 0.10:
        return img

    seed = transparent.copy()
    if border.size:
        # Quantize border colours and keep those covering a real share of the
        # border — a checkerboard contributes two such colours, a flat backdrop
        # one. Anything rarer is the sprite touching the edge, not backdrop.
        quant = (border // 16).astype(np.int32)
        keys = quant[:, 0] * 4096 + quant[:, 1] * 64 + quant[:, 2]
        vals, counts = np.unique(keys, return_counts=True)
        for val, count in zip(vals, counts):
            if count < border.shape[0] * 0.15:
                continue
            colour = np.array([val // 4096, (val // 64) % 64, val % 64]) * 16 + 8
            near = np.all(np.abs(rgb - colour) <= BG_TOL, axis=2)
            seed |= near

    if not seed.any():
        return img

    # Flood fill: keep only the seed region connected to the image border.
    reach = np.zeros((h, w), dtype=bool)
    reach[0, :] |= seed[0, :]
    reach[-1, :] |= seed[-1, :]
    reach[:, 0] |= seed[:, 0]
    reach[:, -1] |= seed[:, -1]

    # Iterative dilation constrained to the seed mask. Converges quickly since
    # backdrops are large open regions.
    while True:
        grown = reach.copy()
        grown[1:, :] |= reach[:-1, :]
        grown[:-1, :] |= reach[1:, :]
        grown[:, 1:] |= reach[:, :-1]
        grown[:, :-1] |= reach[:, 1:]
        grown &= seed
        if np.array_equal(grown, reach):
            break
        reach = grown

    out = np.array(img)
    out[reach, 3] = 0
    return Image.fromarray(out, "RGBA")


def resize_premultiplied(img: Image.Image, size: tuple) -> Image.Image:
    """
    Resample RGBA without halos.

    Keyed-out pixels keep their original white/gray RGB under alpha=0. A plain
    LANCZOS resize averages that RGB into edge pixels, ringing a bright fringe
    around every sprite. Premultiplying by alpha first makes cleared pixels
    contribute nothing, which is the only way edges stay clean when the
    hurt/death sheets get upscaled ~2x.
    """
    arr = np.array(img).astype(np.float32)
    alpha = arr[:, :, 3:4] / 255.0
    arr[:, :, :3] *= alpha
    pre = Image.fromarray(arr.astype(np.uint8), "RGBA").resize(size, Image.LANCZOS)

    out = np.array(pre).astype(np.float32)
    a = out[:, :, 3:4] / 255.0
    np.divide(out[:, :, :3], a, out=out[:, :, :3], where=a > 0.004)
    out[:, :, :3] = np.clip(out[:, :, :3], 0, 255)
    # Drop the near-transparent skirt LANCZOS leaves behind, so the alpha bbox
    # stays tight and frames don't drift off the shared ground line.
    out[:, :, 3][out[:, :, 3] < ALPHA_SOLID] = 0
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def body_bbox(img: Image.Image):
    """Tight bounding box of non-transparent pixels, or None if fully clear."""
    alpha = np.array(img)[:, :, 3]
    rows = np.where(alpha.max(axis=1) > ALPHA_SOLID)[0]
    cols = np.where(alpha.max(axis=0) > ALPHA_SOLID)[0]
    if rows.size == 0 or cols.size == 0:
        return None
    return int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1


def size_metric(img: Image.Image) -> float:
    """
    Pose-robust proxy for the resolution the character was drawn at.

    sqrt(alpha area) beats bbox height here: a lunging attack pose is much
    shorter than a standing idle but covers nearly the same number of pixels,
    so area survives pose changes that height does not.
    """
    alpha = np.array(img)[:, :, 3]
    return float(np.sqrt((alpha > ALPHA_SOLID).sum()))


def normalize_character(char: str, verbose: bool = True) -> bool:
    char_dir = SLICED / char
    if not char_dir.is_dir():
        print(f"SKIP (no directory): {char}")
        return False

    # --- Pass 1: strip backdrops, measure each animation ---------------------
    frames: dict = {}
    metrics: dict = {}
    for anim in ANIMS:
        loaded = load_frames(char_dir, anim)
        if not loaded:
            continue
        cleaned = [(i, strip_backdrop(im)) for i, im in loaded]
        frames[anim] = cleaned
        per_frame = [size_metric(im) for _, im in cleaned if body_bbox(im)]
        if per_frame:
            metrics[anim] = float(np.median(per_frame))

    if "idle" not in metrics:
        print(f"SKIP (no usable idle frames): {char}")
        return False

    # --- Pass 2: scale factor per animation, anchored on idle ----------------
    anchor = metrics["idle"]
    scales: dict = {}
    for anim in frames:
        source = SCALE_INHERITS.get(anim, anim)
        base = metrics.get(source) or metrics.get(anim)
        scales[anim] = (anchor / base) if base else 1.0

    # --- Pass 3: rescale, then find the canvas that fits every frame ---------
    scaled: dict = {}
    max_w = max_h = 0
    for anim, items in frames.items():
        factor = scales[anim]
        scaled[anim] = []
        for idx, img in items:
            if abs(factor - 1.0) > 0.02:
                new_size = (max(1, round(img.width * factor)),
                            max(1, round(img.height * factor)))
                img = resize_premultiplied(img, new_size)
            box = body_bbox(img)
            scaled[anim].append((idx, img, box))
            if box:
                max_w = max(max_w, box[2] - box[0])
                max_h = max(max_h, box[3] - box[1])

    canvas_w = max_w + PAD * 2
    canvas_h = max_h + PAD * 2

    # --- Pass 4: re-emit centred horizontally, bottom-anchored --------------
    ground = canvas_h - PAD
    written = 0
    for anim, items in scaled.items():
        for idx, img, box in items:
            out = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
            if box:
                body = img.crop(box)
                x = (canvas_w - body.width) // 2
                y = ground - body.height
                out.alpha_composite(body, (x, y))
            out.save(char_dir / f"{anim}_{idx}.png")
            written += 1

    if verbose:
        detail = "  ".join(
            f"{a}x{scales[a]:.2f}" for a in ANIMS if a in scales
        )
        print(f"{char:14s} -> {canvas_w}x{canvas_h}  ({written} frames)   {detail}")
    return True


def main() -> None:
    targets = sys.argv[1:] or CHARACTERS
    unknown = [t for t in targets if t not in CHARACTERS]
    if unknown:
        print(f"Unknown character(s): {', '.join(unknown)}")
        print(f"Known: {', '.join(CHARACTERS)}")
        sys.exit(1)

    for char in targets:
        normalize_character(char)
    print("\nDone.")


if __name__ == "__main__":
    main()
