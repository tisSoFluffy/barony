# Rainbow Sparkle Squad

A pastel toybox playground for Godot 4.7. Swap between **Bouncy Blue** (the
cube unicorn) and **Spotty Doggy**, collect sparkles across the meadow, and
open the castle gate. Built for a controller.

There is also a **star counting trail**: ten plush stars numbered 1–10 strung
in a loop around the meadow, each on the ground and reachable on foot. Running
the lap and picking them all up bumps the `Stars N / 10` tally in the corner —
a gentle counting game layered on top of the sparkle hunt. See `scripts/Star.gd`
and `STAR_SPOTS` in `scripts/Game.gd`; the `star.glb` model came through the
same Flux → TRELLIS2 → `tools/import_assets.py` pipeline as everything else.

**Ms. Bumbleflower** the bunny lives here too. She is not a collectible and not
an obstacle — she is company. A small wander brain in `scripts/Bunny.gd` picks
somewhere to go and she hops there in real ballistic arcs (gravity draws the
curve, not a tween), pausing between hops so the rhythm reads as an animal.
Get within about three metres and she spooks and bounds away, which is what
makes her worth chasing. Like every other character she is unrigged, so the
squash on landing, the stretch on takeoff and the nose-down lean through the
arc are all computed in `Bunny._animate()`. `tools/bunnytest.gd` is her test —
it watches her wander, then crowds her and checks she bolts.

A **butterfly** does laps of the flowers — and she is the one rigged character
in the project. Everything else is a single unrigged shell moved as a whole
body, which is fine for a hop or a squash but cannot beat a wing: the two wings
have to swing in opposite directions about the body, and no whole-object
transform does that. `tools/rig_butterfly.py` gives her a three-bone skeleton
(`Body`, `Wing_L`, `Wing_R`) in Blender and exports a skinned glTF that Godot
imports as a `Skeleton3D`; `Butterfly._flap()` then rolls each wing bone about
its own length. Her flight is still procedural — a steered heading with a weave
on it, a slow altitude bob, and a bank into her turns. Her waypoints are pulled
straight out of `DECOR`, so she visits whatever flowers are actually planted.

Weights are assigned by hand rather than by bone heat: a butterfly's wings meet
the body over a broad seam and nearly touch each other, and the automatic
solver bleeds one wing's influence across the midline, so beating the left wing
drags the right. Weighting purely on distance from the body's centre plane is
exact and symmetric by construction. `tools/butterflytest.gd` guards the whole
chain — if the rig ever exports unskinned, the wings go stiff and nothing else
would notice.

## Blockland

A glowing doorway stands in the meadow. Walk into it and the screen wipes to a
plaza where the ten **Numberblocks** are waiting — the number N built out of N
cubes, with a face on the front.

These are the only characters in the project that are **not** generated, and
deliberately so. A Numberblock is literally a stack of unit cubes, so building
one from `BoxMesh` in code is more faithful than anything image-to-3D would
give us — and it means the shape carries the maths. Four really is four cubes,
and you can count them. The arrangement follows the toy: small numbers are
single towers, and the ones that factor neatly become rectangles — 6 is 2×3,
8 is 2×4, 9 is 3×3, 10 is 2×5. Seven is the rainbow one, a colour per cube.

**The game.** The blocks stand in a shuffled arc and you have to touch them in
order, one to ten. A right answer lights the block up and says its number, in
the same voice the star trail uses. A wrong one shakes it and puts the whole
row out again — which is the point: you have to know what comes next, not just
barge around. Ten in a row and they do a wave.

Blockland is built far off to one side of the meadow rather than in a scene of
its own, and the doors teleport between the two. One scene means the player,
camera, HUD and audio are never torn down and rebuilt, so there is no reload
hitch and nothing to re-wire on the way back. `tools/blocklandtest.gd` walks
the door, counts correctly, deliberately gets one wrong, and checks the row
resets.

## Shape Cove

A second door, blue this time, leads to a sand island ringed by water where the
six shapes live — **circle, square, triangle, rectangle, star and heart** — each
a chunky standing slab with a face.

