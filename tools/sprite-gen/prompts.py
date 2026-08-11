#!/usr/bin/env python3
"""
Compose the hardened sprite prompts from godot/sprites/SPRITE_PROMPTS.md.

The first generation pass hand-pasted prompts, which is how the murloc ended up
as four different creatures and how the words HURT / DEATH / Wind-Up / Launch /
Recovery got baked into the sprite pixels. This module builds every prompt from
one source of truth instead:

    prefix + sheet body (with the Identity Lock spliced in) + negative suffix

Usage:
    python3 tools/sprite-gen/prompts.py <character> <sheet>
    python3 tools/sprite-gen/prompts.py murloc reference
    python3 tools/sprite-gen/prompts.py --list
"""

import sys

PREFIX = (
    "HD 2D pixel art, Octopath Traveler visual style, 3/4 top-down isometric "
    "perspective (camera looking down at roughly 30 degrees from the side), "
    "hard 1-pixel black outline on all edges, flat cel shading with exactly "
    "3-4 color values per area (no gradients), clean readable silhouette, "
    "dark warm fantasy color palette, pure white background"
)

# The clause that stops baked-in text and non-white backdrops. Both failures in
# the first pass were caused by the prompts themselves asking for labels.
NEGATIVE = (
    "Absolutely no text anywhere in the image: no labels, no captions, no "
    "titles, no frame numbers, no watermarks, no annotations, no arrows. No "
    "panel borders, no grid lines, no boxes or frames drawn around the "
    "sprites. No drop shadows on the background. Background must be pure flat "
    "white (#FFFFFF) everywhere - no gray, no checkerboard, no transparency "
    "pattern, no gradient, no vignette. Exactly one character in the image, "
    "repeated once per animation frame and nothing else."
)

# Restated verbatim in every sheet prompt. The repetition is the mechanism that
# holds the character on-model across separate Gemini calls.
LOCK = {
    "murloc": (
        "amphibious fish-humanoid, medium build, teal blue-green iridescent "
        "scales, large bulging yellow eyes, wide gaping mouth with small "
        "teeth, webbed hands, tall spiny dorsal fin crest along the back and "
        "head, crude barnacled chest guard, barbed trident always in hand"
    ),
    "skeleton": (
        "undead humanoid skeleton, yellowed cracked bones, rusted plate "
        "greaves, corroded breastplate, chipped longsword, cracked kite shield "
        "with skull emblem, empty glowing blue eye sockets, no cape, no "
        "horned helmet"
    ),
    "orc": (
        "large muscular green-skinned orc, broad shoulders, prominent lower "
        "jaw with upward-curved tusks, spiked iron pauldron on the left "
        "shoulder, thick leather belt, crude iron greaves, battle axe in main "
        "hand, serrated cleaver in offhand"
    ),
    "troll": (
        "tall lanky blue-purple troll, hunched posture, long arms, wild dark "
        "mane of hair, two long curved tusks, tribal bone-studded leather, "
        "three throwing axes on belt"
    ),
    "necro": (
        "robed human spellcaster, tattered dark-purple hooded robe with bone "
        "and skull motifs on the hem, gaunt pale face, skeletal staff with "
        "glowing green orb, floats slightly off the ground, purple-black "
        "energy wisps from fingertips"
    ),
    "gormaul": (
        "enormous two-headed ogre, each head different (one snarling, one dim "
        "grin), mountain of muscle, grey-brown warty skin, crude iron crown, "
        "massive riveted iron pauldrons, tattered war-banner on back, "
        "colossal spiked warhammer"
    ),
}

DISPLAY = {
    "murloc":   "Murloc Raider",
    "skeleton": "Scourge Skeleton",
    "orc":      "Orc Grunt",
    "troll":    "Troll Headhunter",
    "necro":    "Cultist Necromancer",
    "gormaul":  "Gor'maul the Warlord",
}

