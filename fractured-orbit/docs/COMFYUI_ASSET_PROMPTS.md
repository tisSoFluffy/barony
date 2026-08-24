# Fractured Orbit — ComfyUI Asset & Prop Prompt Library

Generation prompts for every asset the game requests, tuned for a **local
ComfyUI** running the **text → image → 3D model → texture** pipeline, and a
**low-poly / "Deep Rock Galactic" brutalist sci-fi** look.

Each entry's **`file:`** is the exact name to save the finished model as, under
`assets/models/`. Drop it in and the engine swaps it for the placeholder with no
code changes (see [`../assets/README.md`](../assets/README.md)).

---

## 1. Pipeline (the four stages)

```
 (1) TEXT ─▶ (2) IMAGE ─▶ (3) 3D MESH ─▶ (4) TEXTURE ─▶  assets/models/<name>.glb
   prompt      SDXL/         image-to-3D    bake / paint
               Flux          (TripoSR …)
```

**Stage 2 — text → image.** SDXL or Flux. Sampler: DPM++ 2M Karras, ~30 steps,
CFG 5–7. Render at **1024×1024** on a **flat neutral-grey background** so the
image-to-3D step gets a clean silhouette. One object, centered, three-quarter
front view.

**Stage 3 — image → 3D.** Any single-image mesh node works — **TripoSR**,
**Stable Fast 3D**, **InstantMesh**, **CRM**, or **Hunyuan3D-2** (Hunyuan and
InstantMesh give the cleanest game-ready topology). If your node accepts
multiple views, generate a **front + 3/4 + side** turnaround (see §4) for a
better cage. Export **GLB**. Then **decimate** to the tri budget in
`../assets/README.md` (ComfyUI has decimate nodes; or one pass in Blender).

**Stage 4 — texture.** Two valid routes, pick per asset:
- **Flat-material route (fastest, most on-style):** discard the baked texture,
  assign a single flat-shaded material per part using the **sector hex palette**
  in §3. This is the truest to the art direction and what the placeholders
  emulate.
- **Baked route:** keep the image-to-3D texture, or re-project a Stage-2 image
  as an albedo bake, then hand it to a PBR/material node. Keep roughness high
  (0.8–1.0), metallic near 0 except for glowing strips (use **emissive**).

> Consistency tip: fix the **seed** and reuse the **style suffix** (§2) across a
> whole sector so its props read as one set.

---

## 2. Shared style tokens

Append the **style suffix** to every Stage-2 prompt; use the **negative** every
time.

**Style suffix** (paste verbatim after each asset prompt):

```
, low poly 3D game asset, faceted geometry, flat shading, hard edges,
brutalist sci-fi, Deep Rock Galactic art style, slightly desaturated colors,
chunky minimalist forms, single object centered, three-quarter front view,
isolated on flat neutral grey background, soft even studio lighting, clean
readable silhouette, PBR game-ready, orthographic-ish
```

**Negative prompt** (paste verbatim every time):

```
high poly, hyperrealistic, photorealistic, smooth subdivision, organic detail,
noisy background, scenery, floor, shadow clutter, multiple objects, text,
letters, watermark, signature, blurry, motion blur, depth of field, lens flare,
oversaturated, busy texture, tiling artifacts
```

---

## 3. Sector palettes (use these hex values in Stage 4)

Match in-engine lighting by texturing to these. Values mirror `SectorDB.gd`.

| Sector | floor | wall | trim | accent | fog | danger | safe |
|---|---|---|---|---|---|---|---|
| 0 Docking Bays | `#3a2f28` | `#4a3b30` | `#6b5540` | `#ffb347` | `#2a1f18` | `#2a9df4` | `#d98a3a` |
| 1 Hydroponics | `#22301f` | `#2b3a26` | `#3f5233` | `#3ad98a` | `#18240f` | `#6ad94a` | `#cfe08a` |
| 2 Engineering | `#2e3238` | `#3a3f47` | `#5a5560` | `#2a9df4` | `#1a1418` | `#ff5a3a` | `#d98a3a` |
| 3 Void Silo | `#0a0c14` | `#10131f` | `#1a2033` | `#b06ad9` | `#05060c` | `#d94a8a` | `#6a8adf` |
| 4 Event Horizon | `#f2f2f2` | `#d8d8d8` | `#101010` | `#101010` | `#cfcfcf` | `#ff2a5a` | `#8a8a8a` |

