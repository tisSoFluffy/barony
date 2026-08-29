extends Node3D

## Builds the whole playground in code and owns the win condition.
##
## Everything is constructed here rather than authored as a .tscn, which keeps
## the level data readable as plain arrays and means the project can be checked
## headlessly without a scene file drifting out of sync with the scripts.

const SPARKLE_TARGET := 8
const STAR_TARGET := 10
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

# Numbered stars, 1..10, strung in a loop around the meadow starting just in
# front of the spawn pad and running clockwise. All on the ground and reachable
# on foot with either character - this is a counting lap, not a platforming one.
const STAR_SPOTS := [
	Vector3(1, 0.9, 3), Vector3(7, 0.9, 1), Vector3(9, 0.9, -4),
	Vector3(6, 0.9, -9), Vector3(0, 0.9, -11), Vector3(-6, 0.9, -9),
	Vector3(-10, 0.9, -3), Vector3(-9, 0.9, 3), Vector3(-5, 0.9, 8),
	Vector3(-3, 0.9, 10),
]

const SPAWN := Vector3(0, 1.2, 6)

# Fantasy set dressing - all generated GLBs, all non-interactive. `m` is the
# model basename under assets/models/; `p` is where its feet go. Optional:
# `h` height in metres (default 1.5), `w` scale by footprint not height,
# `y` yaw, `solid` a trunk/base collider, `sway` idle plant rock, `bob` cloud
# drift. Placed clear of the sparkle ring and the star trail.
const DECOR := [
	# Fountain: the centrepiece the meadow is arranged around.
	{"m": "sparkle_fountain", "p": Vector3(0, 0, -3), "h": 2.7, "solid": true,
		"sr": 1.7, "sh": 1.3},

	# A ring of candy trees well out past the play area - the treeline.
	{"m": "candy_tree", "p": Vector3(-18, 0, 11), "h": 6.0, "y": 0.4, "solid": true, "sr": 0.5, "sh": 3.0, "sway": 0.015},
	{"m": "candy_tree", "p": Vector3(-22, 0, -7), "h": 5.4, "y": 1.7, "solid": true, "sr": 0.5, "sh": 3.0, "sway": 0.02},
	{"m": "candy_tree", "p": Vector3(-15, 0, -21), "h": 6.6, "y": 2.6, "solid": true, "sr": 0.5, "sh": 3.0, "sway": 0.015},
	{"m": "candy_tree", "p": Vector3(17, 0, -21), "h": 6.1, "y": -0.6, "solid": true, "sr": 0.5, "sh": 3.0, "sway": 0.018},
	{"m": "candy_tree", "p": Vector3(23, 0, -3), "h": 5.5, "y": -1.4, "solid": true, "sr": 0.5, "sh": 3.0, "sway": 0.02},
	{"m": "candy_tree", "p": Vector3(19, 0, 15), "h": 6.2, "y": 0.9, "solid": true, "sr": 0.5, "sh": 3.0, "sway": 0.015},
	{"m": "candy_tree", "p": Vector3(-3, 0, -25), "h": 7.0, "y": 0.2, "solid": true, "sr": 0.6, "sh": 3.0, "sway": 0.012},

	# A flower patch on the west side, plus a few strays.
	{"m": "giant_flower", "p": Vector3(-13.5, 0, 2), "h": 2.4, "y": 0.3, "sway": 0.05},
	{"m": "giant_flower", "p": Vector3(-15, 0, 4), "h": 2.0, "y": 1.1, "sway": 0.06},
	{"m": "giant_flower", "p": Vector3(-12.5, 0, 5.5), "h": 2.6, "y": -0.5, "sway": 0.05},
	{"m": "giant_flower", "p": Vector3(-14.5, 0, -1), "h": 2.2, "y": 2.0, "sway": 0.055},
	{"m": "giant_flower", "p": Vector3(13, 0, 1.5), "h": 2.3, "y": 0.8, "sway": 0.05},
	{"m": "giant_flower", "p": Vector3(-1.5, 0, 13), "h": 2.5, "y": -1.2, "sway": 0.05},
	{"m": "giant_flower", "p": Vector3(12, 0, -12), "h": 2.1, "y": 1.6, "sway": 0.06},

	# Toadstools dotted through the mid-field.
	{"m": "toadstool", "p": Vector3(-4, 0, 5.5), "h": 1.6, "y": 0.5},
	{"m": "toadstool", "p": Vector3(5.5, 0, 7), "h": 1.3, "y": 2.1},
	{"m": "toadstool", "p": Vector3(-9.5, 0, -1.5), "h": 1.7, "y": -0.8},
	{"m": "toadstool", "p": Vector3(11.5, 0, -6), "h": 1.4, "y": 1.2},
	{"m": "toadstool", "p": Vector3(-12.5, 0, 7.5), "h": 1.5, "y": 3.0},
	{"m": "toadstool", "p": Vector3(4.5, 0, -13), "h": 1.6, "y": -2.0},
	{"m": "toadstool", "p": Vector3(-6.5, 0, 11), "h": 1.2, "y": 0.9},

	# Crystal clusters as glinting accents.
	{"m": "crystal_cluster", "p": Vector3(-6.5, 0, -12.5), "h": 2.0, "y": 0.4},
	{"m": "crystal_cluster", "p": Vector3(13.5, 0, 3), "h": 1.8, "y": 1.5},
	{"m": "crystal_cluster", "p": Vector3(-13, 0, -9), "h": 2.4, "y": -0.7},
	{"m": "crystal_cluster", "p": Vector3(7.5, 0, 11.5), "h": 1.7, "y": 2.3},
	{"m": "crystal_cluster", "p": Vector3(14, 0, -8), "h": 2.1, "y": -1.9},

	# A few small clouds floating high and out at the edges - pure backdrop, well
	# above the highest jump. Repainted flat white: the raw TRELLIS texture has a
	# speckled UV-seam crackle that a plain matte reads straight past.
	{"m": "cloud_puff", "p": Vector3(-24, 14, 6), "h": 3.6, "w": true, "bob": 0.4, "repaint": Color(0.97, 0.98, 1.0)},
	{"m": "cloud_puff", "p": Vector3(22, 15, -3), "h": 4.0, "w": true, "bob": 0.45, "bob_hz": 0.09, "repaint": Color(0.97, 0.98, 1.0)},
	{"m": "cloud_puff", "p": Vector3(-7, 16, -26), "h": 3.2, "w": true, "bob": 0.35, "bob_hz": 0.11, "repaint": Color(0.97, 0.98, 1.0)},
	{"m": "cloud_puff", "p": Vector3(15, 13, 21), "h": 3.6, "w": true, "bob": 0.4, "bob_hz": 0.08, "repaint": Color(0.97, 0.98, 1.0)},
]

