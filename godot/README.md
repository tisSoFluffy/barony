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

## Status — milestone 2 (walkable 3D dungeon)
- `World.gd` — builds the floor/ceiling + instanced walls (MultiMesh visual +
  StaticBody collision) and torch `OmniLight3D`s from a generated floor
- `Player.gd` — first-person `CharacterBody3D`: WASD move, mouse-look, arrow turn,
  Esc to free the cursor
- `Game.gd` — generates a floor, builds the world, populates it with billboard
  enemies/items drawn from the ported art, dim ambient + torchlight
- `Main.gd` — a class-select menu (six heroes) that starts a run; press F5
- Verified headless (`-- --play war`): world builds ~890 wall blocks + 19 actor/item
  billboards, the player spawns and physics runs clean

## Next milestones
3. Combat: enemy AI (chase/attack/ranged), the six classes' primary attacks and
   Q/B abilities, damage/death, XP & leveling, hunger.
4. Items & interaction: pickups, inventory, the goblin shop, stairs/descent, the
   ogre boss, win/lose, the Hall of Heroes.
5. Co-op multiplayer (Godot high-level networking / WebRTC).
