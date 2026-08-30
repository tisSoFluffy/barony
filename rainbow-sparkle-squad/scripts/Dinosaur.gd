class_name Dinosaur
extends CharacterBody3D

## A dinosaur that lives in the valley - either a land walker or the flyer.
##
## One script covers both because they share almost everything: the same
## generated-and-unrigged body, the same touch-to-hear-my-name, the same
## procedural life. Only the locomotion differs, and that is one branch rather
## than a second class.
##
## Land walkers plod between wander targets with a heavy two-beat gait: they
## rock side to side, dip on each footfall, and swing the whole body a little,
## because a heavy animal moves its mass and a light one does not. The flyer
## circles high overhead and every so often glides down to perch, sits a while,
## then climbs away again - which is also what makes it reachable at all. A
## pteranodon permanently at eight metres is scenery; one that comes down to
## visit is a character, and it rewards a child for watching and waiting.

signal touched(dino: Dinosaur)

enum Mode { WALKER, FLYER }

## Set before the node enters the tree.
var species := "trex"
var mode: Mode = Mode.WALKER
var height := 2.0

## Centre of this dinosaur's roaming area, in WORLD space.
##
## World rather than local specifically because everything else here steers with
## `global_position` and `move_and_slide`, which are world-space too. Handing
## this a local offset - as the valley's layout table naturally holds - sent
## every dinosaur navigating towards a point near the world origin, which is the
## meadow, two hundred metres away. DinoValley converts before setting it.
var home := Vector3.ZERO
var roam_radius := 10.0

# -- walking --------------------------------------------------------------
const WALK_SPEED := 1.5
const TURN_SPEED := 2.2
const ARRIVE := 1.8
const PAUSE_MIN := 1.2
const PAUSE_MAX := 3.5
const GRAVITY_SCALE := 1.0

# -- flying ---------------------------------------------------------------
const CRUISE_Y := 8.5
const FLY_SPEED := 3.4
const PERCH_Y := 0.0
const CIRCLE_TIME_MIN := 9.0
const CIRCLE_TIME_MAX := 16.0
const PERCH_TIME_MIN := 7.0
const PERCH_TIME_MAX := 12.0
const CLIMB_RATE := 2.2

# Wing rig, flyer only. Absent on the walkers, and absent is fine - the flap
# code no-ops rather than requiring every dinosaur to be skinned.
const WING_HZ := 1.5
const WING_SWING := 0.55
const GLIDE_HZ := 0.11             # how often it stops flapping and coasts

var _skel: Skeleton3D
var _wing_l := -1
var _wing_r := -1
var _rest_l := Transform3D.IDENTITY
var _rest_r := Transform3D.IDENTITY
var _flap_phase := 0.0

var _visual: Node3D
var _target := Vector3.ZERO
var _pause := 0.0
var _phase := 0.0
var _gait := 0.0                   # advances only while actually moving
var _squash := 0.0
var _squash_vel := 0.0

# Flyer state
var _angle := 0.0
var _state_timer := 0.0
var _perching := false
var _perch_spot := Vector3.ZERO


func _ready() -> void:
	_visual = Models.spawn("res://assets/models/%s.glb" % species, height)
	add_child(_visual)
	_find_wings()

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = maxf(height * 0.30, 0.4)
	capsule.height = maxf(height, capsule.radius * 2.0 + 0.01)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)

	# Touching is done with a separate, roomier Area3D rather than the body:
	# a three-year-old aims approximately, and bumping a dinosaur's shin should
	# count as meeting it.
	var area := Area3D.new()
	var acol := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(height * 1.5, maxf(height, 2.0), height * 1.5)
	acol.shape = abox
	acol.position.y = height * 0.5
	area.add_child(acol)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

	_phase = randf() * TAU
	_angle = randf() * TAU
	_pause = randf_range(PAUSE_MIN, PAUSE_MAX)
	_state_timer = randf_range(CIRCLE_TIME_MIN, CIRCLE_TIME_MAX)
	_target = _wander_target()
	if mode == Mode.FLYER:
		global_position = home + Vector3(cos(_angle), 0, sin(_angle)) * roam_radius
		global_position.y = CRUISE_Y


## Only the flyer is skinned - tools/rig_wings.py gives it the same three-bone
## rig as the butterfly. The walkers have no skeleton and this quietly does
## nothing for them, so `_flap` can be called unconditionally.
func _find_wings() -> void:
	for node in _visual.find_children("*", "Skeleton3D", true, false):
		_skel = node as Skeleton3D
		break
	if _skel == null:
		return
	_wing_l = _skel.find_bone("Wing_L")
	_wing_r = _skel.find_bone("Wing_R")
	if _wing_l < 0 or _wing_r < 0:
		_skel = null
		return
	_rest_l = _skel.get_bone_rest(_wing_l)
	_rest_r = _skel.get_bone_rest(_wing_r)


func _physics_process(delta: float) -> void:
	_phase += delta
	if mode == Mode.FLYER:
		_fly(delta)
	else:
		_walk(delta)
	_animate(delta)
	_flap(delta)


