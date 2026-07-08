# Barony — HD 2D Sprite Generation Prompts

All sprites are for a Godot 4 HD 2D dungeon crawler in the Octopath Traveler visual style.  
Style reference: [`tools/yt-ref/briefs/hd2d-octopath-traveler.md`](../../tools/yt-ref/briefs/hd2d-octopath-traveler.md)

---

## Global Style Prefix

Prepend this to every prompt below:

> **HD 2D pixel art, Octopath Traveler visual style, 3/4 top-down isometric perspective (camera looking down at roughly 30 degrees from the side), hard 1-pixel black outline on all edges, flat cel shading with exactly 3-4 color values per area (no gradients), clean readable silhouette, dark warm fantasy color palette, white background**

---

## Actual Frame Counts (confirmed from warrior sheets)

Each character needs **4 separate sheets**, generated in this order:

| Sheet | Frames | Canvas (warrior example) |
|---|---|---|
| idle | **3 frames horizontal** | 240×80 px |
| walk | **3 frames horizontal** | 240×80 px |
| attack | **3 frames horizontal** | 240×80 px |
| hurt-death | **2 hurt (top row) + 5 death (bottom row), labeled** | 400×160 px |

Always generate the **reference sheet first**, then use it as image input for each animation sheet.

---

## Workflow

1. Generate the **reference sheet** (3 poses: idle / walk / attack wind-up on one row).
2. Upload the reference sheet as an image when prompting each animation sheet — keeps the character on-model.
3. Generate sheets in order: idle → walk → attack → hurt-death.
4. All outputs: PNG, white background. Key out white in post — the hard outlines make it clean.

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
- `warrior-hurt-death.png` — 2 hurt (top, labeled) + 5 death (bottom, labeled)

---

## Enemies

### ✅ Kobold Tunneler (DONE)

Files: `kobold-reference-sheet-.png`, `kobold-idle.png`, `kobold-walk.png`, `kobold-attack.png`, `kobold-hurt-death.png`

---

### Murloc Raider

**Reference sheet:**
> [Global style prefix] — **character reference sheet, 3 poses (idle / walk / attack wind-up). Murloc Raider: amphibious fish-humanoid, medium build. Blue-green iridescent scales, large bulging yellow eyes, wide gaping mouth with small teeth, webbed hands, fish-fin dorsal crest along back. Crude barnacled chest guard, barbed trident. Each pose 64x64 px, total canvas 192x64. White background.**

**Idle sheet:**
> [Global style prefix] — **Murloc Raider, 3-frame idle animation, horizontal sprite sheet, 64x64 px per frame, total 192x64. Blue-green fish-humanoid with trident, subtle dorsal fin flick and weight shift. 3/4 isometric. White background.**

**Walk sheet:**
> [Global style prefix] — **Murloc Raider, 3-frame walk cycle, horizontal sprite sheet, 64x64 px per frame, total 192x64. Waddling forward with trident raised. 3/4 isometric moving toward lower-left. White background.**

**Attack sheet:**
> [Global style prefix] — **Murloc Raider, 3-frame attack animation, horizontal sprite sheet, 64x64 px per frame, total 192x64. Frame 1: trident pulled back (wind-up), Frame 2: full-extension thrust, Frame 3: recovery. 3/4 isometric. White background.**

**Hurt-death sheet:**
> [Global style prefix] — **Murloc Raider, combined hurt and death sprite sheet. Top row labeled "HURT": 2 frames (64x64) — creature stumbles back. Bottom row labeled "DEATH": 5 frames (64x64) — murloc collapses and goes still. Total canvas 320x128. 3/4 isometric. White background.**

---

### Scourge Skeleton

**Reference sheet:**
> [Global style prefix] — **character reference sheet, 3 poses (idle / walk / attack wind-up). Scourge Skeleton: undead humanoid skeleton, yellowed cracked bones. Rusted plate greaves, corroded breastplate, chipped longsword, cracked kite shield with skull emblem. Empty glowing blue eye sockets. Each pose 96x96 px, total canvas 288x96. White background.**