# Spoken "One!" .. "Ten!" - one clip per star, played on pickup. Rendered from
# the Windows voice; see tools/make_count_voices.ps1.
const STAR_VOICES: Array[AudioStream] = [
	preload("res://assets/audio/count_01.wav"),
	preload("res://assets/audio/count_02.wav"),
	preload("res://assets/audio/count_03.wav"),
	preload("res://assets/audio/count_04.wav"),
	preload("res://assets/audio/count_05.wav"),
	preload("res://assets/audio/count_06.wav"),
	preload("res://assets/audio/count_07.wav"),
	preload("res://assets/audio/count_08.wav"),
	preload("res://assets/audio/count_09.wav"),
	preload("res://assets/audio/count_10.wav"),
]

var _player: Player
var _camera: FollowCamera
var _hud: HUD
var _gate: Gate
var _sparkles := 0
var _stars := 0
var _all_stars := false
var _won := false
var _voice: AudioStreamPlayer


func _ready() -> void:
	randomize()
	_build_environment()
	_build_ground()
	_build_gate()
	_build_arches()
	_build_decor()
	_build_sparkles()
	_build_stars()
	_build_ball()
	_build_player()
	_build_bunny()
	_build_butterfly()
	_build_hud()

	# One shared voice player, non-positional so the number is always clear no
	# matter where on the trail the star was grabbed.
	_voice = AudioStreamPlayer.new()
	_voice.name = "StarVoice"
	_voice.volume_db = 2.0
	add_child(_voice)


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
	fill.light_energy = 0.34
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


