# HD 2D Style Brief — Octopath Traveler

**Source**: https://www.youtube.com/watch?v=tuKHsssldTE (Design Doc — The Design of Octopath Traveler)  
**Concept**: HD 2D art style

---

## Concept Summary

Octopath Traveler's HD 2D is a deliberate collision of two eras: pixel-art sprites and UI live on a plane that floats inside a fully 3D, physically-lit environment. The camera sits at a fixed diagonal 2.5D angle, with aggressive depth-of-field blur on foreground and background objects, forcing the eye to the pixel-art midground where everything "real" happens. The result reads as a diorama — miniature, precious, and atmospheric — rather than a flat 2D game.

---

## Color Palette

| Role | Hex | Description |
|---|---|---|
| Warm parchment / UI gold | `#C8922A` | Menu borders, title cards, warm amber backgrounds |
| Deep shadow brown | `#2A1A0A` | Character outlines, shadow fill, unlit interiors |
| Muted stone / dungeon mid | `#6B5A40` | Stone walls, dirt paths, neutral environment base |
| Rich crimson red | `#8B1A1A` | Carpet (throne room), accent highlights, danger states |
| Fog/bloom white | `#E8D4A0` | Bloom halos around torches, god-rays, horizon glow |
| Deep forest green | `#2A4A1A` | Exterior night foliage, background trees |
| Cold slate blue | `#3A4A5A` | Night sky, dungeon shadow gradient, fog mid-layer |
| Ember gold | `#F0A020` | Torch light, magic effects, UI highlight |

---

## Lighting

- **Direction**: Top-down or top-left, matching isometric readability. Torches create tight local warm pools (orange-gold).
- **Quality**: Hard pixel shadows on sprites, soft volumetric bloom on the 3D environment — the contrast between the two is the whole trick.
- **Bloom**: Heavy and deliberate. Light sources bleed well beyond their origin. Bloom makes the world feel alive vs. the sprites.
- **Time-of-day**: Most scenes skew dusk-to-night. Even daytime scenes are desaturated and moody — overcast or golden hour only, no harsh midday sun.
- **Interior**: Candlelight only. Very dark with isolated warm spots. High contrast ratios (~20:1 between lit and unlit areas).

---

## Sprite Style

- **Pixel resolution**: Low-to-medium density — ~32–48px tall for a character in-world.
- **Outlines**: Hard single-pixel black outlines on all characters and interactive objects. No anti-aliasing on sprites.
- **Shading**: Flat cel-style with 2–4 shades per color. No gradients within a sprite color area.
- **Scale trick**: Sprites rendered at fixed pixel resolution regardless of camera distance. The 3D background scales normally; sprites don't. This creates the "miniature world" feeling.
- **Detail level**: High costume/equipment detail but silhouette always reads first.

---

## Depth & Layering

Four distinct depth planes:

1. **Foreground** (extreme blur, 3D geometry) — foliage, railings, architectural framing elements
2. **Midground** (sharp, pixel-art plane) — all characters, interactive objects, key set pieces
3. **Backdrop** (mild blur, 3D geometry) — environment world giving sense of scale
4. **Sky/atmosphere** (heavy fog/glow) — fills space behind everything, provides mood

DoF falloff is steep and aggressive. Anything 2+ layers from the sprite plane is noticeably soft. **This is the single most important technical element** — without it, it just looks like a 2D game.

---

## Animation Notes

- **Sprite animation**: ~8–12 fps, intentionally choppy. Limited animation; characters don't move between idle frames.
- **Particles**: Fully 3D, high quality, rendered over the sprite plane. Low-res sprite + hi-res particles = key contrast.
- **Ambient motion**: 3D environment layers have subtle movement (swaying trees, flickering torchlight). Sprite plane is static.
- **Camera**: Fixed-angle, gentle character follow. ~30° diagonal tilt from ground. No dynamic cuts during exploration.
- **Dialogue**: Ornate bordered panels, animated text reveal, minimal portrait animation.

---

## Technical Notes (Godot 4 Implementation)

- **DOF**: `DOFBlurFarEnabled` + `DOFBlurNearEnabled` in WorldEnvironment — near blur on objects in front of character plane, far blur on background geometry
- **Sprite rendering**: SubViewport at fixed low resolution (e.g. 320×180), nearest-neighbor upscale, composited over 3D world via CanvasLayer
- **Lighting**: `OmniLight3D` warm orange for torches, very short range, high attenuation. WorldEnvironment glow with high bloom threshold
- **Fog**: FogVolume or environment fog to visually separate depth layers
- **Sprite shader**: Nearest-neighbor sampling, hard alpha cutoff — no semi-transparent pixels on character edges

---

## Application Prompts

1. **Environment art**: *"HD 2D isometric exterior village scene, pixel art characters on a 3D stone-and-wood environment, candlelight torches, heavy bokeh depth-of-field blur on background buildings, dusk golden-hour sky, Octopath Traveler visual style"*

2. **Character sprite**: *"32x48 pixel art warrior character, hard black outline, flat cel shading 4 colors, medieval armor with cape, transparent background, Octopath Traveler sprite style"*

3. **Environment shader**: *"Godot 4 WorldEnvironment config for HD 2D: aggressive near+far DOF blur, warm orange volumetric bloom from point lights, desaturated ambient with high contrast, dusk color grading"*

4. **Interior scene**: *"HD 2D dungeon interior, pixel art sprites in foreground, 3D stone wall environment with torch sconces behind, near-black shadows with isolated warm light pools, Gothic stone arches, heavy fog in corridors"*

5. **UI design**: *"Octopath Traveler-style game UI, ornate parchment-and-gold border frames, pixel font, dark background with warm amber highlights, minimal icons with hand-drawn quality"*

---

## Key Reference Frames

- **tile_007** — diorama effect: 3D town exterior, pixelated foreground building, DoF blur on far buildings
- **tile_049 / tile_056** — night exterior lighting, torches + deep shadow
- **tile_070** — torch-lit temple entrance, ideal light-to-dark ratio
- **tile_077** — characters on lit stage, sprite outline + scale vs. 3D world
- **tile_119** — throne room, crimson accent color, 3D architecture behind flat sprites
