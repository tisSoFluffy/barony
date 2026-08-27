extends Node3D

## Builds the whole playground in code and owns the win condition.
##
## Everything is constructed here rather than authored as a .tscn, which keeps
## the level data readable as plain arrays and means the project can be checked
## headlessly without a scene file drifting out of sync with the scripts.

const SPARKLE_TARGET := 8
const FALL_LIMIT := -12.0        # below this you get put back on the spawn pad

# Hand-placed layout. Sparkles sit on a loose ring plus a few up on the arches,
# so some of them need a bounce (or Bouncy Blue's double jump) to reach.
const SPARKLE_SPOTS := [
	Vector3(4, 0.9, 3), Vector3(-5, 0.9, 4), Vector3(7, 0.9, -3),
	Vector3(-7, 0.9, -5), Vector3(0, 0.9, 9), Vector3(11, 0.9, 6),
	Vector3(-11, 0.9, -1), Vector3(2, 4.6, -8), Vector3(-3, 4.6, 7),
	Vector3(9, 5.4, -9),
]

const ARCH_SPOTS := [
	{"pos": Vector3(2, 0, -8), "yaw": 0.0},
	{"pos": Vector3(-8, 0, 3), "yaw": 1.2},
	{"pos": Vector3(9, 0, -9), "yaw": -0.6},
]

const SPAWN := Vector3(0, 1.2, 6)

var _player: Player
var _camera: FollowCamera
var _hud: HUD
var _gate: Gate
var _sparkles := 0
var _won := false


func _ready() -> void:
	randomize()
	_build_environment()
	_build_ground()
	_build_gate()
	_build_arches()
	_build_sparkles()
	_build_ball()
	_build_player()
	_build_hud()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return

	if _player != null:
		# Movement is camera-relative, so the camera has to publish its yaw.
		_player.camera_yaw = _camera.yaw
		if _player.global_position.y < FALL_LIMIT:
			_respawn()


# -- world ---------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.45, 0.72, 0.95)
	sky_material.sky_horizon_color = Color(0.90, 0.93, 0.98)
	sky_material.ground_bottom_color = Color(0.72, 0.86, 0.70)
	sky_material.ground_horizon_color = Color(0.88, 0.92, 0.95)
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# The generator bakes its own lighting into the albedo, so these textures
	# arrive already lit. Stacking a bright sky ambient on top blows every
	# model out to white - keep ambient low and let the sun do the shaping.
	env.ambient_light_energy = 0.22
	# AGX deliberately desaturates towards white, which on already-bright baked
	# albedo turned the whole meadow into pastel soup. Filmic holds the colour.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -125, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.97, 0.90)
	sun.shadow_enabled = true
	add_child(sun)

	# A dim fill from the opposite side keeps shadowed faces readable without
	# raising overall exposure.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 60, 0)
	fill.light_energy = 0.25
	fill.light_color = Color(0.82, 0.88, 1.0)
	fill.shadow_enabled = false
	add_child(fill)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"

	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(70, 70)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.44, 0.70, 0.32)
	mat.roughness = 0.95
	plane.material = mat
	mesh.mesh = plane
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(70, 1.0, 70)
	col.shape = box
	col.position.y = -0.5      # top face sits exactly at y = 0
	body.add_child(col)

	add_child(body)


func _build_gate() -> void:
	_gate = Gate.new()
	_gate.name = "Gate"
	_gate.required = SPARKLE_TARGET
	_gate.position = Vector3(0, 0, -14)
	_gate.entered.connect(_on_gate_entered)
	add_child(_gate)


func _build_arches() -> void:
	for i in ARCH_SPOTS.size():
		var spot: Dictionary = ARCH_SPOTS[i]
		var pad := BouncePad.new()
		pad.name = "Arch%d" % i
		pad.position = spot["pos"]
		pad.rotation.y = spot["yaw"]
		add_child(pad)


func _build_sparkles() -> void:
	for i in SPARKLE_SPOTS.size():
		var sparkle := Sparkle.new()
		sparkle.name = "Sparkle%d" % i
		sparkle.position = SPARKLE_SPOTS[i]
		sparkle.collected.connect(_on_sparkle_collected)
		add_child(sparkle)


## A physics ball to knock around. Pure toy - it is not required to finish.
func _build_ball() -> void:
	var body := RigidBody3D.new()
	body.name = "Ball"
	body.position = Vector3(3.5, 1.5, 1.0)
	body.mass = 0.6

	var physics := PhysicsMaterial.new()
	physics.bounce = 0.62
	physics.friction = 0.45
	body.physics_material_override = physics

	body.add_child(Models.spawn_wide("res://assets/models/ball.glb", 0.7, false))

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	col.shape = sphere
	col.position.y = 0.35     # model sits on its own origin, collider centred
	body.add_child(col)

	add_child(body)


func _build_player() -> void:
	_player = Player.new()
	_player.name = "Player"
	_player.position = SPAWN
	_player.swapped.connect(_on_player_swapped)
	add_child(_player)

	_camera = FollowCamera.new()
	_camera.target = _player
	add_child(_camera)


func _build_hud() -> void:
	_hud = HUD.new()
	add_child(_hud)
	_hud.set_sparkles(0, SPARKLE_TARGET)
	_hud.set_character(String(_player.character["name"]))


# -- game state ----------------------------------------------------------

func _on_sparkle_collected(_sparkle: Sparkle) -> void:
	_sparkles += 1
	_gate.set_sparkles(_sparkles)
	_hud.set_sparkles(_sparkles, _gate.remaining())
	if _gate.is_open() and not _won:
		_hud.show_banner("The gate is open!")
		_clear_banner_after(1.8)


func _on_player_swapped(def: Dictionary) -> void:
	if _hud != null:
		_hud.set_character(String(def["name"]))


func _on_gate_entered() -> void:
	if _won:
		return
	_won = true
	_hud.show_banner("You made it home!")


func _respawn() -> void:
	_player.velocity = Vector3.ZERO
	_player.global_position = SPAWN


func _clear_banner_after(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if not _won:
		_hud._banner.visible = false
