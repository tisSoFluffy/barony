class_name Bunny
extends CharacterBody3D

## Ms. Bumbleflower, a bunny who hops around the meadow on her own.
##
## She is not a collectible and not an obstacle - she is company. A small
## wander brain picks somewhere to go, she hops there in real ballistic arcs
## (gravity does the curve, not a tween), pauses to look around, and picks
## again. Get too close and she spooks and bounds away, which is what makes
## her fun to chase.
##
## Like every other character here she is unrigged, so all the life is
## procedural: a squash/stretch spring driven by takeoff and landing, plus a
## nose-down lean through the arc. See `_animate()`.

const HEIGHT := 1.05
const ALBEDO_TINT := Color(0.72, 0.74, 0.78)   # see Models.tint_albedo

# Hop shape. A hop is one launch: vertical impulse plus a horizontal shove,
# then gravity owns the arc until she lands.
const HOP_UP := 6.2
const HOP_SPEED := 4.2
const FLEE_UP := 7.0
const FLEE_SPEED := 7.2
const GRAVITY_SCALE := 0.85

# Pauses between hops. She chains a few quick hops, then rests a beat, so the
# rhythm reads as an animal rather than a metronome.
const REST_MIN := 0.22
const REST_MAX := 0.85
const LONG_REST_CHANCE := 0.22
const LONG_REST := 1.7

const TURN_SPEED := 7.0
const ARRIVE_DIST := 1.6

# Where she is allowed to roam: a disc around the meadow centre, kept inside
# the treeline and off the castle gate.
const ROAM_CENTRE := Vector3(0, 0, -1)
const ROAM_RADIUS := 12.0

const FLEE_RADIUS := 3.2          # player this close and she bolts
const FLEE_COOLDOWN := 0.45

var player: Node3D                ## set by Game.gd so she can be spooked

var _visual: Node3D
var _target := Vector3.ZERO
var _rest := 0.6
var _flee_cd := 0.0
var _was_on_floor := true
var _fall_speed := 0.0            # velocity.y from before move_and_slide ate it

# Signed squash: positive = stretched tall and thin, negative = squashed flat
# and wide. Springs back to 0. Same trick as Player.gd.
var _squash := 0.0
var _squash_vel := 0.0


func _ready() -> void:
	_visual = Models.spawn("res://assets/models/bunny.glb", HEIGHT)
	# Pale grey fur and mint cloth, otherwise blown to flat white by the sun.
	Models.tint_albedo(_visual, ALBEDO_TINT)
	add_child(_visual)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = maxf(HEIGHT, 0.62)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)

	_target = _wander_target()
	_rest = randf_range(REST_MIN, REST_MAX)


func _physics_process(delta: float) -> void:
	_flee_cd = maxf(_flee_cd - delta, 0.0)

	if not is_on_floor():
		var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 22.0)
		velocity.y -= g * GRAVITY_SCALE * delta
	else:
		# On the ground she stops dead rather than sliding - a hop should land
		# and stick, so each arc reads as one deliberate push.
		velocity.x = 0.0
		velocity.z = 0.0
		_rest -= delta
		if _spooked() and _flee_cd <= 0.0:
			_flee()
		elif _rest <= 0.0:
			_hop()

	# move_and_slide zeroes vertical speed on contact, so remember how hard she
	# was falling first - that is what scales the landing squash.
	_fall_speed = velocity.y
	move_and_slide()
	_detect_landing()
	_face_travel(delta)
	_animate(delta)


# -- brain ---------------------------------------------------------------

func _spooked() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) < FLEE_RADIUS


## A random spot inside the roam disc, biased to actually be somewhere else -
## re-rolling until it is a decent walk away stops her dithering on the spot.
func _wander_target() -> Vector3:
	for _i in 8:
		var a := randf() * TAU
		var r: float = sqrt(randf()) * ROAM_RADIUS
		var p := ROAM_CENTRE + Vector3(cos(a) * r, 0.0, sin(a) * r)
		if p.distance_to(global_position) > 4.0:
			return p
	return ROAM_CENTRE


func _hop() -> void:
	var flat := _target - global_position
	flat.y = 0.0
	if flat.length() < ARRIVE_DIST:
		_target = _wander_target()
		flat = _target - global_position
		flat.y = 0.0

	var dir := flat.normalized() if flat.length_squared() > 0.001 else Vector3.FORWARD
	# Vary each hop a little so a run of them is not a straight dotted line.
	dir = dir.rotated(Vector3.UP, randf_range(-0.25, 0.25))
	_launch(dir, HOP_UP * randf_range(0.9, 1.1), HOP_SPEED * randf_range(0.85, 1.15))
	_rest = LONG_REST if randf() < LONG_REST_CHANCE else randf_range(REST_MIN, REST_MAX)


## Spooked: one big bound directly away from the player, and a new destination
## on the far side so she keeps going rather than hopping straight back.
func _flee() -> void:
	var away := global_position - player.global_position
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = Vector3.FORWARD
	away = away.normalized()

	_launch(away, FLEE_UP, FLEE_SPEED)
	_target = _clamp_to_roam(global_position + away * 7.0)
	_rest = REST_MIN
	_flee_cd = FLEE_COOLDOWN


func _launch(dir: Vector3, up: float, speed: float) -> void:
	velocity.y = up
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_squash = 0.42                # stretch tall off the ground
	_squash_vel = 0.0


func _clamp_to_roam(p: Vector3) -> Vector3:
	var off := p - ROAM_CENTRE
	off.y = 0.0
	if off.length() > ROAM_RADIUS:
		off = off.normalized() * ROAM_RADIUS
	return ROAM_CENTRE + off


# -- procedural animation ------------------------------------------------

func _detect_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var impact: float = clampf(absf(_fall_speed) / 10.0, 0.2, 1.0)
		_squash = -0.34 - 0.30 * impact
		_squash_vel = 0.0
	_was_on_floor = on_floor


## Point her along the way she is travelling. Models face +Z and Models.spawn
## turns them to the node's -Z, so -basis.z is "the way she is looking".
func _face_travel(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() < 0.04:
		return
	var want := atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, want, minf(TURN_SPEED * delta, 1.0))


func _animate(delta: float) -> void:
	# Critically-ish damped spring back to neutral.
	_squash_vel += (-165.0 * _squash - 14.5 * _squash_vel) * delta
	_squash += _squash_vel * delta
	_squash = clampf(_squash, -0.6, 0.6)

	# Volume-preserving, so tall means thin and flat means wide - what sells a
	# rigid shell as something soft.
	_visual.scale = Vector3(1.0 - _squash * 0.5, 1.0 + _squash, 1.0 - _squash * 0.5)

	# Tip nose-down as she rises and level out as she falls, so the arc has a
	# direction instead of staying stiffly upright.
	var lean := 0.0
	if not is_on_floor():
		lean = clampf(velocity.y / 8.0, -0.5, 1.0) * 0.30
	_visual.rotation.x = lerp(_visual.rotation.x, lean, minf(9.0 * delta, 1.0))