Global colour language: **safe zones** = warm copper/gold/amber; **traps** =
electric blue; **poison** = toxic green; **enemies** = blood red; **the glitch**
= negative space (white ground, black texture) or 3D↔2D wireframe flicker.

---

## 4. Turnaround helper (optional, better meshes)

If your image-to-3D node takes multiple views, generate each asset with this
wrapper around the asset prompt to force a clean multiview sheet:

```
character turnaround sheet, three views in a row: front view, 3/4 view, side
view, identical object, consistent proportions, T-pose if a creature, evenly
spaced, flat neutral grey background, <ASSET PROMPT>, <STYLE SUFFIX>
```

---

## 5. Props, hazards, pickups & gates

### Sector 0 — The Docking Bays  (industrial, rusty, cargo)

**`file: cargo_crate.glb`**  · prop · ~1 m · 300–800 tris
```
a rusted industrial cargo shipping crate, riveted metal panels, chipped copper
and amber paint, worn corner brackets, a faded hazard stripe, sturdy blocky cube
```
Texture: worn metal, `#4a3b30` base with `#ffb347` painted stripe, high roughness.

**`file: pipe_cluster.glb`**  · decor · ~1.5 m · 300–700 tris
```
a cluster of thick industrial pipes and conduits bundled together, cylindrical
tubes, valve wheels, bracket clamps, exposed ship plumbing
```
Texture: dark metal `#4a3b30`, brass valves; faint amber grime.

**`file: sliding_door.glb`**  · prop · ~2.5 m · 200–500 tris
```
a heavy sci-fi sliding blast door, single rectangular slab, recessed frame, a
thin glowing horizontal light strip, magnetic seal, brutalist
```
Texture: `#4a3b30` slab, **emissive** `#ffb347` strip (safe) — swap strip to
`#2a9df4` for locked doors.

**`file: magnet_ring.glb`**  · GATE (Magnet Boots) · ~2 m · 1500–4000 tris
```
a large floating ring electromagnet device, thick torus of banded metal coils,
copper windings, glowing energy core in the center hole, industrial mounting
struts, hovering
```
Texture: banded copper `#d98a3a`, **emissive** blue core `#2a9df4`, energy=0.8.

**`file: magnetic_pillar.glb`**  · gate scenery · 3–5 m · 800–2000 tris
```
a tall vertical magnetic pillar rising from the floor, hexagonal metal column,
stacked magnetic disc segments, glowing seams between segments, floor mount
```
Texture: `#6b5540` metal, emissive amber seams.

---

### Sector 1 — Hydroponics & Living Quarters  (overgrown, humid)

**`file: vine_ribbon.glb`**  · GATE (Wall-Run) · 3–6 m span · 1000–3000 tris
```
a giant geometric alien vine, thick faceted green cylinder like a neon ribbon,
low-poly leaves and glowing nodes along its length, spanning a gap, bright
bioluminescent
```
Texture: `#3ad98a` with **emissive** node highlights (neon ribbon look).

**`file: thorn_cluster.glb`**  · hazard · ~1.5 m · 400–900 tris
```
a cluster of sharp geometric thorns and spikes growing from a wall, angular
crystalline barbs, dark green with toxic yellow tips, menacing static spikes
```
Texture: `#2b3a26` base, `#6ad94a` tips, slight emissive on tips.

**`file: spore_vent.glb`**  · hazard emitter · ~1 m · 300–700 tris
```
an organic pod vent leaking spore gas, bulbous low-poly sac with a puckered
opening, veiny surface, resting on a metal grate, about to burst
```
Texture: `#3f5233` sac, sickly `#6ad94a` glow at the opening.

---

### Sector 2 — The Engineering Core  (high-tech, heat distortion)

**`file: laser_emitter.glb`**  · GATE (barricade to Kinetic Charge) · ~1.5 m · 800–2000 tris
```
a wall-mounted laser barricade emitter, angular metal housing, lens array,
warning chevrons, a heavy reinforced grid frame, industrial red-hot accents
```
Texture: `#3a3f47` housing, **emissive** `#ff5a3a` lens + `#2a9df4` status light.

