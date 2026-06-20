# Barony of Azeroth — Godot 4.7 port

A migration of the single-file HTML game (at the repo root) into a real 3D
Godot project. The HTML version remains the source of truth for game design;
this folder rebuilds it in Godot with true 3D rendering.

## Open it
Open `godot/project.godot` in **Godot 4.7**. Press F5 to run.

## Status — milestone 1 (foundation, validated headless)
- `project.godot` — input map (WASD/mouse/abilities), autoloads, GL-compatibility renderer
- Autoload data, ported 1:1 from the web build and checked against it:
  - `Classes` (`scripts/data/ClassDB.gd`) — all six heroes + projectile/AoE/melee tables
  - `Bestiary` (`scripts/data/EnemyDB.gd`) — all seven enemies + per-depth spawn tables
- `Dungeon.gd` — the procedural generator, ported from `genLevel()`; deterministic
  from a seed (verified: same seed → identical floor, different seed → differs)
- `Painter.gd` / `SpriteFactory.gd` — a CPU rasterizer that mirrors the web canvas
  helpers (`S/shp/rrect/ell/tri/dot`), so the chunky Warcraft-style art ports across;
  renders to `Image` (works headless, unit-testable)

Run the headless self-tests:
```
godot --headless --path godot --gametest
```

## Next milestones
2. 3D world build (walls/floor/ceiling mesh + torch lighting) and a first-person
   player controller — a walkable dungeon.
3. Combat: billboard enemies + AI, the six classes' primary attacks and Q/B abilities.
4. Items, inventory, the goblin shop, the boss, win/lose.
5. Co-op multiplayer (Godot high-level networking).