**Idle sheet:**
> [Global style prefix] — **Scourge Skeleton, 3-frame idle animation, horizontal sprite sheet, 96x96 px per frame, total 288x96. Yellowed armored skeleton with sword and cracked shield, subtle sword sway and jaw rattle. 3/4 isometric. White background.**

**Walk sheet:**
> [Global style prefix] — **Scourge Skeleton, 3-frame walk cycle, horizontal sprite sheet, 96x96 px per frame, total 288x96. Stalking forward with sword raised. 3/4 isometric moving toward lower-left. White background.**

**Attack sheet:**
> [Global style prefix] — **Scourge Skeleton, 3-frame attack animation, horizontal sprite sheet, 96x96 px per frame, total 288x96. Frame 1: sword raised overhead wind-up, Frame 2: diagonal slash with motion streak, Frame 3: shield returns to guard. 3/4 isometric. White background.**

**Hurt-death sheet:**
> [Global style prefix] — **Scourge Skeleton, combined hurt and death sprite sheet. Top row labeled "HURT": 2 frames (96x96) — skeleton staggers back. Bottom row labeled "DEATH": 5 frames (96x96) — bones collapse and scatter. Total canvas 480x192. 3/4 isometric. White background.**

---

### Orc Grunt

**Reference sheet:**
> [Global style prefix] — **character reference sheet, 3 poses (idle / walk / attack wind-up). Orc Grunt: large muscular green-skinned orc, broad shoulders, prominent lower jaw with upward curved tusks. Spiked iron pauldron, thick leather belt, crude iron greaves. Battle axe in main hand, serrated cleaver in offhand. Menacing hunched posture. Each pose 96x96 px, total canvas 288x96. White background. Warcraft orc aesthetic.**

**Idle sheet:**
> [Global style prefix] — **Orc Grunt, 3-frame idle animation, horizontal sprite sheet, 96x96 px per frame, total 288x96. Large green orc dual-wielding axe and cleaver, subtle breathing and weapon shift. 3/4 isometric. White background.**

**Walk sheet:**
> [Global style prefix] — **Orc Grunt, 3-frame walk cycle, horizontal sprite sheet, 96x96 px per frame, total 288x96. Heavy stomping forward with weapons ready. 3/4 isometric moving toward lower-left. White background.**

**Attack sheet:**
> [Global style prefix] — **Orc Grunt, 3-frame attack animation, horizontal sprite sheet, 96x96 px per frame, total 288x96. Frame 1: axe raised in wind-up, Frame 2: full overhead chop with force lines, Frame 3: recovery stance with cleaver raised. 3/4 isometric. White background.**

**Hurt-death sheet:**
> [Global style prefix] — **Orc Grunt, combined hurt and death sprite sheet. Top row labeled "HURT": 2 frames (96x96) — orc staggers and grunts. Bottom row labeled "DEATH": 5 frames (96x96) — orc stumbles, drops weapons, crashes to ground. Total canvas 480x192. 3/4 isometric. White background.**

---

### Troll Headhunter *(ranged — attack = throw)*

**Reference sheet:**
> [Global style prefix] — **character reference sheet, 3 poses (idle / walk / throw wind-up). Troll Headhunter: tall lanky blue-purple troll, hunched posture, long arms, wild dark mane of hair. Tribal bone-studded leather, three throwing axes on belt, two long curved tusks. Each pose 96x96 px, total canvas 288x96. White background.**

**Idle sheet:**
> [Global style prefix] — **Troll Headhunter, 3-frame idle animation, horizontal sprite sheet, 96x96 px per frame, total 288x96. Lanky blue-purple troll with throwing axes on belt, subtle sway and tusk bob. 3/4 isometric. White background.**

**Walk sheet:**
> [Global style prefix] — **Troll Headhunter, 3-frame walk cycle, horizontal sprite sheet, 96x96 px per frame, total 288x96. Loping forward with throwing arm loose at side. 3/4 isometric moving toward lower-left. White background.**

**Attack sheet (throw):**
> [Global style prefix] — **Troll Headhunter, 3-frame ranged throw animation, horizontal sprite sheet, 96x96 px per frame, total 288x96. Frame 1: arm cocked back with axe gripped (wind-up), Frame 2: full throw release, axe leaving hand, Frame 3: follow-through, empty hand extended. 3/4 isometric. White background.**