**`file: pressure_plate.glb`**  · hazard · ~1 m · 150–400 tris
```
a floor pressure plate trap, square recessed metal panel with a raised center
tile, warning stripes around the rim, mechanical seams, flush with the ground
```
Texture: `#3a3f47` plate, `#ff5a3a` rim stripes.

**`file: reactor_vent.glb`**  · hazard/decor · ~1.5 m · 500–1200 tris
```
an overheating reactor vent, heavy metal grille over a molten glowing core,
heat-warped fins, warning labels, industrial radiator block
```
Texture: `#2e3238` grille, **emissive** molten `#ff5a3a` core (energy 1.5+).

---

### Sector 3 — The Void Silo  (zero-G, open to space)

**`file: anchor_beacon.glb`**  · GATE (Zero-G Anchor) · ~1.2 m · 1000–2500 tris
```
a handheld gravity anchor device on a floating pedestal, compact tech gadget
with a grappling emitter nozzle, folded tether arms, a glowing violet power cell,
sci-fi tool
```
Texture: `#1a2033` body, **emissive** `#b06ad9` power cell + nozzle.

**`file: black_hole_core.glb`**  · hazard · ~1.2 m · 600–1500 tris
```
a small contained singularity, dark spherical core with an accretion ring of
faceted debris orbiting it, warped space, ominous pink-violet glow, floating
```
Texture: near-black core, **emissive** `#d94a8a` ring; add subtle `#b06ad9`.

---

### Sector 4 — The Event Horizon  (surreal, glitching geometry)

**`file: reality_switch.glb`**  · GATE (Reality Bender) · ~1.5 m · 1000–2500 tris
```
an impossible geometry switch console, a monolithic pillar with a large toggle
lever, surfaces that flicker between white-solid and black-wireframe, glitch
artifacts, negative-space aesthetic
```
Texture: negative-space — white body `#f2f2f2`, black wireframe seams `#101010`,
thin **emissive** `#ff2a5a` fault line.

---

## 6. Enemies

Model at ~1.8 m tall unless noted; origin at the feet, facing `-Z`.

**`file: scrap_crawler.glb`**  · S0 · fast, low HP · 800–1800 tris
```
a small fast scrap robot crawler, low-poly quadruped body cobbled from junk
metal, glowing single optic, skittering legs, blood-red accent lights, menacing
little scavenger drone
```
Texture: rusty `#4a3b30`, **emissive** `#d94a5a` optic.

**`file: silence_guard.glb`**  · S1 · humanoid, freezes when shot · 1500–2500 tris
```
a slow humanoid infected guard, gaunt low-poly figure in a tattered crew suit,
faceless glitching head, faint green corruption veins, hollow posture, eerie
```
Texture: `#2b3a26` suit, `#6ad94a` corruption veins (low emissive).

**`file: drone_swarm.glb`**  · S2 · flies, explodes · 400–1000 tris
```
a small aggressive attack drone, faceted spherical body, four short rotor arms,
a red targeting eye, blinking charge indicators, kamikaze explosive unit
```
Texture: `#3a3f47` shell, **emissive** `#ff5a3a` eye + charge lights.

**`file: turret_spider.glb`**  · S2 · wall-climber, ranged · 1500–3000 tris
```
a robotic turret spider, four articulated legs gripping surfaces, a rotating
central turret barrel, sensor cluster, industrial blue-steel plating, wall-crawler
```
Texture: `#3a3f47` plating, **emissive** `#2a9df4` sensor + `#ff5a3a` barrel tip.

**`file: void_leaper.glb`**  · S3 · drops from ceiling · 1200–2500 tris
```
a void creature that leaps, sleek dark low-poly body with long grasping limbs, no
face, wisps of violet void energy, coiled to pounce, unsettling silhouette
```
Texture: near-black body, **emissive** `#b06ad9` energy wisps.

**`file: memory_construct.glb`**  · S4 · glitchy NPC echo · 1500–2800 tris
```
a glitching humanoid memory ghost, a flickering translucent crew-member figure
half dissolving into black wireframe and white voxels, corrupted hologram,
negative-space distortion
```
Texture: white `#f2f2f2` + black `#101010` wireframe, **emissive** `#ff2a5a`
glitch scanlines; enable alpha for translucency.

