#!/usr/bin/env python3
"""
gen_textures.py — Generate seamless tileable environment textures via Gemini.

Reuses gemini_bot.py's browser automation but skips the reference-sheet /
attachment / slicing steps that character sprites need — textures are single
images with no sub-frames.

Usage:
    python3 tools/sprite-gen/gen_textures.py
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from gemini_bot import run_parallel

STYLE = (
    "HD 2D pixel art, Octopath Traveler visual style, seamless tileable "
    "texture (edges match perfectly when repeated in a grid), flat even "
    "top-down lighting with no baked shadows or vignette, flat cel shading "
    "with exactly 3-4 color values per area (no gradients), dark warm "
    "fantasy stone dungeon palette, 512x512 pixels."
)

TEXTURES = [
    (
        f"{STYLE} Worn stone flagstone floor texture: rectangular flagstones "
        "with dark mortar lines, subtle cracks, faint grime and moss in the "
        "grout. Viewed straight down.",
        "environments/dungeon-floor.png",
    ),
    (
        f"{STYLE} Rough hewn dungeon wall texture: large stacked stone "
        "blocks with mortar lines, subtle moss streaks and grime, occasional "
        "small cracks. Viewed straight on.",
        "environments/dungeon-wall.png",
    ),
    (
        f"{STYLE} Stone stairway descending texture: carved stone steps "
        "viewed from above at a slight angle, worn edges, subtle dust. "
        "Tiles seamlessly along the horizontal axis.",
        "environments/dungeon-stairs.png",
    ),
]


async def main():
    await run_parallel(TEXTURES, attachment_filename=None)


if __name__ == "__main__":
    asyncio.run(main())