## Roll each wing about its own length. Blender puts a bone's local Y along the
## bone and that survives the glTF round trip, so the axis is Vector3.UP; both
## wings take the same local sign because their rest frames are already
## mirrored. Same reasoning as Butterfly._flap, which this is the slow cousin of.
##
## Unlike the butterfly, this one GLIDES: a slow envelope drops the beat to
## almost nothing every few seconds, which is what a big soaring reptile does
## and what keeps it from looking like a wind-up toy. It beats harder while
## climbing away from a perch, because that is when it would actually need to.
func _flap(delta: float) -> void:
	if _skel == null:
		return

	var climbing: bool = not _perching and global_position.y < CRUISE_Y - 1.0
	var glide: float = 0.5 + 0.5 * sin(_phase * TAU * GLIDE_HZ)
	var amount: float = 1.0 if climbing else lerpf(0.12, 1.0, glide)
	if _perching:
		amount = 0.06                # folded, just breathing

	_flap_phase += delta * TAU * WING_HZ * (1.6 if climbing else 1.0)
	var swing := Quaternion(Vector3.UP, sin(_flap_phase) * WING_SWING * amount)
	_skel.set_bone_pose_rotation(_wing_l, _rest_l.basis.get_rotation_quaternion() * swing)
	_skel.set_bone_pose_rotation(_wing_r, _rest_r.basis.get_rotation_quaternion() * swing)


# -- land -----------------------------------------------------------------

func _walk(delta: float) -> void:
	if not is_on_floor():
		var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 22.0)
		velocity.y -= g * GRAVITY_SCALE * delta

	var flat := _target - global_position
	flat.y = 0.0

	if _pause > 0.0 or flat.length() < ARRIVE:
		_pause -= delta
		if _pause <= 0.0:
			_target = _wander_target()
			_pause = randf_range(PAUSE_MIN, PAUSE_MAX)
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
	else:
		var dir := flat.normalized()
		velocity.x = dir.x * WALK_SPEED
		velocity.z = dir.z * WALK_SPEED
		_face(dir, delta)
		_gait += delta

	move_and_slide()


func _face(dir: Vector3, delta: float) -> void:
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, minf(TURN_SPEED * delta, 1.0))


func _wander_target() -> Vector3:
	for _i in 8:
		var a := randf() * TAU
		var r: float = sqrt(randf()) * roam_radius
		var p := home + Vector3(cos(a) * r, 0.0, sin(a) * r)
		if p.distance_to(global_position) > 4.0:
			return p
	return home


# -- air ------------------------------------------------------------------

## Circle high, then come down and sit for a while. The two states swap on a
## timer rather than on arrival, so the flyer is never predictable enough to
## get boring but always comes back down eventually.
func _fly(delta: float) -> void:
	_state_timer -= delta

	if _perching:
		global_position.y = move_toward(global_position.y, PERCH_Y, CLIMB_RATE * delta)
		var to_spot := _perch_spot - global_position
		to_spot.y = 0.0
		if to_spot.length() > 0.2:
			var step: float = minf(FLY_SPEED * 0.6 * delta, to_spot.length())
			global_position += to_spot.normalized() * step
			_face(to_spot.normalized(), delta)
		if _state_timer <= 0.0:
			_perching = false
			_state_timer = randf_range(CIRCLE_TIME_MIN, CIRCLE_TIME_MAX)
		return

	# Circling: sweep round the home point at cruise height.
	_angle += (FLY_SPEED / maxf(roam_radius, 1.0)) * delta
	var want := home + Vector3(cos(_angle), 0.0, sin(_angle)) * roam_radius
	want.y = CRUISE_Y + sin(_phase * 0.7) * 0.8
	var move := want - global_position
	global_position += move * minf(3.0 * delta, 1.0)

	# Face along the tangent of the circle, which is where it is actually going.
	var tangent := Vector3(-sin(_angle), 0.0, cos(_angle))
	_face(tangent, delta)

	if _state_timer <= 0.0:
		_perching = true
		_state_timer = randf_range(PERCH_TIME_MIN, PERCH_TIME_MAX)
		var a := randf() * TAU
		var r: float = sqrt(randf()) * roam_radius * 0.55
		_perch_spot = home + Vector3(cos(a) * r, 0.0, sin(a) * r)


func is_perching() -> bool:
	return mode == Mode.FLYER and _perching and absf(global_position.y - PERCH_Y) < 0.6


# -- procedural life ------------------------------------------------------

func _animate(delta: float) -> void:
	_squash_vel += (-150.0 * _squash - 13.0 * _squash_vel) * delta
	_squash += _squash_vel * delta
	_squash = clampf(_squash, -0.5, 0.5)

	var moving := Vector3(velocity.x, 0.0, velocity.z).length() > 0.2
	var s := _squash

	if mode == Mode.FLYER:
		# A slow wingbeat read as a whole-body rise and fall, plus a bank into
		# the turn. The model is one shell, so this is the only honest way to
		# suggest wings without a rig.
		var beat: float = sin(_phase * TAU * 0.9)
		_visual.position.y = beat * (0.10 if _perching else 0.22)
		_visual.rotation.z = 0.0 if _perching else -0.28
		_visual.rotation.x = beat * 0.06
	else:
		# Heavy two-beat plod. The dip and the roll share a phase so the body
		# drops onto the foot it is rolling towards, which is what makes it read
		# as weight rather than as a wobble.
		if moving:
			var step: float = _gait * TAU * 1.25
			_visual.position.y = -absf(sin(step)) * height * 0.035
			_visual.rotation.z = sin(step) * 0.06
			_visual.rotation.x = sin(step * 2.0) * 0.025
		else:
			# Idle: just breathing.
			_visual.position.y = sin(_phase * TAU * 0.35) * height * 0.012
			_visual.rotation.z = lerp(_visual.rotation.z, 0.0, minf(4.0 * delta, 1.0))
			_visual.rotation.x = lerp(_visual.rotation.x, 0.0, minf(4.0 * delta, 1.0))

	_visual.scale = Vector3(1.0 - s * 0.45, 1.0 + s, 1.0 - s * 0.45)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		touched.emit(self)


## Rear up and bellow - the reaction to being met.
func cheer() -> void:
	_squash = 0.34
	_squash_vel = 0.0


func stomp() -> void:
	_squash = -0.30
	_squash_vel = 0.0
