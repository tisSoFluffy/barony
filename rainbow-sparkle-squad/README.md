# Rainbow Sparkle Squad

A pastel toybox playground for Godot 4.7. Swap between **Bouncy Blue** (the
cube unicorn) and **Spotty Doggy**, collect sparkles across the meadow, and
open the castle gate. Built for a controller.

![the meadow](../out/rss_shot.png)

## Running it

Godot is not on PATH on this machine — it lives in a folder named like an exe:

```bash
GODOT="/c/Users/joshu/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe"
"$GODOT" --path rainbow-sparkle-squad          # play
```

Use `Godot_v4.7-stable_win64_console.exe` for anything headless — the plain exe
detaches from the console and you will not see `print()` output.

## Controls

Gamepad is the primary input; keyboard bindings exist so the game is testable
without one plugged in.

| Action | Controller | Keyboard |
|---|---|---|
| Move | Left stick (analog) | `WASD` |
| Camera | Right stick | Arrow keys |
| Jump / double jump | `A` | `Space` |
| Swap character | `X` | `Q` |
| Dash (Spotty only) | `RT` | `Shift` |
| Restart | `Back` / `Select` | `R` |

Movement is camera-relative and keeps analog magnitude, so a light stick push
walks and a full push runs. Jump has coyote time (0.12 s) and an input buffer
(0.15 s) so it stays responsive at ledges.

## The two characters

Neither model is rigged, so the difference between them is entirely movement
feel — see `scripts/Cast.gd`, which is plain data.

- **Bouncy Blue** — slower, but jumps higher, falls at 72% gravity and gets a
  second mid-air hop. Built for the sparkles parked on top of the arches.
- **Spotty Doggy** — faster on the ground with a dash on `RT`, but only one
  jump and normal gravity.

## No rigs, so the animation is procedural

There are no bones and no animation clips anywhere in this project. Everything
that makes the characters feel alive is computed in `Player._animate()`:

- a **spring-driven squash/stretch** that stretches tall on takeoff, flattens
  on landing in proportion to impact speed, and pops on a character swap;
- a **hop bob** while running, scaled by actual speed, with an extra squash at
  the bottom of each step;
- a **lean** into the direction of travel.

The squash is volume-preserving (tall means thin, flat means wide), which is
what makes a rigid cube read as a soft toy. It is applied to a `Visual` child
node so the collision capsule is never distorted.

## Asset pipeline

The models come from ComfyUI TRELLIS.2 as ~500k-triangle Y-up GLBs. Turn a raw
export into a game asset with:

```bash
.venv/Scripts/python.exe rainbow-sparkle-squad/tools/import_assets.py
"$GODOT_CONSOLE" --headless --path rainbow-sparkle-squad --import
```

`tools/import_assets.py` does four things, and each one is load-bearing:

1. **Strip specks.** Every export carries 30–50k triangles of disconnected
   noise. Removing it first also lets the decimator collapse much further,
   since each speck otherwise pins boundary edges in place. The same pass
   drops welded floor discs, though these particular concepts were generated
   on plain backgrounds and have none.
2. **Decimate** to roughly 15k triangles.
3. **Re-atlas and bake.** This is the subtle one. TRELLIS packs its texture as
   dozens of small charts; decimation collapses vertices across chart borders,
   so a single low-poly triangle ends up with corners in unrelated parts of the
   sheet and smears a bright streak across itself. Measured on the rainbow
   arch, the worst triangle stretched **1900×**, and still **2.4×** at only
   half the original density — there is no reduction level at which reusing the
   original UVs is safe. So the decimated mesh gets a fresh xatlas unwrap and
   the original's appearance is baked into it texel by texel, with 6 texels of
   edge dilation so bilinear filtering never picks up the background.
4. **Force the material matte.** TRELLIS writes `metallicFactor = 1.0` and
   relies on a metallic-roughness *texture* to pull it back down; that texture
   does not survive the round trip, so every asset arrives as a perfect mirror
   and reflects the sky as a milky haze over the whole scene.

`tools/preview.py` renders a contact sheet of the processed GLBs with a plain
numpy rasteriser, which is faster than opening the editor when you just want to
know whether an asset came out the right shape.

## Checking it still works

```bash
"$GODOT_CONSOLE" --path rainbow-sparkle-squad -s tools/playtest.gd
"$GODOT_CONSOLE" --path rainbow-sparkle-squad -s tools/shoot.gd -- 200 shot.png
```

`playtest.gd` drives synthetic input and asserts the verbs actually work —
movement, jump-and-land, swapping, collecting, the gate opening. It exits
non-zero on failure. Its schedule is in **seconds, not frames**: headless runs
idle frames as fast as the machine allows while physics stays pinned at 60 Hz,
so a frame counter fires the checks long before the character has moved.

`shoot.gd` builds the scene, reports what got created, and saves a screenshot.

## Layout

```
assets/models/     processed GLBs (committed; regenerate with import_assets.py)
scenes/Main.tscn   a bare Node3D with Game.gd attached
scripts/
  Game.gd          builds the world, owns the win condition
  Cast.gd          the two characters, as data
  Player.gd        movement + procedural animation
  FollowCamera.gd  right-stick orbit camera with obstruction pull-in
  Models.gd        GLB loading and auto-fit
  Sparkle.gd  BouncePad.gd  Gate.gd  HUD.gd
tools/             asset pipeline and headless checks
```

The world is built in code rather than authored as a scene, so the level layout
reads as plain arrays at the top of `Game.gd` and there is no `.tscn` to drift
out of sync with the scripts.

## Known rough edges

- The rainbow arch's texture is banded and blotchy. That is faithful to the
  generation — the source atlas genuinely looks like that — not a pipeline bug.
  It needs regenerating rather than reprocessing.
- Decimation bottoms out around 15k triangles per asset rather than the 4–6k
  requested; `fast_simplification` stops collapsing before the target. Fine at
  this scale (~85k triangles for the whole level) but worth revisiting.
- `sparkle_cubes` is a scatter cloud, so one pickup is a cluster of small cubes
  rather than a single readable coin. It works, but a dedicated gem model would
  read better.
- **Spotty Doggy has the ball fused to her front paws.** The concept image had
  the ball resting against the dog, and the generator reconstructed the two as
  one solid object. It is a single connected component, so the speck/floor pass
  cannot separate it — it needs either a regenerated concept with the ball
  removed, or a manual cut in Blender.
- No audio yet.
