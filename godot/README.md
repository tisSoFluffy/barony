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

## Status — milestone 3 (combat)
- `Enemy.gd` — chase/attack AI: wakes on sight + line-of-sight, melees in range,
  ranged types (troll/necro) keep distance and fire projectiles; hit-flash + death
- `Projectile.gd` — fireball/arrow/bolt with pierce + lifesteal (heals the caster)
- `Player.gd` — full combat: per-class primary (melee / projectile), F secondary,
  Q ability (AoE or multishot), B mobility (dash/blink/charge/shield), resource
  costs + regen, damage/block/i-frames, death, XP & leveling
- `HUD.gd` — health & resource bars, crosshair, floating messages, damage flash,
  the first-person weapon view (bob + swing), and a death screen
- Menu fixed (centered). Verified headless: enemies damage the player, melee &
  abilities kill enemies and grant XP, all six weapon views render

## Status — milestone 4 (items, economy, descent, boss)
- `GearDB.gd` — randomized gear rolls (3 tiers, affixes), ported from `rollGear`
- Pickups: walk over gold/potions/meat/gear/keys to collect; consumables on
  H / M / G; a hunger meter that drains and bites when empty
- `InventoryUI.gd` (press **I**) — equip slots + 6-slot bag, click to equip /
  right-click to drop, with live total stats; gear bonuses feed `tot_*`
- `ShopUI.gd` — Gazlowe the goblin merchant: press **E** to buy potions/meat
  and a featured gear piece (prices scale with depth)
- **E** also uses stairs (descend + rebuild the next floor), shrines (random
  blessing/curse), and the boss portal
- The Ogre **boss** on depth 5: enrages at half health and calls reinforcements;
  on death drops a portal home — step in to win
- Win/lose screens + the persistent **Hall of Heroes** (`Scores.gd`, shown on the
  title menu)
- Verified headless: pickups, equip changes stats, shop buys, descent, boss →
  portal → victory, and scores persist

## Next milestone
5. Co-op multiplayer (Godot high-level networking / WebRTC).