**Hurt-death sheet:**
> [Global style prefix] — **Troll Headhunter, combined hurt and death sprite sheet. Top row labeled "HURT": 2 frames (96x96) — troll recoils but stays upright. Bottom row labeled "DEATH": 5 frames (96x96) — troll collapses slowly, regeneration fails. Total canvas 480x192. 3/4 isometric. White background.**

---

### Cultist Necromancer *(ranged — attack = shadow bolt cast)*

**Reference sheet:**
> [Global style prefix] — **character reference sheet, 3 poses (idle floating / glide / spell cast wind-up). Cultist Necromancer: robed human spellcaster, tattered dark-purple hooded robe with bone and skull motifs on hem. Gaunt pale face, skeletal staff with glowing green orb, floats slightly off ground, purple-black energy wisps from fingertips. Each pose 96x96 px, total canvas 288x96. White background.**

**Idle sheet:**
> [Global style prefix] — **Cultist Necromancer, 3-frame idle animation, horizontal sprite sheet, 96x96 px per frame, total 288x96. Robed necromancer floating slightly, robes drifting, green orb pulsing. 3/4 isometric. White background.**

**Walk (glide) sheet:**
> [Global style prefix] — **Cultist Necromancer, 3-frame glide/move animation, horizontal sprite sheet, 96x96 px per frame, total 288x96. Necromancer drifting forward without leg movement, robes billowing. 3/4 isometric moving toward lower-left. White background.**

**Attack sheet (cast):**
> [Global style prefix] — **Cultist Necromancer, 3-frame spell cast animation, horizontal sprite sheet, 96x96 px per frame, total 288x96. Frame 1: staff raised, green energy gathering at orb (wind-up), Frame 2: shadow bolt launching forward with dark green trail, Frame 3: recovery, robes settling. 3/4 isometric. White background.**

**Hurt-death sheet:**
> [Global style prefix] — **Cultist Necromancer, combined hurt and death sprite sheet. Top row labeled "HURT": 2 frames (96x96) — necromancer recoils, orb flickers. Bottom row labeled "DEATH": 5 frames (96x96) — floats upward briefly, then crumples and dissolves, robe collapsing. Total canvas 480x192. 3/4 isometric. White background.**

---

### Gor'maul the Warlord *(boss)*

**Reference sheet:**
> [Global style prefix] — **character reference sheet, 3 poses (idle / charging / enraged at 50% hp). Gor'maul the Warlord: enormous two-headed ogre, each head different (one snarling, one dim grin). Mountain of muscle, grey-brown warty skin. Crude iron crown, massive riveted iron pauldrons, tattered war-banner on back, colossal spiked warhammer dragging on ground. Three times regular enemy size. Each pose 192x192 px, total canvas 576x192. White background. Boss-tier threat presence.**

**Idle sheet:**
> [Global style prefix] — **Gor'maul the Warlord, 3-frame idle animation, horizontal sprite sheet, 192x192 px per frame, total 576x192. Massive two-headed ogre with spiked warhammer, both heads slowly turning, deep chest breathing. 3/4 isometric. White background.**

**Walk sheet:**
> [Global style prefix] — **Gor'maul the Warlord, 3-frame walk cycle, horizontal sprite sheet, 192x192 px per frame, total 576x192. Ground-shaking heavy stomp forward, warhammer dragging, war-banner swaying. 3/4 isometric moving toward lower-left. White background.**

**Attack sheet:**
> [Global style prefix] — **Gor'maul the Warlord, 3-frame warhammer slam animation, horizontal sprite sheet, 192x192 px per frame, total 576x192. Frame 1: warhammer hoisted overhead with both hands (massive wind-up), Frame 2: full ground slam, shockwave cracks at base, Frame 3: recovery, hunched breathing heavily. 3/4 isometric. White background.**

**Hurt-death sheet:**
> [Global style prefix] — **Gor'maul the Warlord, combined hurt and death sprite sheet. Top row labeled "HURT": 2 frames (192x192) — ogre stumbles but roars defiantly. Bottom row labeled "DEATH": 5 frames (192x192) — sways, drops warhammer, both heads loll, crashes to knees, collapses face-first. Total canvas 960x384. 3/4 isometric. White background.**

