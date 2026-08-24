# Assets — placeholder-swap pipeline

Fractured Orbit ships **playable with zero external art**: every visible object
is built from Godot primitives by `scripts/MeshFactory.gd` (autoload `Forge`).
You replace those placeholders **one file at a time**, with no code changes.

## How the swap works

Every prop, enemy, pickup and gate is requested by a *logical name*:

```gdscript
var node := Forge.model("cargo_crate")   # returns a Node3D, ready to parent
```

`Forge.model(name)` resolves in this order:

1. `res://assets/models/<name>.glb`   ← your generated model, if present
2. `res://assets/models/<name>.tscn`  ← a hand-made scene, if present
3. a **primitive placeholder**, tinted by the asset's category

So the moment you drop `assets/models/cargo_crate.glb` into the project, every
cargo crate in the game becomes your model. Delete it and the placeholder
returns. `Forge.has_model(name)` tells you which assets are still placeholders.

## Naming

File basename **must** match the logical name exactly (see the full list and the
generation prompts in [`../docs/COMFYUI_ASSET_PROMPTS.md`](../docs/COMFYUI_ASSET_PROMPTS.md)).
Examples: `cargo_crate.glb`, `scrap_crawler.glb`, `magnet_ring.glb`,
`echo_debris.glb`.

## Import settings (low-poly)

When Godot imports a `.glb`, open its **Import** dock and set:

- **Meshes → Ensure Tangents**: on (needed if you bake normal maps)
- **Materials → Location**: *Built-In* (keeps the file self-contained), or
  *External* if you want to retheme per sector.
- Keep **Lightmap UV** off unless you bake lightmaps.
- Origin at the model's **feet/base** and forward = `-Z` so placement matches the
  primitive placeholders (which sit on `y = 0`, facing `-Z`).

## Scale & budget

Match the placeholder footprints (roughly 1 world unit = 1 metre):

| Category | Target tris | Footprint |
|----------|-------------|-----------|
| Small prop / pickup | 150–600 | ≤ 1 m |
| Crate / vent / plate | 300–800 | ~1 m |
| Enemy (basic) | 800–2500 | ~0.8 × 1.8 m |
| Gate device | 1500–4000 | 1–2 m |
| Mini-boss / boss | 4000–12000 | 2–4 m |

Everything is deliberately low-poly; hard facets and a single flat-shaded
material per part are the look. See the art-direction section of the prompt
library before generating.
