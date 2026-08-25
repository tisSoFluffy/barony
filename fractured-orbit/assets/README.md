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

## Clean the export before you drop it in

The concept references we feed the texture workflow show the subject standing on
a floor, so the shape stage reconstructs that floor as a wide flat disc welded to
the subject. It is not a cosmetic problem: on our exports it has been **85–91% of
the 40k triangle budget** and it is the widest thing in the mesh, so the auto-fit
below scales the model to fit its *floor* rather than itself. It also soaks up
most of the UV atlas, leaving the subject a fraction of the texture resolution.

Run every fresh export through the cleaner, which strips the plane, drops unused
vertices and adds the vertex normals the workflow omits:

```
python tools/clean_gen_mesh.py <comfy>/output/textured/character_00009_.glb \
    assets/models/silence_guard.glb --yaw 180
```

`--yaw` turns the model to face `-Z` (the facing everything in
`docs/COMFYUI_ASSET_PROMPTS.md` is authored to); check which way yours came out
with `tools/shot_model.gd` below. The real fix upstream is to generate the
concept reference on a plain cut-out background — no floor, no cast shadow —
which gives the subject the whole triangle budget and the whole atlas.

## Auto-fit on load (you do not need to pre-scale)

Image-to-3D nodes (Hunyuan3D, TripoSR, InstantMesh …) export their mesh
**normalised into a unit cube centred on the origin** — dropped in raw, a model
would float at half its height and be the wrong size. `Forge.model()` therefore
normalises every generated file on the way out:

* uniform scale so the **longest axis** matches the asset's documented size,
* base rebased to `y = 0`, centred in XZ.

The result is an outer `Node3D` with an identity transform, so callers keep
setting `position`/`rotation` exactly as they did for the placeholder.

Per-asset target sizes live in `_model_size` in `scripts/MeshFactory.gd`; an
asset with no row falls back to its category default (`prop` 1.0 m, `gate` 2.0 m,
`enemy` 1.8 m, `pickup` 0.5 m, …). If a model reads too big or small in-engine,
edit that one number — do not re-export the file.

Sanity check what is wired and how it lands, then look at it:

```
godot --headless --path fractured-orbit -s tools/check_models.gd
godot --path fractured-orbit --resolution 520x520 -s tools/shot_model.gd -- silence_guard
```

`shot_model.gd` writes `shot_0..3.png` (front, 3/4, side, back) to the project's
`user://` directory — worth a look before trusting a model in a sector, since a
mesh can land at the right size and still be facing backwards.

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