# frame px, single-row canvas, hurt-death canvas
SIZE = {
    "murloc":   (64,  "192x64",  "320x128"),
    "skeleton": (96,  "288x96",  "480x192"),
    "orc":      (96,  "288x96",  "480x192"),
    "troll":    (96,  "288x96",  "480x192"),
    "necro":    (96,  "288x96",  "480x192"),
    "gormaul":  (192, "576x192", "960x384"),
}

# Pose descriptions only. No word here may be one we'd mind seeing drawn.
BODY = {
    "murloc": {
        "ref":    "standing at rest / mid-stride walking / trident thrust",
        "idle":   "All 3 frames show the same standing-at-rest pose, feet planted "
                  "in the same spot, trident held upright at its side; only the "
                  "dorsal fin flick and a small breathing weight-shift differ "
                  "between them. Do not walk, do not attack, do not lunge.",
        "walk":   "Waddling forward with trident raised, moving toward lower-left.",
        "attack": "First frame the trident is pulled back beside the hip; second "
                  "frame the trident is thrust out at full arm extension; third "
                  "frame the trident is lowered and the body is settling.",
        "hurt":   "the creature stumbling backward, still standing",
        "death":  "the creature collapsing to the ground and going still",
    },
    "skeleton": {
        "ref":    "standing at rest / mid-stride walking / sword raised overhead",
        "idle":   "All 3 frames show the same standing-at-rest pose, feet planted "
                  "in the same spot, sword low and shield at its side; only a "
                  "slight sword sway and jaw rattle differ between them. Do not "
                  "walk, do not attack, do not lunge.",
        "walk":   "Stalking forward with sword raised and shield up, moving toward lower-left.",
        "attack": "First frame the sword is raised overhead; second frame the "
                  "sword cuts down diagonally with a motion streak; third frame "
                  "the shield is back at guard.",
        "hurt":   "the skeleton staggering backward, still standing",
        "death":  "the skeleton collapsing as its bones scatter across the ground",
    },
    "orc": {
        "ref":    "standing at rest / mid-stride walking / axe raised overhead",
        "idle":   "All 3 frames show the same standing-at-rest pose, feet planted "
                  "in the same spot, both weapons held low; only the breathing "
                  "chest rise and a small weapon shift differ between them. Do "
                  "not walk, do not attack, do not lunge.",
        "walk":   "Heavy stomping forward with both weapons ready, moving toward lower-left.",
        "attack": "First frame the axe is raised high behind the head; second "
                  "frame the axe chops down through the target with force lines; "
                  "third frame the orc is upright again with the cleaver raised.",
        "hurt":   "the orc staggering backward, still standing",
        "death":  "the orc stumbling, dropping its weapons, and crashing to the ground",
    },
    "troll": {
        "ref":    "standing at rest / mid-stride loping / throwing arm cocked back",
        "idle":   "All 3 frames show the same standing-at-rest pose, feet planted "
                  "in the same spot, arms loose at its sides; only a body sway "
                  "and tusk bob differ between them. Do not walk, do not throw, "
                  "do not lunge.",
        "walk":   "Loping forward with the throwing arm loose at its side, moving toward lower-left.",
        "attack": "First frame the arm is cocked back behind the head gripping a "
                  "throwing axe; second frame the arm swings forward and the axe "
                  "leaves the hand; third frame the arm is extended forward and "
                  "the hand is empty.",
        "hurt":   "the troll recoiling but staying upright",
        "death":  "the troll slowly sinking to the ground and going still",
    },
    "necro": {
        "ref":    "floating at rest / gliding forward / staff raised with energy gathering",
        "idle":   "All 3 frames show the same floating-at-rest pose, hovering in "
                  "the same spot, staff held upright at its side; only the robe "
                  "drift and the orb's glow pulse differ between them. Do not "
                  "glide forward, do not cast, do not lunge.",
        "walk":   "Drifting forward without leg movement, robes billowing, moving toward lower-left.",
        "attack": "First frame the staff is raised and green energy gathers at "
                  "the orb; second frame a shadow bolt streaks forward from the "
                  "orb with a dark green trail; third frame the staff is lowered "
                  "and the robes settle.",
        "hurt":   "the necromancer recoiling as the orb flickers",
        "death":  "the necromancer drifting upward, then crumpling and dissolving "
                  "as the empty robe collapses to the ground",
    },
    "gormaul": {
        "ref":    "standing at rest / striding forward / roaring with arms spread",
        "idle":   "All 3 frames show the same standing-at-rest pose, feet planted "
                  "in the same spot, warhammer resting head-down on the ground; "
                  "only the slow turn of both heads and the deep breathing chest "
                  "rise differ between them. Do not walk, do not swing, do not lunge.",
        "walk":   "Ground-shaking heavy stomp forward, warhammer dragging, "
                  "war-banner swaying, moving toward lower-left.",
        "attack": "First frame the warhammer is hoisted overhead in both hands; "
                  "second frame the warhammer smashes into the ground and a "
                  "shockwave cracks the floor at its base; third frame the ogre "
                  "is hunched over the hammer breathing heavily.",
        "hurt":   "the ogre stumbling backward while roaring, still standing",
        "death":  "the ogre swaying, dropping the warhammer, both heads lolling, "
                  "crashing to its knees, and collapsing face-first",
    },
}