Like the Numberblocks these are built in code, and for the same reason: a
circle has to be a real circle and a triangle three real sides, or the thing
being taught is wrong. Generated geometry cannot promise that. Every figure
comes out of **one** extrusion routine applied to a 2D outline, so the whole set
shares a thickness and a look, and adding a shape means adding a list of points
and nothing else. Normals are set explicitly rather than generated — a
generated normal at a sharp star point averages the two faces either side of it
and rounds off exactly the corner that makes it a star.

**The game.** Blockland teaches *order*; this teaches *recognition*, so the loop
is deliberately different. A round names one shape and you go and touch it.
There is no sequence to remember and no way to fall behind — a wrong answer
costs nothing but another go, and after two wrong guesses the right shape hops
on the spot so nobody can get stuck. Every shape is asked exactly once. Finish
all six and it becomes free play: touch anything to hear its name.

It is built for a player who **cannot read**. The round is spoken —
`tools/make_shape_voices.ps1` renders "Find the triangle!" and the shape names
alongside praise and encouragement — and the text on screen is the backup,
not the other way round. The shapes stay in fixed places between rounds on
purpose: at three, knowing where the star lives is a win worth keeping, and the
puzzle is the name, not the memory.

`tools/shapecovetest.gd` covers the door and plays the game through to the end.
Its geometry checks are the load-bearing ones — a triangle with the wrong number
of sides, or a figure sunk into the sand, is a wrong lesson rather than a
cosmetic bug.

## The meadow

The meadow is **dressed as a unicorn's fantasy world**: a sparkle fountain at
its heart, a treeline of candy-scoop trees, toadstools and crystal clusters
through the mid-field, a flower patch, and puffy clouds bobbing overhead. It is
all pure scenery — one reusable `scripts/Decor.gd` node, laid out as the `DECOR`
array in `scripts/Game.gd`; only the fountain and tree trunks have colliders.
The six models were generated the same way (`toadstool`, `crystal_cluster`,
`candy_tree`, `giant_flower`, `sparkle_fountain`, `cloud_puff`).

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

`tools/import_assets.py` does three things, and each one is load-bearing:

1. **Decimate in Blender, keeping the source UVs** (`tools/blender_decimate.py`,
   shelled out to `blender.exe`). A TRELLIS surface-net mesh is ~11k
   *disconnected* shell fragments. The old path — `fast_simplification` then a
   fresh `xatlas` unwrap and a texel-by-texel re-bake — turned that into ~1500
   confetti UV charts, and the seams between them rendered in-engine as a white
   crackle over every surface. Blender welds the fragments (`remove_doubles`),
   drops degenerate slivers, then runs a **collapse** decimate that carries the
   per-vertex UVs straight through, so the mesh keeps sampling TRELLIS's own
   coherent atlas and nothing is re-baked. Target is ~20–26k triangles.
2. **Load back with `process=False`.** trimesh's default load merges spatially
   close vertices, which fuses the two halves of every UV seam onto one UV
   coordinate and reintroduces exactly the crackle Blender avoided.
3. **Force the material matte.** TRELLIS writes `metallicFactor = 1.0` and
   relies on a metallic-roughness *texture* to pull it back down; that texture
   does not survive the round trip, so every asset arrives as a perfect mirror
   and reflects the sky as a milky haze over the whole scene.

The concepts are generated on plain backgrounds, so there is no welded floor
disc to strip; `strip_floor()` is kept in the module but not run on this path
(it would re-split the mesh on its UV seams and can over-trim).

`tools/preview.py` renders a grey contact sheet of the processed GLBs with a
plain numpy rasteriser; `tools/turntable.gd` is the authoritative check —
it loads one GLB in a real Godot viewport, lights it, and saves a four-angle
textured strip (`--unshaded` to isolate a texture problem from a shading one).

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

- The rainbow arch's outer red band is much thicker than the rest and the
  underside is mostly red — TRELLIS reconstructs it that way from the concept.
  It reads clearly as a rainbow; the band proportions are a stylisation quirk,
  not a pipeline bug. Reroll the TRELLIS seed if it needs to be more even.
- `sparkle_cubes` is a scatter cloud, so one pickup is a cluster of small cubes
  rather than a single readable coin. It works, but a dedicated gem model would
  read better.
- Character bodies carry faint speckle from the TRELLIS texture (freckles on
  the dog, a soft mottle on the unicorn). Small enough to read as toy-plastic
  texture rather than noise.
- No audio yet.
