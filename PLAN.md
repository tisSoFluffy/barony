# Barony — HD 2D Rebuild Plan

**Style reference**: Octopath Traveler HD 2D  
**Brief**: [tools/yt-ref/briefs/hd2d-octopath-traveler.md](tools/yt-ref/briefs/hd2d-octopath-traveler.md)  
**Engine**: Godot 4

The current project is being rebuilt from scratch with HD 2D as the foundational visual contract. Core game logic (combat, dungeon gen, enemy AI) is ported; rendering, camera, world geometry, and UI are new.

---

## Status Legend
- [ ] Pending
- [~] In progress
- [x] Done

---

## Phase 1 — Foundation
*Get a blank scene that looks like HD 2D before writing any game logic.*

- [x] 1.1 HD 2D Rendering Pipeline
  - SubViewport at 320×180 for sprite plane, nearest-neighbor upscale
  - Composite over 3D world via CanvasLayer
  - WorldEnvironment: heavy DoF near+far, bloom, warm dusk color grade (`environments/hd2d_default.tres`)
  - Switched renderer: GL Compatibility → Forward+ (required for DoF/bloom/fog)
- [x] 1.2 Fixed Isometric Camera
  - 28° pitch, 45° yaw, 14u distance, 40° FOV (`scripts/IsoCamera.gd`)
  - Smooth lerp follow via `set_target(node)`
- [x] 1.3 Scene Architecture
  - Scene tree: Main → World3D (WorldEnv + DirectionalLight + Level + Camera) / SpriteViewport / SpriteLayer / UI (`scenes/Main.tscn`)
  - Autoloads: SignalBus, Game, SceneManager (`scripts/autoload/`)
  - Signal bus: 10 typed signals for health, stamina, dialogue, items, HUD messages

---

## Phase 2 — World & Environment

- [x] 2.1 Tile-Based 3D Level System
  - `DungeonTile.gd` — static mesh/collision builder, 7 tile types, HD 2D palette materials
  - `TileLevel.gd` — Node3D that builds level from 2D grid, places torch OmniLights, `make_test_grid()` for dev
  - Bugs fixed: Y-offset preservation on tile position, collision shape centering
- [x] 2.2 Lighting Setup
  - `TorchLight.gd` — flickering OmniLight3D (sine + noise, 2.8–4.2 energy, living flame color)
  - `AmbientLightSetup.gd` — near-zero ambient (0.08), dim cold fill DirectionalLight
  - WorldEnvironment already configured in Phase 1.1
- [ ] 2.3 Environment Art Pipeline *(asset strategy TBD)*
  - 3D dungeon wall/floor/prop models or Godot primitives + shaders

---

## Phase 3 — Characters & Sprites

- [ ] 3.1 Sprite Pipeline Rewrite
  - New 3/4-view sprites (current top-down sprites incompatible with HD 2D angle)
  - SpriteFactory rebuilt for SubViewport pipeline
  - Animation locked to 8–12fps
- [x] 3.2 Player Controller Port
  - Camera-relative isometric movement via fixed ISO_YAW basis (`scripts/Player.gd`)
  - Stamina / dodge (SNES B) / parry+riposte (SNES L) / heavy attack hold / knockback all ported
  - Player faces move direction via lerp_angle; all SignalBus emissions wired
  - SNES USB controller fully mapped in project.godot (D-pad + analog axes + 8 face/shoulder buttons)
- [x] 3.3 Enemy AI Port
  - State machine: awake → chase → wind-up telegraph → melee strike → punish stumble → stagger (`scripts/Enemy.gd`)
  - Bleed (stackable DOT) + burn (fire DOT) status effects
  - Fixed: multi-frame strike bug, signal-before-free ordering, burn tick reset, move_and_slide on wind-up miss

---

## Phase 4 — UI

- [ ] 4.1 HD 2D UI System
  - Ornate parchment/gold bordered panels (ref: Octopath Traveler style brief)
  - HUD: health/stamina bars, diegetic where possible
  - Dialogue box with animated text reveal
  - Pixel font throughout
- [ ] 4.2 Inventory & Shop UI Overhaul
  - Keep data structures from existing InventoryUI.gd / ShopUI.gd
  - Full visual overhaul to match new aesthetic

---

## Phase 5 — Content & Polish

- [ ] 5.1 Dungeon Generation Port
  - Keep room/corridor graph logic from Dungeon.gd
  - Output drives 3D tile placement instead of direct mesh generation
- [ ] 5.2 3D Particle Effects
  - Magic spells, dust, torch embers, hit impacts — all 3D, over sprite plane
  - Lo-res sprite + hi-res particles = the HD 2D contrast
- [ ] 5.3 Post-Processing Shader Pass
  - Film grain, vignette, subtle scanline on sprite SubViewport
  - Color grade matching warm amber + cold blue palette from brief

---

## Local LLM Offload Guide

Tasks suitable for `python3 tools/local-llm/lmstudio.py`:

| Task | Offload? | Notes |
|---|---|---|
| Autoload GDScript boilerplate | ✅ | Game.gd, SceneManager.gd, SignalBus.gd |
| Signal bus structure | ✅ | Mechanical, verifiable |
| Player movement port | ✅ | Translation job from existing Player.gd |
| Enemy state machine port | ✅ | Repetitive, mechanical |
| UI Control node layouts | ✅ | Structural markup |
| Dungeon gen translation layer | ✅ | Clear input/output contract |
| Enemy/item data files | ✅ | Bulk generation |
| Rendering pipeline | ❌ | Architecture — wrong here = broken everywhere |
| Camera system | ❌ | Needs careful math |
| Lighting / DoF tuning | ❌ | Iterative visual judgment |
| Shaders | ❌ | Complex, correctness-critical |
| Particle effects | ❌ | Visual judgment |

---

## Key Files (existing, for reference during port)

| File | What to keep |
|---|---|
| `scripts/Player.gd` | Stamina, dodge, parry, stagger, melee hit timing |
| `scripts/Enemy.gd` | State machine, attack patterns, health/damage |
| `scripts/Dungeon.gd` | Room/corridor graph generation logic |
| `scripts/Game.gd` | Game state management patterns |
| `scripts/data/EnemyDB.gd` | Enemy stat definitions |
| `scripts/data/ClassDB.gd` | Player class definitions |
| `scripts/ui/InventoryUI.gd` | Inventory data model |
| `scripts/ui/ShopUI.gd` | Shop transaction logic |
