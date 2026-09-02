class_name Player
extends CharacterBody3D

## Controller-first character movement for two unrigged models.
##
## Because neither model has a skeleton, every bit of life in the character is
## procedural and lives in `_animate()`: a spring-driven squash/stretch, a hop
## bob while running, and a lean into the direction of travel. That is also why
## the visual sits under a separate `_visual` node - we scale and tilt that
## freely without ever touching the collision capsule.

signal swapped(character: Dictionary)
signal landed(impact: float)

const COYOTE_TIME := 0.12      # keep accepting a jump briefly after walking off
const JUMP_BUFFER := 0.15      # and remember a jump pressed slightly too early
const DASH_SPEED := 17.0
const DASH_TIME := 0.22
const DASH_COOLDOWN := 0.7
const TURN_SPEED := 12.0

var character: Dictionary = Cast.BOUNCY_BLUE

var _visual: Node3D
var _model: Node3D
var _shape: CollisionShape3D

var _cast_index := 0
var _air_jumps_left := 0
var _coyote := 0.0
var _buffer := 0.0
var _dash_left := 0.0
var _dash_cd := 0.0
var _hop_phase := 0.0
var _was_on_floor := true

# Squash/stretch spring. `_squash` is a signed deviation: positive = stretched
# tall and thin, negative = squashed flat and wide. It always springs back to 0.
var _squash := 0.0
var _squash_vel := 0.0

## Set by Game.gd each frame so movement is relative to where the camera looks.
var camera_yaw := 0.0


func _ready() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	_shape = CollisionShape3D.new()
	_shape.name = "Shape"
	add_child(_shape)

	# Also collide with layer 2, which the Haunted House's walls, floors and
	# staircase live on. That layer is solid to the player but skipped by
	# FollowCamera's obstruction ray - see the note there. Without this the
	# player would walk straight through the whole building.
	collision_mask |= FollowCamera.SEE_OVER_LAYER_BIT

	_apply_character(Cast.ALL[_cast_index])


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if Input.is_action_just_pressed("swap"):
		swap_character()

	var wish := _wish_direction()
	_move(delta, wish)
	_jump(delta)
	_dash(wish)

	move_and_slide()
	_detect_landing()
	_animate(delta, wish)


# -- input ---------------------------------------------------------------

## Left stick / WASD, rotated into world space by the camera's yaw so "up on
## the stick" always means "away from the camera".
func _wish_direction() -> Vector3:
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if raw.length_squared() < 0.0001:
		return Vector3.ZERO
	var dir := Vector3(raw.x, 0.0, raw.y).rotated(Vector3.UP, camera_yaw)
	# Preserve analog magnitude for fine control, but never exceed 1.
	return dir.limit_length(1.0)


func _tick_timers(delta: float) -> void:
	_coyote = COYOTE_TIME if is_on_floor() else maxf(_coyote - delta, 0.0)
	_buffer = JUMP_BUFFER if Input.is_action_just_pressed("jump") \
		else maxf(_buffer - delta, 0.0)
	_dash_left = maxf(_dash_left - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)


# -- movement ------------------------------------------------------------

func _move(delta: float, wish: Vector3) -> void:
	if not is_on_floor():
		var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 22.0)
		velocity.y -= g * float(character["gravity_scale"]) * delta

	if _dash_left > 0.0:
		return   # a dash owns horizontal velocity until it expires

	var speed := float(character["speed"])
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if wish != Vector3.ZERO:
		var target := wish * speed
		flat = flat.move_toward(target, float(character["accel"]) * delta)
		_face(wish, delta)
	else:
		flat = flat.move_toward(Vector3.ZERO, float(character["friction"]) * delta)

	velocity.x = flat.x
	velocity.z = flat.z


## Turn so the node's -Z (Godot's forward) points along `dir`. Models.MODEL_YAW
## then swings the model's own +Z face round to match, and `_dash` can keep
## using -basis.z as "the way we are looking".
func _face(dir: Vector3, delta: float) -> void:
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, minf(TURN_SPEED * delta, 1.0))


func _jump(_delta: float) -> void:
	if _buffer <= 0.0:
		return

	if _coyote > 0.0:
		_launch(float(character["jump"]))
	elif _air_jumps_left > 0:
		_air_jumps_left -= 1
		# The second hop is deliberately softer, and cancels any fall speed
		# first so it always feels like a clean lift rather than a nudge.
		velocity.y = 0.0
		_launch(float(character["jump"]) * 0.88)
	else:
		return

	_buffer = 0.0
	_coyote = 0.0