---

## Projectiles

### Fireball
> [Global style prefix] — **fireball projectile, 3-frame animation loop, each frame 32x32 px, total canvas 96x32, white background. Compact fireball traveling left-to-right. Bright orange core, yellow-white hot center, dark red trailing wisps. Hard outlines.**

### Arrow
> [Global style prefix] — **arrow projectile, single frame, 32x32 px, white background. Wooden shaft, iron tip, white fletching, traveling left-to-right at slight downward angle. Hard black outline.**

### Shadow Bolt
> [Global style prefix] — **shadow bolt projectile, 3-frame animation loop, each frame 32x32 px, total canvas 96x32, white background. Dark purple-black energy orb with green crackling core, wisps trailing behind. Traveling left-to-right. Hard outlines.**

### Thrown Axe
> [Global style prefix] — **thrown axe projectile, 3-frame tumble animation, each frame 32x32 px, total canvas 96x32, white background. Crude iron hand axe tumbling end-over-end. Frames show 0°, 120°, 240° rotation. Hard black outline.**

---

## Item Pickups

All items: 32×32 px, white background, same style prefix, slight isometric overhead angle.

### Health Potion
> [Global style prefix] — **health potion pickup, 32x32 px. Round red glass vial, cork stopper, gold wax seal, red cross embossed, glowing warm liquid inside. Isometric angle. White background.**

### Mana Potion
> [Global style prefix] — **mana potion pickup, 32x32 px. Tall blue glass vial, silver stopper, glowing blue magical liquid, small arcane rune on label. Isometric angle. White background.**

### Gold Coins
> [Global style prefix] — **gold coin pile pickup, 32x32 px. Small pile of 5-6 gold coins, slight overhead isometric view, crown emblem stamped on coins, warm torchlight sheen. White background.**

### Iron Key
> [Global style prefix] — **iron key pickup, 32x32 px. Large ornate iron key, slight rust, skull-shaped bow (top loop), notched blade. Overhead isometric angle, torchlight glint. White background.**

### Shrine
> [Global style prefix] — **dungeon shrine interactive object, 64x64 px. Short stone pedestal, glowing golden bowl on top, warm orange magical flame rising from bowl, archaic runes engraved on stone. 3/4 isometric. White background.**

---

## Gear Icons (UI Inventory)

All icons: 48×48 px, white background, **front-facing flat view (not isometric)** — these are UI elements.

> HD 2D pixel art, Octopath Traveler visual style, **front-facing flat icon view**, hard 1-pixel black outline, flat cel shading 3-4 values, white background — **equipment icon, 48x48 px.**

- **Iron Sword** — straight double-edged longsword, worn leather grip, simple crossguard
- **Iron Shield** — round iron shield, studded edge, iron boss center
- **Iron Helm** — full-face iron helm, T-visor, cheek guards
- **Iron Chestplate** — riveted iron breastplate, pauldron tabs, chain underlayer visible at neck
- **Gold Ring** — simple gold band, small red gemstone
- **Magic Staff** — gnarled wood, glowing purple-blue crystal orb at top, leather wrapped grip
- **Hunter Bow** — recurve shortbow, dark wood, arrow nocked
- **Rogue Dagger** — short stiletto, black blade, wrapped handle with red tassel

---

## Notes for Gemini

1. **Always upload the reference sheet** as an image when generating animation sheets. Keeps the character on-model across all sheets.
2. **Hurt-death sheet format**: Two labeled rows — "HURT" on top (2 frames), "DEATH" on bottom (5 frames). Specify the labels explicitly in the prompt.
3. **White gap between frames**: Add "with a thin white gap between each frame" to keep frames clearly separated for slicing in Godot.
4. **If a sheet comes back wrong frame count**: Re-run with the warrior sheets uploaded as a visual format reference alongside the prompt.
5. **Import in Godot**: `texture_filter = nearest`, then slice by frame width.
6. **Generation order per character**: Reference → Idle → Walk → Attack → Hurt-Death.
