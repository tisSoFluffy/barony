extends Node
## Low-poly art factory + the placeholder-swap layer.
##
## The whole game currently renders from Godot primitives (boxes, prisms,
## cylinders) so it is playable with ZERO external art. Every visible thing is
## requested by a logical asset name via `model(name)`:
##
##   * If res://assets/models/<name>.glb (or .tscn) exists — i.e. you have
##     generated it through the ComfyUI text->img->model->texture pipeline and
##     dropped it in — it is instanced and used.
##   * Otherwise a chunky primitive PLACEHOLDER is built, tinted to the asset's
##     category so the silhouette still reads on the grey-box level.
##
## This means: ship the game today with primitives, then replace props one at a
## time by adding files to res://assets/models/ — no code changes. The asset
## names here are exactly the ones documented in docs/COMFYUI_ASSET_PROMPTS.md.

const MODEL_DIR := "res://assets/models/"

# Category tint used when a real model has not been generated yet.
var _placeholder_tint := {
	"prop": Color("6b5540"),
	"hazard": Color("ff5a3a"),
	"enemy": Color("d94a5a"),
	"pickup": Color("ffce42"),
	"gate": Color("2a9df4"),
	"decor": Color("4a4a55"),
}

# Which category each known asset belongs to (drives placeholder shape + tint).
var _asset_category := {
	"cargo_crate": "prop", "pipe_cluster": "decor", "sliding_door": "prop",
	"magnet_ring": "gate", "magnetic_pillar": "gate", "tech_node": "pickup",
	"vine_ribbon": "gate", "thorn_cluster": "hazard", "spore_vent": "hazard",
	"laser_emitter": "hazard", "pressure_plate": "hazard", "reactor_vent": "hazard",
	"anchor_beacon": "gate", "black_hole_core": "hazard", "reality_switch": "gate",
	"scrap_crawler": "enemy", "silence_guard": "enemy", "drone_swarm": "enemy",
	"turret_spider": "enemy", "void_leaper": "enemy", "memory_construct": "enemy",
	"core_guardian": "enemy", "nexus": "enemy",
	"health_cell": "pickup", "blueprint": "pickup", "echo_debris": "decor",
}

## ---- Materials ------------------------------------------------------------

## A flat, matte low-poly material. `emit` > 0 makes it a glowing strip/light.
func mat(color: Color, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.metallic = 0.0
	# Hard low-poly look: no specular sparkle, crisp facets.
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	return m

const GLITCH_SHADER := "res://assets/shaders/glitch.gdshader"
var _glitch_shader_mat: ShaderMaterial

## The animated 2D<->3D wireframe glitch material (Event Horizon). Cached; falls
## back to a static negative-space material if the shader can't be loaded.
func glitch_shader_mat() -> Material:
	if _glitch_shader_mat != null:
		return _glitch_shader_mat
	if ResourceLoader.exists(GLITCH_SHADER):
		var sh := load(GLITCH_SHADER)
		if sh is Shader:
			var m := ShaderMaterial.new()
			m.shader = sh
			_glitch_shader_mat = m
			return m
	return glitch_mat(true)

## A slab wearing the animated glitch material.
func glitch_slab(size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = glitch_shader_mat()
	return mi

## A negative-space "glitch" material for the Event Horizon / reality breaks.
func glitch_mat(invert: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE if invert else Color.BLACK
	m.roughness = 1.0
	m.metallic = 0.0
	m.emission_enabled = true
	m.emission = (Color.WHITE if invert else Color("101010"))
	m.emission_energy_multiplier = 0.4
	return m

## ---- Primitive meshes -----------------------------------------------------

func slab(size: Vector3, color: Color, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat(color, emit)
	return mi

func pillar(radius: float, height: float, color: Color, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 6   # hexagonal — reads as low-poly
	mi.mesh = cyl
	mi.material_override = mat(color, emit)
	return mi

func prism(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = size
	mi.mesh = p
	mi.material_override = mat(color)
	return mi

## ---- Asset resolution (placeholder swap) ----------------------------------

## Returns a Node3D for the named asset: a generated model if present, else a
## primitive placeholder. Callers parent + position the result.
func model(name: String) -> Node3D:
	var glb := MODEL_DIR + name + ".glb"
	var scn := MODEL_DIR + name + ".tscn"
	if ResourceLoader.exists(glb):
		var packed := load(glb)
		if packed is PackedScene:
			var inst := (packed as PackedScene).instantiate()
			if inst is Node3D:
				return inst as Node3D
	if ResourceLoader.exists(scn):
		var packed2 := load(scn)
		if packed2 is PackedScene:
			var inst2 := (packed2 as PackedScene).instantiate()
			if inst2 is Node3D:
				return inst2 as Node3D
	return _placeholder(name)

## True when a real generated model backs this asset name (for tooling/HUD).
func has_model(name: String) -> bool:
	return ResourceLoader.exists(MODEL_DIR + name + ".glb") \
		or ResourceLoader.exists(MODEL_DIR + name + ".tscn")

func _placeholder(name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "ph_" + name
	var cat := String(_asset_category.get(name, "prop"))
	var tint: Color = _placeholder_tint.get(cat, Color("888888"))
	match cat:
		"enemy":
			# stacked body + head so an enemy silhouette reads even as a box-bot
			var body := slab(Vector3(0.7, 1.1, 0.7), tint)
			body.position = Vector3(0, 0.55, 0)
			root.add_child(body)
			var head := slab(Vector3(0.45, 0.45, 0.45), tint.lightened(0.2), 0.3)
			head.position = Vector3(0, 1.35, 0)
			root.add_child(head)
		"pickup":
			var gem := prism(Vector3(0.4, 0.5, 0.4), tint)
			gem.position = Vector3(0, 0.4, 0)
			root.add_child(gem)
		"gate":
			var g := pillar(0.5, 2.0, tint, 0.8)
			g.position = Vector3(0, 1.0, 0)
			root.add_child(g)
		"hazard":
			var hz := slab(Vector3(1.0, 0.2, 1.0), tint, 0.6)
			hz.position = Vector3(0, 0.1, 0)
			root.add_child(hz)
		_:
			var b := slab(Vector3(0.9, 0.9, 0.9), tint)
			b.position = Vector3(0, 0.45, 0)
			root.add_child(b)
	return root
