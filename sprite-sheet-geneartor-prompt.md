 I am attaching the existing sprite sheet for reference. You must match the
  pixel art style, character design, color palette, and frame size EXACTLY
  from the reference image. Do not change the art style.

  Create a NEW sprite sheet with 8-directional walk animations using the
  SAME character, SAME pixel art style, SAME size per frame.

  SHEET LAYOUT: 4 columns × 7 rows = 28 frames
  Frame size: match the existing sprite's per-frame pixel dimensions exactly.
  Total sheet = 4 frames wide × 7 rows tall.
  Transparent background — alpha = 0 everywhere there is no character.
  Export as PNG with full alpha. Do NOT use grey or checkerboard for empty
  areas — those pixels must be alpha = 0.

  ROW CONTENTS (each row = 4 frames of animation):

  Row 0 — Walk SOUTH: Character faces directly toward the viewer, walking
    in place. See their face and chest. Arms and legs cycle naturally.
    4-frame loop.

  Row 1 — Walk SOUTHWEST: 3/4 front-left angle. Viewer sees the left side
    of the face and partial chest. 4-frame loop.

  Row 2 — Walk WEST: Pure side view, character walks to the LEFT.
    This is the same angle as the existing reference sprite. 4-frame loop.

  Row 3 — Walk NORTHWEST: 3/4 back-left angle. Viewer sees the back-left
    of the character. 4-frame loop.

  Row 4 — Walk NORTH: Character faces directly away from viewer, walking
    away. See only the back. 4-frame loop.

  Row 5 — Attack SOUTH: Character faces viewer and performs their attack
    (4 frames: wind-up, strike, follow-through, recovery). Does not loop.
    [WEAPON/ATTACK TYPE: see per-enemy table below]

  Row 6 — Hurt + Dead:
    Frame 0 (col 0): Hurt — recoil pose, facing south.
    Frames 1–3 (cols 1–3): Death — collapse sequence.

  ANIMATION RULES:
  - Walk cycles must loop cleanly (frame 3 flows back to frame 0).
  - The character's feet should land near the bottom edge of each frame.
  - The character should be horizontally centered in every frame.
  - Maintain weapon/accessory visibility across all 5 walk directions.
  - The 5 walk angles should feel like the same character rotating —
    consistent silhouette, colors, and proportions.
