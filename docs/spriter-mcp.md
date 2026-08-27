# Spriter Pro MCP server

This repo ships a **project-scoped MCP server** (`tools/spriter-mcp/`) that
lets agentic editors build sprite animations with **Spriter Pro** — create
`.scml` projects from part images, author keyframed animations, bake them to
PNG frames or Godot-ready sprite sheets, and open the result in the Spriter
Pro GUI for hand-polish.

Spriter Pro has **no CLI or scripting API**, so the server works at the file
level: it reads and writes Spriter's documented SCML project format directly
and includes its own SCML renderer (bones, spin-aware angle tweening, pivots,
z-order) built on Pillow. Anything authored here opens normally in Spriter
Pro, and anything animated in Spriter Pro can be baked here.

## Prerequisites

- **Python 3.10+** on PATH.
- **Spriter Pro** (Steam) — only needed for the `open_in_spriter` tool and
  for hand-editing; parsing/rendering/exporting work without it.

## One-time setup

The server runs from a local venv (not committed):

```powershell
python -m venv tools/spriter-mcp/.venv
tools/spriter-mcp/.venv/Scripts/python.exe -m pip install -r tools/spriter-mcp/requirements.txt
```

(macOS/Linux: the venv python lives at `tools/spriter-mcp/.venv/bin/python`;
adjust the `command` path in `.mcp.json` accordingly.)

## How it's wired

`.mcp.json` at the repo root:

```json
"spriter": {
  "command": "tools/spriter-mcp/.venv/Scripts/python.exe",
  "args": ["tools/spriter-mcp/server.py"],
  "env": { "SPRITER_PATH": "${SPRITER_PATH:-}" }
}
```

`SPRITER_PATH` is an optional override for the Spriter Pro executable; unset,
the server uses the default Steam install
(`C:\Program Files (x86)\Steam\steamapps\common\Spriter\Spriter.exe`).

Approve the project server the first time Claude Code prompts, then check
`/mcp` — `spriter` should be connected with 14 tools.

## Tools provided (14)

| Tool | Purpose |
|------|---------|
| `list_projects` | Find `.scml` projects under a directory (incl. Spriter's sample Art Packs) |
| `get_project_info` | Images + pivots, entities, animations of a project |
| `get_animation_details` | Full keyframe data for one animation |
| `create_project` | New `.scml` from part PNGs (reads real image sizes) |
| `add_images` | Register more part PNGs in a project |
| `set_pivot` | Set an image's default pivot (rotation/position anchor) |
| `build_animation` | Create/replace an animation from full-pose keyframes |
| `delete_animation` | Remove an animation |
| `render_pose` | Render one frame to PNG — visual check while iterating |
| `render_frames` | Bake an animation to aligned, numbered PNG frames |
| `export_sprite_sheet` | Bake to a grid sheet PNG + JSON sidecar (frame size/count/fps) for Godot |
| `open_in_spriter` | Launch the Spriter Pro GUI on a project |
| `list_docs` | Topics of Spriter Pro's built-in manual (installed with the app) |
| `read_doc` | One manual page as plain text; fuzzy topic match (e.g. `bones`, `pivot`) |

The doc tools read the HTML manual shipped in the Spriter install folder
(`<install>/docs/`) at runtime, so the agent can consult the official
workflow guidance (pivots, bones, keyframing, character maps, export)
without the pages being copied into this repo.

## Typical workflow

1. Get body-part PNGs (e.g. from the sprite pipeline, or Spriter's Art Packs).
2. `create_project` with the parts and sensible pivots (`set_pivot` to adjust —
   pivots are fractions from the image's **bottom-left**; a limb pivots at its
   joint).
3. `build_animation` with full poses: every key lists all sprites with
   `x/y` (y-up), `angle` (degrees CCW), `spin` (tween direction to the next
   key), and `z` draw order. Spriter tweens linearly between keys.
4. `render_pose` at a few times and look at the PNGs; iterate.
5. `export_sprite_sheet` at the game's `scale` into `godot/sprites/` and wire
   it up like any other sheet (the JSON sidecar has frame size, count, fps).
6. Optionally `open_in_spriter` so a human can polish curves/timing in the
   real tool; re-export afterwards — the renderer treats non-linear curve
   types as linear, so exact easing baked in Spriter may differ slightly.

## Format notes / limitations

- Works with **SCML** (Spriter's XML format). `.scon` (JSON) files aren't
  parsed — save as `.scml` from Spriter Pro.
- The renderer supports sprites, bone hierarchies, looping/non-looping
  timelines, spin-aware angle interpolation, per-key pivots, alpha, and
  negative/non-uniform scale. Curve types other than instant/linear are
  approximated as linear; character maps, sounds, and event triggers are
  ignored when rendering.
- `build_animation` authors flat (bone-less) animations; bone rigs made in
  Spriter Pro render fine — they just can't be *authored* through the tool yet.
