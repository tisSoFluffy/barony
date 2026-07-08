#!/usr/bin/env python3
"""
Generate sprite sheets and game art images via Gemini Imagen.

Saves output to godot/sprites/ by default.

Usage:
    python3 tools/generate_sprites.py "2D pixel art slime idle animation, 3 frames in a row, solid black background"
    python3 tools/generate_sprites.py --prompt "kobold walk cycle" --out warrior_walk_new.png --ratio 4:3
    python3 tools/generate_sprites.py --list-ratios

Environment:
    GEMINI_API_KEY  — required, your Google AI Studio key
"""

import argparse
import os
import sys
from pathlib import Path

GODOT_SPRITES = Path(__file__).parent.parent / "godot" / "sprites"

# Sprite-sheet-specific suffix appended to every prompt to help Imagen
# stay on-model for game asset use cases.
SPRITE_SUFFIX = (
    " Crisp, clean edges with consistent character proportions across all frames. "
    "Game asset style. No labels or text overlays."
)

STYLE_PRESETS = {
    "pixel":  "2D pixel art, 16-bit retro style, sharp pixel edges, no anti-aliasing, ",
    "hd2d":   "HD-2D style, high definition 2D sprite, detailed painterly texture, soft shading, ",
    "iso":    "isometric game sprite, clean outlines, flat shading, top-down 45-degree view, ",
    "flat":   "flat vector game sprite, bold outlines, minimal shading, mobile game style, ",
}


def build_prompt(raw: str, style=None) -> str:
    prefix = STYLE_PRESETS.get(style, "") if style else ""
    return prefix + raw + SPRITE_SUFFIX


def generate(prompt: str, output_path: Path, aspect_ratio: str = "1:1", model: str = "gemini-2.5-flash-image") -> Path:
    from google import genai
    from google.genai import types

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        sys.exit("Error: GEMINI_API_KEY environment variable is not set.")

    client = genai.Client(api_key=api_key)

    print(f"Sending to Gemini ({model})…")
    print(f"  Prompt : {prompt}")
    print(f"  Ratio  : {aspect_ratio}")

    # Gemini image-generation models use generateContent with response_modalities
    response = client.models.generate_content(
        model=model,
        contents=prompt,
        config=types.GenerateContentConfig(
            response_modalities=["IMAGE", "TEXT"],
        ),
    )

    image_bytes = None
    for part in response.candidates[0].content.parts:
        if part.inline_data and part.inline_data.mime_type.startswith("image/"):
            image_bytes = part.inline_data.data
            break

    if image_bytes is None:
        sys.exit("Error: Gemini returned no image in the response.")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(image_bytes)
    print(f"  Saved  : {output_path}")
    return output_path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate sprite sheets / game art via Gemini Imagen.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "prompt_pos",
        nargs="?",
        metavar="PROMPT",
        help="Image description (positional shorthand).",
    )
    parser.add_argument("--prompt", "-p", help="Image description.")
    parser.add_argument(
        "--out",
        "-o",
        default=None,
        help="Output filename inside godot/sprites/ (default: generated_sprite.png).",
    )
    parser.add_argument(
        "--ratio",
        "-r",
        default="1:1",
        choices=["1:1", "3:4", "4:3", "9:16", "16:9"],
        help="Aspect ratio (default: 1:1).",
    )
    parser.add_argument(
        "--style",
        "-s",
        choices=list(STYLE_PRESETS.keys()),
        default=None,
        help="Optional style preset prepended to prompt: " + ", ".join(STYLE_PRESETS),
    )
    parser.add_argument(
        "--list-ratios",
        action="store_true",
        help="Print supported aspect ratios and exit.",
    )
    args = parser.parse_args()

    if args.list_ratios:
        print("Supported aspect ratios: 1:1  3:4  4:3  9:16  16:9")
        return

    raw_prompt = args.prompt or args.prompt_pos
    if not raw_prompt:
        parser.error("Provide a prompt as a positional arg or via --prompt.")

    prompt = build_prompt(raw_prompt, args.style)
    out_name = args.out or "generated_sprite.png"
    output_path = GODOT_SPRITES / out_name

    generate(prompt, output_path, args.ratio)


if __name__ == "__main__":
    main()