MOVE_NAME = {"attack": {"murloc": "trident thrust", "skeleton": "sword slash",
                        "orc": "axe chop", "troll": "axe throw",
                        "necro": "spell cast", "gormaul": "warhammer slam"}}

SHEETS = ["reference", "idle", "walk", "attack", "hurt-death"]


def build(character: str, sheet: str) -> str:
    name = DISPLAY[character]
    lock = LOCK[character]
    body = BODY[character]
    px, row_canvas, hd_canvas = SIZE[character]

    # Gor'maul drifted into a single-headed ogre on three of four sheets, so its
    # sheets carry an extra per-frame reminder that both heads must be present.
    extra = (" - both heads present in every frame"
             if character == "gormaul" else "")

    if sheet == "reference":
        core = (
            f"character reference sheet, 3 poses in one horizontal row "
            f"({body['ref']}). {name}: {lock}. "
            f"Each pose {px}x{px} px, total canvas {row_canvas}."
        )
        if character == "gormaul":
            core += " Three times regular enemy size, boss-tier threat presence."
    elif sheet == "hurt-death":
        core = (
            f"{name}, one image containing two horizontal rows of sprites on a "
            f"pure white background. {name}: {lock}. "
            f"Top row: 2 frames ({px}x{px}) of {body['hurt']}. "
            f"Bottom row: 5 frames ({px}x{px}) of {body['death']}. "
            f"Total canvas {hd_canvas}. "
            f"The frames are separated by empty white space only - do not draw "
            f"any rectangle, box, outline, divider or border around or between "
            f"the frames, and do not lay the sprites out in a table or grid of "
            f"cells. Nothing but the character on white. "
            f"Identical character in all 7 frames{extra}. 3/4 isometric."
        )
    else:
        label = MOVE_NAME["attack"][character] if sheet == "attack" else sheet
        kind = f"3-frame {label} animation" if sheet != "walk" else "3-frame walk cycle"
        core = (
            f"{name}, {kind}, horizontal sprite sheet, {px}x{px} px per frame, "
            f"total {row_canvas}, thin white gap between frames. "
            f"{name}: {lock}. {body[sheet]} "
            f"Identical character in all 3 frames{extra}. 3/4 isometric."
        )

    return f"{PREFIX} - {core} {NEGATIVE}"


def main() -> None:
    if len(sys.argv) == 2 and sys.argv[1] == "--list":
        print("characters:", " ".join(LOCK))
        print("sheets:    ", " ".join(SHEETS))
        return
    if len(sys.argv) != 3:
        print(__doc__.strip())
        sys.exit(1)
    character, sheet = sys.argv[1], sys.argv[2]
    if character not in LOCK:
        print(f"unknown character '{character}' (have: {', '.join(LOCK)})")
        sys.exit(1)
    if sheet not in SHEETS:
        print(f"unknown sheet '{sheet}' (have: {', '.join(SHEETS)})")
        sys.exit(1)
    print(build(character, sheet))


if __name__ == "__main__":
    main()
