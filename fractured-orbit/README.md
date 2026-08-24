# Fractured Orbit: The Echoes — Godot project

A 3D **Rogue-Vania** aboard the dying research vessel *Aethelgard*: roguelike
permadeath and procedural rooms wrapped around a metroidvania spine of
ability-gated vertical sectors, in a low-poly **brutalist sci-fi / "Deep Rock
Galactic"** style. You play **Kael, a Loop-Walker**; NEXUS resets the ship every
10 minutes, but your gates, tech and map — and the *echoes* of where you died —
persist across runs.

This is a **separate project** from `../godot` (that's the unrelated *Barony of
Azeroth* port); it only borrows that project's proven conventions (Godot 4.7,
GL-compatibility renderer, autoload data, seeded RNG, headless test harness).

## Open it
Open `fractured-orbit/project.godot` in **Godot 4.x** (built for 4.7; parses and
runs headless clean on 4.3). Press **F5**.

### Controls
`WASD` move · mouse look · `Space` jump · `Shift` dash · `LMB` kinetic strike ·
`F` gate power (context-sensitive) · `E` interact/attune/read-echo · `Esc` free
the cursor.

## Play the loop
1. **Begin the Descent** from the menu (blank seed = random, or type a seed).
2. Cross rooms to the **gate room**, climb the platforms, `E` on the gate device
   to **attune** the traversal power.
3. Use `F` to reach the **lifted exit** and ascend a sector. Without the gate,
   `F` tells you what's missing — that's the metroidvania lock.
4. Die (or let the 10-minute NEXUS clock run out) and the run resets — but you
   keep your gates/tech, and your death leaves an **echo** in the world.

## Validate headless (no display needed)
```
godot --headless --path fractured-orbit --gametest      # self-tests (data, determinism, gen, save)
godot --headless --path fractured-orbit -- --play 0     # build+step a sector (0..4)
godot --headless --path fractured-orbit -- --smoke      # boot check
```
All self-tests pass and all five sectors build and step physics headless. (In
headless the *dummy* renderer prints `Parameter "m" is null` for procedural
meshes — a Godot headless-only artifact, not present under the GL renderer.)

## Architecture (all procedural, zero external art required)

Autoloads: `Util` (seeded RNG) · `Sectors` (SectorDB) · `Abilities` (AbilityDB) ·
`Meta` (cross-run save) · `Forge` (MeshFactory).

| File | Role |
|---|---|
| `scripts/data/SectorDB.gd` | the 5 sectors: palette, hazards, enemies, gate, lore |
| `scripts/data/AbilityDB.gd` | the 5 traversal gates + the tech tree |
| `scripts/SectorGen.gd` | the "Procedural Glitch" — fixed skeleton, random content, scales with loop count |
| `scripts/Sector.gd` | builds walkable 3D geometry, lighting, spawns props/hazards/enemies + death echoes |
| `scripts/MeshFactory.gd` | low-poly primitives **and** the placeholder→generated-model swap |
| `scripts/MetaSave.gd` | persists gates, tech, deepest sector, loop count, echoes |
| `scripts/Player.gd` | ability-gated first-person 3D platformer controller |
| `scripts/Enemy.gd` / `Hazard.gd` | enemy AI / hazard behaviors |
| `scripts/Game.gd` | run manager: reset clock, death→echo→rebuild, sector advance, endings |
| `scripts/ui/HUD.gd` | integrity, loop timer, gate roster, notices, end screens |
| `scripts/Boot.gd` | menu + headless test harness |

See [`docs/DESIGN.md`](docs/DESIGN.md) for the full design and the
concept→code map.

## Art pipeline (placeholders → your models)
The game ships playable on primitives. Generate low-poly models with your local
**ComfyUI** (text → image → 3D → texture) and drop them into
`assets/models/<name>.glb` — the engine swaps each placeholder automatically, no
code changes. Every asset's exact filename and generation prompt is in
[`docs/COMFYUI_ASSET_PROMPTS.md`](docs/COMFYUI_ASSET_PROMPTS.md); the mechanism
is described in [`assets/README.md`](assets/README.md).

## Status
Vertical slice, validated headless. Next: boss scripting, the three-ending
choice, the 2D↔3D glitch shader, audio, and the art pass. Full status in
`docs/DESIGN.md`.