func _build_decor() -> void:
	for i in DECOR.size():
		var d: Dictionary = DECOR[i]
		var prop := Decor.new()
		prop.name = "Decor_%s_%d" % [d["m"], i]
		prop.model_path = "res://assets/models/%s.glb" % d["m"]
		prop.height = float(d.get("h", 1.5))
		prop.by_width = bool(d.get("w", false))
		prop.yaw = float(d.get("y", 0.0))
		prop.solid = bool(d.get("solid", false))
		prop.solid_radius = float(d.get("sr", 0.5))
		prop.solid_height = float(d.get("sh", 2.0))
		prop.sway = float(d.get("sway", 0.0))
		prop.bob = float(d.get("bob", 0.0))
		prop.bob_hz = float(d.get("bob_hz", 0.12))
		prop.repaint = d.get("repaint", Color(0, 0, 0, 0))
		prop.position = d["p"]
		add_child(prop)


func _build_stars() -> void:
	for i in STAR_SPOTS.size():
		var star := Star.new()
		star.name = "Star%d" % (i + 1)
		star.number = i + 1
		star.position = STAR_SPOTS[i]
		star.collected.connect(_on_star_collected)
		add_child(star)


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


## Ms. Bumbleflower, who hops around the meadow by herself. She needs to know
## about the player so she can spook and bound away when you get close.
func _build_bunny() -> void:
	var bunny := Bunny.new()
	bunny.name = "Bunny"
	bunny.position = Vector3(-4.5, 0.4, 2.5)
	bunny.player = _player
	add_child(bunny)


## A butterfly doing laps of the flowers. Her waypoints are pulled straight out
## of DECOR, so she always visits whatever is actually planted in the meadow -
## move a flower and she follows it.
func _build_butterfly() -> void:
	var perches := PackedVector3Array()
	for d in DECOR:
		if d["m"] == "giant_flower" or d["m"] == "toadstool":
			perches.append(d["p"])

	var fly := Butterfly.new()
	fly.name = "Butterfly"
	fly.perches = perches
	fly.position = Vector3(-12.5, 2.6, 3.5)
	add_child(fly)


func _build_hud() -> void:
	_hud = HUD.new()
	add_child(_hud)
	_hud.set_sparkles(0, SPARKLE_TARGET)
	_hud.set_stars(0, STAR_TARGET)
	_hud.set_character(String(_player.character["name"]))


# -- game state ----------------------------------------------------------

func _on_sparkle_collected(_sparkle: Sparkle) -> void:
	_sparkles += 1
	_gate.set_sparkles(_sparkles)
	_hud.set_sparkles(_sparkles, _gate.remaining())
	if _gate.is_open() and not _won:
		_hud.show_banner("The gate is open!")
		_clear_banner_after(1.8)


func _on_star_collected(star: Star) -> void:
	_stars += 1
	_hud.set_stars(_stars, STAR_TARGET)

	# Say the star's own number - "One!", "Two!", ... - as it is picked up.
	var i: int = clampi(star.number - 1, 0, STAR_VOICES.size() - 1)
	_voice.stream = STAR_VOICES[i]
	_voice.play()
	if _stars >= STAR_TARGET and not _all_stars:
		_all_stars = true
		_hud.show_banner("You found all ten stars!")
		_clear_banner_after(2.2)


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
