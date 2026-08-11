# Barony — HD 2D Sprite Generation Prompts

All sprites are for a Godot 4 HD 2D dungeon crawler in the Octopath Traveler visual style.  
Style reference: [`tools/yt-ref/briefs/hd2d-octopath-traveler.md`](../../tools/yt-ref/briefs/hd2d-octopath-traveler.md)

---

## Global Style Prefix

Prepend this to every prompt below:

> **HD 2D pixel art, Octopath Traveler visual style, 3/4 top-down isometric perspective (camera looking down at roughly 30 degrees from the side), hard 1-pixel black outline on all edges, flat cel shading with exactly 3-4 color values per area (no gradients), clean readable silhouette, dark warm fantasy color palette, pure white background**

---

## Global Negative Suffix

**Append this to every prompt below, verbatim.** It is not optional.

> **Absolutely no text anywhere in the image: no labels, no captions, no titles, no frame numbers, no watermarks, no annotations, no arrows. No panel borders, no grid lines, no boxes or frames drawn around the sprites. No drop shadows on the background. Background must be pure flat white (#FFFFFF) everywhere — no gray, no checkerboard, no transparency pattern, no gradient, no vignette. Exactly one character in the image, repeated once per animation frame and nothing else.**

### Why this exists

The first generation pass baked the words `HURT`, `DEATH`, `Wind-Up`, `Launch`,
`Recovery`, `GRK!` and `THROWING` directly into the sprite pixels, and returned
several sheets on gray or checkerboard backdrops with panel borders drawn
around each frame. That was **caused by these prompts**: the old hurt-death
prompt said `Top row labeled "HURT"`, and the old attack prompts named each
frame `(wind-up)` / `recovery`. Gemini rendered the labels because it was asked
to. Never name a frame with a word you don't want drawn — describe the *pose*
instead. Baked-in text cannot be removed in post: it overlaps the body.

---

## Identity Lock

The other first-pass failure was **character drift**. Each animation sheet is a
separate Gemini call, and a short descriptor like "blue-green fish-humanoid
with trident" let the model reinvent the character every call — the murloc came
back as four different creatures across its four sheets, Gor'maul as three
different bosses.

**Fix: every sheet prompt below restates the character's full Identity Lock
verbatim.** Do not shorten it, even though it is repetitive — the repetition is
the mechanism. Upload the reference sheet as an attachment *as well*; the two
together hold the character on-model.

| Character | Identity Lock (use verbatim in every sheet) |
|---|---|
| Murloc Raider | amphibious fish-humanoid, medium build, **teal blue-green iridescent scales**, large bulging yellow eyes, wide gaping mouth with small teeth, webbed hands, tall spiny **dorsal fin crest along the back and head**, crude barnacled chest guard, barbed trident always in hand |
| Scourge Skeleton | undead humanoid skeleton, **yellowed cracked bones**, rusted plate greaves, corroded breastplate, chipped longsword, cracked kite shield with skull emblem, empty **glowing blue** eye sockets, no cape, no horned helmet |
| Orc Grunt | large muscular **green-skinned** orc, broad shoulders, prominent lower jaw with upward-curved tusks, **spiked iron pauldron on the left shoulder**, thick leather belt, crude iron greaves, battle axe in main hand, serrated cleaver in offhand |
| Troll Headhunter | tall lanky **blue-purple** troll, hunched posture, long arms, wild dark mane of hair, **two long curved tusks**, tribal bone-studded leather, three throwing axes on belt |
| Cultist Necromancer | robed human spellcaster, tattered **dark-purple** hooded robe with bone and skull motifs on the hem, gaunt pale face, skeletal staff with **glowing green orb**, floats slightly off the ground, purple-black energy wisps from fingertips |
| Gor'maul the Warlord | enormous **two-headed** ogre, each head different (one snarling, one dim grin), mountain of muscle, **grey-brown warty skin**, crude iron crown, massive riveted iron pauldrons, tattered war-banner on back, colossal spiked warhammer |

---

## Actual Frame Counts (confirmed from warrior sheets)

Each character needs **4 separate sheets**, generated in this order:

| Sheet | Frames | Canvas (warrior example) |
|---|---|---|
| idle | **3 frames horizontal** | 240×80 px |
| walk | **3 frames horizontal** | 240×80 px |
| attack | **3 frames horizontal** | 240×80 px |
| hurt-death | **2 hurt (top row) + 5 death (bottom row), unlabeled** | 400×160 px |

Always generate the **reference sheet first**, then use it as image input for each animation sheet.

---

## Workflow

1. Generate the **reference sheet** (3 poses: idle / walk / attack strike on one row).
2. Upload the reference sheet as an image when prompting each animation sheet — keeps the character on-model.
3. Generate sheets in order: idle → walk → attack → hurt-death.
4. All outputs: PNG, pure white background. Key out white in post — the hard outlines make it clean.
5. **After slicing, always run `tools/normalize_frames.py`** — see [Post-processing](#post-processing).

---

## Output Sizes

| Asset type | Frame size |
|---|---|
| Player warrior | 80×80 px |
| Small enemy (kobold, murloc) | 64×64 px |
| Medium enemy (skeleton, orc, troll, necro) | 96×96 px |
| Boss (Gor'maul) | 192×192 px |
| Projectiles | 32×32 px |
| Item pickups | 32×32 px |
| Gear icons (UI inventory) | 48×48 px |

---

## ✅ Player — Warrior (DONE)

Files in `godot/sprites/`:
- `warrior-idle.png` — 3 frames
- `warrior-walk.png` — 3 frames
- `warrior-attack.png` — 3 frames
- `warrior-hurt-death.png` — 2 hurt (top) + 5 death (bottom)

---

## ✅ Kobold Tunneler (DONE — on-model, use as the quality bar)

Files: `kobold-reference-sheet-.png`, `kobold-idle.png`, `kobold-walk.png`, `kobold-attack.png`, `kobold-hurt-death.png`

The kobold is the only first-pass character that stayed on-model across all
four sheets. Compare new output against it.

---

## Enemies

> In every prompt below, `[LOCK]` means "paste that character's Identity Lock
> row from the table above, verbatim". Every prompt also takes the Global Style
> Prefix in front and the Global Negative Suffix behind.

### Murloc Raider

**Reference sheet:**
> [Global style prefix] — **character reference sheet, 3 poses in one horizontal row (standing at rest / mid-stride walking / trident thrust). Murloc Raider: [LOCK]. Each pose 64x64 px, total canvas 192x64.** [Global negative suffix]

**Idle sheet:**
> [Global style prefix] — **Murloc Raider, 3-frame idle animation, horizontal sprite sheet, 64x64 px per frame, total 192x64, thin white gap between frames. Murloc Raider: [LOCK]. The dorsal fin flicks and the body shifts weight between frames. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Walk sheet:**
> [Global style prefix] — **Murloc Raider, 3-frame walk cycle, horizontal sprite sheet, 64x64 px per frame, total 192x64, thin white gap between frames. Murloc Raider: [LOCK]. Waddling forward with trident raised, moving toward lower-left. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Attack sheet:**
> [Global style prefix] — **Murloc Raider, 3-frame trident thrust animation, horizontal sprite sheet, 64x64 px per frame, total 192x64, thin white gap between frames. Murloc Raider: [LOCK]. First frame the trident is pulled back beside the hip; second frame the trident is thrust out at full arm extension; third frame the trident is lowered and the body is settling. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Hurt-death sheet:**
> [Global style prefix] — **Murloc Raider, one image containing two horizontal rows of sprites on a pure white background. Murloc Raider: [LOCK]. Top row: 2 frames (64x64) of the creature stumbling backward, still standing. Bottom row: 5 frames (64x64) of the creature collapsing to the ground and going still. Total canvas 320x128, thin white gap between frames. Identical character in all 7 frames. 3/4 isometric.** [Global negative suffix]

---

### Scourge Skeleton

**Reference sheet:**
> [Global style prefix] — **character reference sheet, 3 poses in one horizontal row (standing at rest / mid-stride walking / sword raised overhead). Scourge Skeleton: [LOCK]. Each pose 96x96 px, total canvas 288x96.** [Global negative suffix]

**Idle sheet:**
> [Global style prefix] — **Scourge Skeleton, 3-frame idle animation, horizontal sprite sheet, 96x96 px per frame, total 288x96, thin white gap between frames. Scourge Skeleton: [LOCK]. The sword sways slightly and the jaw rattles between frames. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Walk sheet:**
> [Global style prefix] — **Scourge Skeleton, 3-frame walk cycle, horizontal sprite sheet, 96x96 px per frame, total 288x96, thin white gap between frames. Scourge Skeleton: [LOCK]. Stalking forward with sword raised and shield up, moving toward lower-left. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Attack sheet:**
> [Global style prefix] — **Scourge Skeleton, 3-frame sword slash animation, horizontal sprite sheet, 96x96 px per frame, total 288x96, thin white gap between frames. Scourge Skeleton: [LOCK]. First frame the sword is raised overhead; second frame the sword cuts down diagonally with a motion streak; third frame the shield is back at guard. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Hurt-death sheet:**
> [Global style prefix] — **Scourge Skeleton, one image containing two horizontal rows of sprites on a pure white background. Scourge Skeleton: [LOCK]. Top row: 2 frames (96x96) of the skeleton staggering backward, still standing. Bottom row: 5 frames (96x96) of the skeleton collapsing as its bones scatter across the ground. Total canvas 480x192, thin white gap between frames. Identical character in all 7 frames. 3/4 isometric.** [Global negative suffix]

---

### Orc Grunt

**Reference sheet:**
> [Global style prefix] — **character reference sheet, 3 poses in one horizontal row (standing at rest / mid-stride walking / axe raised overhead). Orc Grunt: [LOCK]. Menacing hunched posture, Warcraft orc aesthetic. Each pose 96x96 px, total canvas 288x96.** [Global negative suffix]

**Idle sheet:**
> [Global style prefix] — **Orc Grunt, 3-frame idle animation, horizontal sprite sheet, 96x96 px per frame, total 288x96, thin white gap between frames. Orc Grunt: [LOCK]. Chest rises with breathing and the weapons shift between frames. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Walk sheet:**
> [Global style prefix] — **Orc Grunt, 3-frame walk cycle, horizontal sprite sheet, 96x96 px per frame, total 288x96, thin white gap between frames. Orc Grunt: [LOCK]. Heavy stomping forward with both weapons ready, moving toward lower-left. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Attack sheet:**
> [Global style prefix] — **Orc Grunt, 3-frame axe chop animation, horizontal sprite sheet, 96x96 px per frame, total 288x96, thin white gap between frames. Orc Grunt: [LOCK]. First frame the axe is raised high behind the head; second frame the axe chops down through the target with force lines; third frame the orc is upright again with the cleaver raised. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Hurt-death sheet:**
> [Global style prefix] — **Orc Grunt, one image containing two horizontal rows of sprites on a pure white background. Orc Grunt: [LOCK]. Top row: 2 frames (96x96) of the orc staggering backward, still standing. Bottom row: 5 frames (96x96) of the orc stumbling, dropping its weapons, and crashing to the ground. Total canvas 480x192, thin white gap between frames. Identical character in all 7 frames. 3/4 isometric.** [Global negative suffix]

---

### Troll Headhunter *(ranged — attack = throw)*

**Reference sheet:**
> [Global style prefix] — **character reference sheet, 3 poses in one horizontal row (standing at rest / mid-stride loping / throwing arm cocked back). Troll Headhunter: [LOCK]. Each pose 96x96 px, total canvas 288x96.** [Global negative suffix]

**Idle sheet:**
> [Global style prefix] — **Troll Headhunter, 3-frame idle animation, horizontal sprite sheet, 96x96 px per frame, total 288x96, thin white gap between frames. Troll Headhunter: [LOCK]. The body sways and the tusks bob between frames. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Walk sheet:**
> [Global style prefix] — **Troll Headhunter, 3-frame walk cycle, horizontal sprite sheet, 96x96 px per frame, total 288x96, thin white gap between frames. Troll Headhunter: [LOCK]. Loping forward with the throwing arm loose at its side, moving toward lower-left. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Attack sheet (throw):**
> [Global style prefix] — **Troll Headhunter, 3-frame axe throw animation, horizontal sprite sheet, 96x96 px per frame, total 288x96, thin white gap between frames. Troll Headhunter: [LOCK]. First frame the arm is cocked back behind the head gripping a throwing axe; second frame the arm swings forward and the axe leaves the hand; third frame the arm is extended forward and the hand is empty. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Hurt-death sheet:**
> [Global style prefix] — **Troll Headhunter, one image containing two horizontal rows of sprites on a pure white background. Troll Headhunter: [LOCK]. Top row: 2 frames (96x96) of the troll recoiling but staying upright. Bottom row: 5 frames (96x96) of the troll slowly sinking to the ground and going still. Total canvas 480x192, thin white gap between frames. Identical character in all 7 frames. 3/4 isometric.** [Global negative suffix]

---

### Cultist Necromancer *(ranged — attack = shadow bolt cast)*

**Reference sheet:**
> [Global style prefix] — **character reference sheet, 3 poses in one horizontal row (floating at rest / gliding forward / staff raised with energy gathering). Cultist Necromancer: [LOCK]. Each pose 96x96 px, total canvas 288x96.** [Global negative suffix]

**Idle sheet:**
> [Global style prefix] — **Cultist Necromancer, 3-frame idle animation, horizontal sprite sheet, 96x96 px per frame, total 288x96, thin white gap between frames. Cultist Necromancer: [LOCK]. The robes drift and the green orb pulses between frames. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Walk (glide) sheet:**
> [Global style prefix] — **Cultist Necromancer, 3-frame glide animation, horizontal sprite sheet, 96x96 px per frame, total 288x96, thin white gap between frames. Cultist Necromancer: [LOCK]. Drifting forward without leg movement, robes billowing, moving toward lower-left. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Attack sheet (cast):**
> [Global style prefix] — **Cultist Necromancer, 3-frame spell cast animation, horizontal sprite sheet, 96x96 px per frame, total 288x96, thin white gap between frames. Cultist Necromancer: [LOCK]. First frame the staff is raised and green energy gathers at the orb; second frame a shadow bolt streaks forward from the orb with a dark green trail; third frame the staff is lowered and the robes settle. Identical character in all 3 frames. 3/4 isometric.** [Global negative suffix]

**Hurt-death sheet:**
> [Global style prefix] — **Cultist Necromancer, one image containing two horizontal rows of sprites on a pure white background. Cultist Necromancer: [LOCK]. Top row: 2 frames (96x96) of the necromancer recoiling as the orb flickers. Bottom row: 5 frames (96x96) of the necromancer drifting upward, then crumpling and dissolving as the empty robe collapses to the ground. Total canvas 480x192, thin white gap between frames. Identical character in all 7 frames. 3/4 isometric.** [Global negative suffix]

---

### Gor'maul the Warlord *(boss)*

**Reference sheet:**
> [Global style prefix] — **character reference sheet, 3 poses in one horizontal row (standing at rest / striding forward / roaring with arms spread). Gor'maul the Warlord: [LOCK]. Three times regular enemy size, boss-tier threat presence. Each pose 192x192 px, total canvas 576x192.** [Global negative suffix]

**Idle sheet:**
> [Global style prefix] — **Gor'maul the Warlord, 3-frame idle animation, horizontal sprite sheet, 192x192 px per frame, total 576x192, thin white gap between frames. Gor'maul the Warlord: [LOCK]. Both heads slowly turn and the chest rises with deep breathing between frames. Identical character in all 3 frames — both heads present in every frame. 3/4 isometric.** [Global negative suffix]

**Walk sheet:**
> [Global style prefix] — **Gor'maul the Warlord, 3-frame walk cycle, horizontal sprite sheet, 192x192 px per frame, total 576x192, thin white gap between frames. Gor'maul the Warlord: [LOCK]. Ground-shaking heavy stomp forward, warhammer dragging, war-banner swaying, moving toward lower-left. Identical character in all 3 frames — both heads present in every frame. 3/4 isometric.** [Global negative suffix]

**Attack sheet:**
> [Global style prefix] — **Gor'maul the Warlord, 3-frame warhammer slam animation, horizontal sprite sheet, 192x192 px per frame, total 576x192, thin white gap between frames. Gor'maul the Warlord: [LOCK]. First frame the warhammer is hoisted overhead in both hands; second frame the warhammer smashes into the ground and a shockwave cracks the floor at its base; third frame the ogre is hunched over the hammer breathing heavily. Identical character in all 3 frames — both heads present in every frame, same size in every frame. 3/4 isometric.** [Global negative suffix]

**Hurt-death sheet:**
> [Global style prefix] — **Gor'maul the Warlord, one image containing two horizontal rows of sprites on a pure white background. Gor'maul the Warlord: [LOCK]. Top row: 2 frames (192x192) of the ogre stumbling backward while roaring, still standing. Bottom row: 5 frames (192x192) of the ogre swaying, dropping the warhammer, both heads lolling, crashing to its knees, and collapsing face-first. Total canvas 960x384, thin white gap between frames. Identical character in all 7 frames — both heads present in every frame. 3/4 isometric.** [Global negative suffix]

---

## Projectiles

### Fireball
> [Global style prefix] — **fireball projectile, 3-frame animation loop, each frame 32x32 px, total canvas 96x32. Compact fireball traveling left-to-right. Bright orange core, yellow-white hot center, dark red trailing wisps. Hard outlines.** [Global negative suffix]

### Arrow
> [Global style prefix] — **arrow projectile, single frame, 32x32 px. Wooden shaft, iron tip, white fletching, traveling left-to-right at slight downward angle. Hard black outline.** [Global negative suffix]

### Shadow Bolt
> [Global style prefix] — **shadow bolt projectile, 3-frame animation loop, each frame 32x32 px, total canvas 96x32. Dark purple-black energy orb with green crackling core, wisps trailing behind. Traveling left-to-right. Hard outlines.** [Global negative suffix]

### Thrown Axe
> [Global style prefix] — **thrown axe projectile, 3-frame tumble animation, each frame 32x32 px, total canvas 96x32. Crude iron hand axe tumbling end-over-end. Frames show 0°, 120°, 240° rotation. Hard black outline.** [Global negative suffix]

---

## Item Pickups

All items: 32×32 px, pure white background, same style prefix and negative suffix, slight isometric overhead angle.

### Health Potion
> [Global style prefix] — **health potion pickup, 32x32 px. Round red glass vial, cork stopper, gold wax seal, red cross embossed, glowing warm liquid inside. Isometric angle.** [Global negative suffix]

### Mana Potion
> [Global style prefix] — **mana potion pickup, 32x32 px. Tall blue glass vial, silver stopper, glowing blue magical liquid, small arcane rune on label. Isometric angle.** [Global negative suffix]

### Gold Coins
> [Global style prefix] — **gold coin pile pickup, 32x32 px. Small pile of 5-6 gold coins, slight overhead isometric view, crown emblem stamped on coins, warm torchlight sheen.** [Global negative suffix]

### Iron Key
> [Global style prefix] — **iron key pickup, 32x32 px. Large ornate iron key, slight rust, skull-shaped bow (top loop), notched blade. Overhead isometric angle, torchlight glint.** [Global negative suffix]

### Shrine
> [Global style prefix] — **dungeon shrine interactive object, 64x64 px. Short stone pedestal, glowing golden bowl on top, warm orange magical flame rising from bowl, archaic runes engraved on stone. 3/4 isometric.** [Global negative suffix]

---

## Gear Icons (UI Inventory)

All icons: 48×48 px, pure white background, **front-facing flat view (not isometric)** — these are UI elements.

> HD 2D pixel art, Octopath Traveler visual style, **front-facing flat icon view**, hard 1-pixel black outline, flat cel shading 3-4 values, pure white background — **equipment icon, 48x48 px.** [Global negative suffix]

- **Iron Sword** — straight double-edged longsword, worn leather grip, simple crossguard
- **Iron Shield** — round iron shield, studded edge, iron boss center
- **Iron Helm** — full-face iron helm, T-visor, cheek guards
- **Iron Chestplate** — riveted iron breastplate, pauldron tabs, chain underlayer visible at neck
- **Gold Ring** — simple gold band, small red gemstone
- **Magic Staff** — gnarled wood, glowing purple-blue crystal orb at top, leather wrapped grip
- **Hunter Bow** — recurve shortbow, dark wood, arrow nocked
- **Rogue Dagger** — short stiletto, black blade, wrapped handle with red tassel

---

## Post-processing

Slicing alone is not enough. `slice_sprites.py` tight-crops each *sheet*
independently, so a character ends up with e.g. a 421×593 idle frame and a
298×254 death frame. `SpriteFactory` applies one `pixel_size` to all of them,
so the character visibly pops to a different size the moment it changes
animation, and short frames float above the floor.

**Always run both, in order:**

```bash
python3 tools/slice_sprites.py
python3 tools/normalize_frames.py            # or: normalize_frames.py murloc orc
```

`normalize_frames.py` re-keys the backdrop (flood fill from the border, so it
catches black/gray/checkerboard backdrops the white-key misses), rescales each
animation to a common drawn-resolution anchored on `idle`, and re-emits every
frame on one shared canvas, centred and bottom-anchored to a common ground
line. `pixel_size` in `SpriteFactory.gd` does **not** need re-tuning afterwards:
`idle` is the scale anchor and is never resampled, so body size in world units
is unchanged.

---

## Review checklist

Before accepting a character, build a contact sheet of
`godot/sprites/sliced/<character>/` and confirm:

- [ ] Same creature in all 16 frames — same palette, same silhouette, same gear
- [ ] No text, labels, panel borders or gray backdrop anywhere
- [ ] Weapon present in every frame it should be
- [ ] All frames identical canvas size, feet on a common ground line
- [ ] Reads clearly at game scale, not just zoomed in

---

## Notes for Gemini

1. **Always upload the reference sheet** as an image when generating animation sheets, *and* restate the Identity Lock in the prompt text. Both together — either alone lets the character drift.
2. **Never name a frame with a word you don't want drawn.** Say "the arm is cocked back", not "(wind-up)". Say "top row" / "bottom row", not `labeled "HURT"`.
3. **Thin white gap between frames** keeps frames separable for the slicer.
4. **If a sheet comes back wrong frame count**: re-run with the kobold sheets uploaded as a visual format reference alongside the prompt.
5. **Import in Godot**: `texture_filter = nearest`, then slice by frame width.
6. **Generation order per character**: Reference → Idle → Walk → Attack → Hurt-Death → slice → normalize.