func _launch(force: float) -> void:
	velocity.y = force
	_squash = 0.45          # stretch tall on the way up
	_squash_vel = 0.0


func _dash(wish: Vector3) -> void:
	if not bool(character["can_dash"]):
		return
	if not Input.is_action_just_pressed("dash") or _dash_cd > 0.0:
		return

	var dir := wish if wish != Vector3.ZERO else -global_transform.basis.z
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return

	dir = dir.normalized()
	velocity.x = dir.x * DASH_SPEED
	velocity.z = dir.z * DASH_SPEED
	_dash_left = DASH_TIME
	_dash_cd = DASH_COOLDOWN
	_squash = -0.30         # flatten into the lunge


func _detect_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		# Scale the squash by how hard we hit, so a small step reads different
		# from a fall off the castle wall.
		var impact: float = clampf(absf(velocity.y) / 14.0, 0.15, 1.0)
		_squash = -0.30 - 0.35 * impact
		_squash_vel = 0.0
		_air_jumps_left = int(character["air_jumps"])
		landed.emit(impact)
	_was_on_floor = on_floor


# -- procedural animation ------------------------------------------------

func _animate(delta: float, wish: Vector3) -> void:
	# Critically-ish damped spring back to neutral.
	var stiffness := 170.0
	var damping := 15.0
	_squash_vel += (-stiffness * _squash - damping * _squash_vel) * delta
	_squash += _squash_vel * delta
	_squash = clampf(_squash, -0.7, 0.7)

	var flat_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var gait: float = clampf(flat_speed / maxf(float(character["speed"]), 0.001), 0.0, 1.4)

	# Hop bob: only while actually running along the ground.
	var bob := 0.0
	if is_on_floor() and gait > 0.05:
		_hop_phase += delta * TAU * float(character["hop_hz"]) * gait
		bob = absf(sin(_hop_phase)) * float(character["hop_height"]) * gait
	else:
		_hop_phase = 0.0

	# A running bounce should also squash at the bottom of each step.
	var step_squash := 0.0
	if bob > 0.0:
		step_squash = -0.10 * gait * (1.0 - absf(sin(_hop_phase)))

	var s := _squash + step_squash
	# Volume-preserving: tall means thin, flat means wide.
	_visual.scale = Vector3(1.0 - s * 0.5, 1.0 + s, 1.0 - s * 0.5)
	_visual.position.y = bob

	# Lean into travel, and bank slightly when turning.
	var lean: float = clampf(flat_speed / 12.0, 0.0, 1.0) * 0.22
	var target_tilt := Vector3(lean, 0.0, 0.0)
	if wish == Vector3.ZERO:
		target_tilt = Vector3.ZERO
	_visual.rotation.x = lerp(_visual.rotation.x, target_tilt.x, minf(8.0 * delta, 1.0))


# -- character swapping --------------------------------------------------

func swap_character() -> void:
	_cast_index = (_cast_index + 1) % Cast.ALL.size()
	_apply_character(Cast.ALL[_cast_index])
	# A swap should feel like a pop, not a cut.
	_squash = -0.5
	_squash_vel = 0.0


func _apply_character(def: Dictionary) -> void:
	character = def

	if _model != null:
		_model.queue_free()
	_model = Models.spawn(String(def["model"]), float(def["height"]))

	# Cast carried a "tint" on every character from the start but nothing ever
	# read it. It is wired up here because Little Boo REUSES the Haunted House's
	# happy ghost, and an untinted copy would be pixel-identical to the answer
	# to one of that island's five rounds.
	#
	# White is an explicit no-op rather than a multiply by one: tint_albedo also
	# forces roughness to 1.0, and Bouncy Blue and Spotty Doggy ship at the
	# exporter's 0.85. Skipping them entirely keeps the two characters that
	# already existed looking exactly as they did.
	var tint: Color = def.get("tint", Color.WHITE)
	if tint != Color.WHITE:
		Models.tint_albedo(_model, tint)

	_visual.add_child(_model)

	# Capsule sized from the character's own height, feet on the origin.
	var height := float(def["height"])
	var radius: float = minf(0.32, height * 0.42)
	var capsule := CapsuleShape3D.new()
	capsule.height = maxf(height, radius * 2.0 + 0.01)
	capsule.radius = radius
	_shape.shape = capsule
	_shape.position.y = capsule.height * 0.5

	_air_jumps_left = int(def["air_jumps"])
	swapped.emit(def)


## Used by bounce pads so they can override vertical velocity outright.
func bounce(force: float) -> void:
	velocity.y = force
	_air_jumps_left = int(character["air_jumps"])
	_squash = 0.55
	_squash_vel = 0.0
