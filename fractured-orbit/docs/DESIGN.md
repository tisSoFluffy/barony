# Fractured Orbit: The Echoes — Design & Implementation Map

A 3D **Rogue-Vania** aboard the research vessel *Aethelgard*. Roguelike
permadeath + procedural rooms, wrapped around a metroidvania spine of
ability-gated, interconnected vertical sectors. Low-poly brutalist sci-fi.

## Pillars
1. **Vertical progression (vania).** Five stacked sectors, each opened by one
   permanent traversal gate. Gates, tech, and map progress persist across runs.
2. **Replayable loops (rogue).** Room *content* is generated per run and gets
   denser/harder as the loop counter climbs ("The Glitch"). Death resets the run.
3. **Failure as story (echoes).** Where you died is remembered — debris and a
   ghost-note reappear there in every later run.
4. **Charming low-poly.** Faceted brutalist slabs, area lighting + long shadows,
   cube-explosion particles. Complexity hidden under a minimalist skin.

## The five sectors

| # | Sector | Gate (unlocks) | Signature hazards | Enemies | Boss |
|---|--------|----------------|-------------------|---------|------|
| 0 | Docking Bays | **Magnet Boots** — ride magnetic pillars up | falling crates, crumbling walkways | Scrap-Crawlers | — |
| 1 | Hydroponics | **Wall-Run Climb** — run the living roof | spore clouds, thorn walls | Silence-Touched Guards | — |
| 2 | Engineering Core | **Kinetic Charge** — shatter laser barricades | laser grids, pressure plates, molten floor | Drone Swarms, Turret Spiders | Core Guardian (splits) |
| 3 | Void Silo | **Zero-G Anchor** — tether across zero-G | zero-G pockets, black-hole pits | Void Leapers | — |
| 4 | Event Horizon | **Reality Bender** — rewrite room geometry | reality rifts, mirror rooms | Memory Constructs | The Original NEXUS |

Tech-tree carry-overs reshape hazards rather than gate progress: **Spore
Purifier** (spore cloud → harmless fog), **Hacking Spike**, **Time Dilation**,
**Noise Canceller**, **Gravity Manipulator**, **Warp Jump**.

## The rogue-vania loop
```
enter sector (safe zone) ─▶ fight/traverse rooms ─▶ reach the GATE room
      ▲                                                      │
      │ die → record ECHO, +1 loop, harder gen          find + attune the gate
      │                                                      │
   rebuild sector ◀── NEXUS 10-min reset ◀── use the gate to reach the lifted EXIT ─▶ ascend
```

## The Procedural Glitch (generation rule)
- **Skeleton is fixed** so the player always knows the goal: every sector = a
  safe entrance → a run of rooms → the gate-challenge room → a lifted exit.
- **Content is random** inside that skeleton (props, hazards, enemies, extra
  platforms), seeded from `(run_seed, sector, loop_index)` → reproducible.
- **Later loops are hostile**: `SectorGen.difficulty(loop)` raises enemy/hazard
  counts and spawns multi-platform obstacle courses.

## Story arc (three acts)
- **Act I — The Descent.** Learn the loop; death carries inventory forward.
- **Act II — The Glitch.** Generation turns hostile; you learn *you* are the
  virus the world rejects. Earn reality-warping powers.
- **Act III — The Core.** Fight NEXUS. Endings: **Save the ship** (fragile
  peace) · **Transcendence** (merge with NEXUS) · **The Loop** (jump into the
  singularity — true permadeath, the simulation collapses).

## Concept → code map

| Design idea | Where it lives |
|---|---|
| 5 sectors, palettes, hazard/enemy/gate tables | `scripts/data/SectorDB.gd` |
| 5 gates + tech tree (pure data) | `scripts/data/AbilityDB.gd` |
| Procedural-glitch generator (skeleton + random content) | `scripts/SectorGen.gd` |
| Walkable 3D geometry, lighting, prop/hazard/enemy spawn, echoes | `scripts/Sector.gd` |
| Low-poly primitives + generated-model placeholder swap | `scripts/MeshFactory.gd` (`Forge`) |
| Cross-run persistence: gates, tech, reached, loops, echoes | `scripts/MetaSave.gd` (`Meta`) |
| Ability-gated FPS platformer controller | `scripts/Player.gd` |
| Enemy chase/attack AI | `scripts/Enemy.gd` |
| Hazard behaviors (laser pulse, spore DoT, etc.) | `scripts/Hazard.gd` |
| Run manager: 10-min reset, death→echo→rebuild, sector advance, endings | `scripts/Game.gd` |
| HUD: integrity, loop timer, gate roster, notices, end screens | `scripts/ui/HUD.gd` |
| Menu + headless self-tests | `scripts/Boot.gd` |
| Deterministic seeded RNG | `scripts/Util.gd` (`Util`) |

## The NEXUS fight & endings (Event Horizon)
NEXUS cannot be brute-forced. It is **shielded** while an attack pattern runs;
the **Reality Bender** gate (F, near the boss) deletes the active pattern and
opens a short window in which your **kinetic strike** (LMB) reaches the core.
The loop chains the kit: dodge → rewrite → strike, three times, each pattern
faster than the last (aimed volley → radial ring → fast triple).

On the break, the **three endings** (`Game._show_endings`):
- **Path A — Save the Ship:** restore NEXUS; fragile peace.
- **Path B — Transcendence:** merge with NEXUS; escape as a digital god.
- **Path C — The Loop:** jump into the singularity — **true permadeath**, the
  save is wiped and a fresh loop begins.

## Status (vertical slice)
Implemented and **validated headless** (`--gametest`, `--play 0..4`): all five
sectors generate deterministically, build walkable 3D space, spawn the
Loop-Walker, and step physics; gates lock/unlock and persist; deaths record
echoes that reappear as debris; the 10-minute reset and sector advancement run;
the **NEXUS boss** (shield → strip → strike) is beatable and gates the exit; the
**three-ending choice** resolves (Path C wipes the save); the **glitch shader**
skins Event Horizon walls.

Not yet built (next milestones): the Core Guardian's split-on-hit behavior, co-op,
audio, richer enemy variety, and the art pass (replacing placeholders via the
ComfyUI pipeline — see [`COMFYUI_ASSET_PROMPTS.md`](COMFYUI_ASSET_PROMPTS.md)).