**`file: core_guardian.glb`**  · S2 mini-boss · splits when hit · 3000–6000 tris
```
a giant slow guardian cube boss, massive faceted metal cube with glowing seams
that hint at smaller cubes inside, a single central eye, heavy armored plating,
imposing
```
Texture: `#3a3f47` armor, **emissive** `#2a9df4` seams + `#ff5a3a` eye.

**`file: nexus.glb`**  · S4 final boss · 6000–12000 tris
```
NEXUS, a terrifying geometric AI entity of pure logic, a large floating
polyhedron core surrounded by rotating angular rings and shards, cold white and
black negative-space surfaces, red fault lines, godlike and menacing
```
Texture: white/black negative-space, **emissive** `#ff2a5a` core + fault lines.

---

## 7. Pickups & narrative props

**`file: tech_node.glb`**  · pickup (lore log) · ~0.5 m · 150–500 tris
```
a small holographic data node pickup, a faceted crystal shard in a floating
metal cradle, projecting a faint hologram glyph, glowing, collectible sci-fi item
```
Texture: `#6b5540` cradle, **emissive** `#ffb347` crystal (pulses in-engine).

**`file: blueprint.glb`**  · pickup (Tech Tree) · ~0.5 m · 150–500 tris
```
a glowing schematic blueprint chip, a flat translucent tech tablet showing wire-
frame engineering diagrams, thin bezel, hovering, collectible upgrade item
```
Texture: dark bezel, **emissive** `#2a9df4` schematic lines.

**`file: health_cell.glb`**  · pickup (heal) · ~0.4 m · 150–400 tris
```
a hexagonal energy cell pickup, small canister of glowing restorative fluid, ribbed
metal casing, warm inviting light, collectible power item
```
Texture: `#5a5560` casing, **emissive** warm `#ffce42` fluid.

**`file: echo_debris.glb`**  · decor (permadeath echo marker) · ~1 m · 300–800 tris
```
a somber pile of debris marking a death, scattered scrap and a broken helmet with
a faintly flickering distress light, a small holographic ghost note hovering above,
melancholy memorial
```
Texture: charred `#3a2f28` scrap, **emissive** faint `#d94a5a` distress blink +
pale `#8fa4c4` note hologram. (Spawned wherever a past run died.)

---

## 8. Environment kit (optional — replaces the box-built rooms)

The level geometry is grey-boxed from slabs in code. To art-pass a sector, make
a **modular kit** at a **4 m grid** and swap it in via a `Sector` variant (not
required for play). Generate each as its own file if you go this route:

**`file: wall_slab_<sector>.glb`** — `a giant brutalist metal wall slab panel,
riveted seams, a thin glowing edge strip, modular tiling section`

**`file: floor_tile_<sector>.glb`** — `a heavy industrial floor plate, low tread
pattern, recessed panel lines, modular square tile`

**`file: platform_<sector>.glb`** — `a floating angular platform, thick metal
slab with a glowing underside rim, support struts`

Texture all three to the sector row in §3 (floor/wall/trim + emissive accent).

**Skybox (Void Silo / Event Horizon):** generate an equirectangular starfield
for a `PanoramaSkyMaterial`: `deep space starfield, distant faint galaxies, a
single small bright star sun, mostly black, subtle nebula, equirectangular 2:1
panorama, no planets, no text` (negative: `bright, colorful, busy, foreground
objects`).

---

## 9. Batch checklist

- [ ] Fix one seed per sector; reuse the style suffix so a set matches.
- [ ] Render Stage-2 at 1024², one object, flat grey bg.
- [ ] Image-to-3D → GLB → decimate to the §/README budget.
- [ ] Texture via flat-material (palette §3) **or** baked albedo; keep roughness
      high, metallic ~0, put all glow on **emission**.
- [ ] Origin at base, forward = `-Z`, ~1 unit = 1 m.
- [ ] Save as `assets/models/<exact-name>.glb`; launch — the placeholder is gone.
- [ ] `Forge.has_model("<name>")` returns true; silhouette still reads in-game.
