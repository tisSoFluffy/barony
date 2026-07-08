extends Camera3D

## Fixed isometric-style camera for HD 2D.
## Sits at a locked diagonal angle and follows a target smoothly.
## Angle: ~30° pitch down, 45° yaw — matches Octopath Traveler's diorama feel.

const PITCH_DEG := -28.0
const YAW_DEG   := 45.0
const HEIGHT    := 12.0
const DISTANCE  := 14.0
const FOLLOW_SPEED  := 6.0
const TRAUMA_DECAY  := 2.4   # units per second
const SHAKE_MAX_XZ  := 0.30  # world units of max shake offset

var _offset:  Vector3
var _trauma:  float = 0.0
var target:   Node3D = null

func _ready() -> void:
	_offset = Vector3(
		sin(deg_to_rad(YAW_DEG)) * DISTANCE,
		HEIGHT,
		cos(deg_to_rad(YAW_DEG)) * DISTANCE
	)
	rotation_degrees = Vector3(PITCH_DEG, YAW_DEG, 0.0)
	fov = 40.0
	SignalBus.screen_shake.connect(_on_screen_shake)


func _process(delta: float) -> void:
	if target == null:
		return
	var desired := target.global_position + _offset

	# Trauma-based shake (squared for fast-then-slow feel)
	if _trauma > 0.0:
		var s := _trauma * _trauma * SHAKE_MAX_XZ
		desired.x += randf_range(-s, s)
		desired.z += randf_range(-s, s)
		_trauma = maxf(0.0, _trauma - TRAUMA_DECAY * delta)

	global_position = global_position.lerp(desired, FOLLOW_SPEED * delta)


func set_target(node: Node3D) -> void:
	target = node
	if target:
		global_position = target.global_position + _offset


func _on_screen_shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)
