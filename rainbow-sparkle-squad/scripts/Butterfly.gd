class_name Butterfly
extends Node3D

## A butterfly that flutters around the meadow, visiting the flowers.
##
## She is the one rigged character in the project. Everything else is a single
## unrigged shell moved as a whole body, which is fine for a hop or a squash but
## cannot beat a wing: the two wings have to swing in opposite directions about
## the body. `tools/rig_butterfly.py` gives her a three-bone skeleton, and
## `_flap()` drives the two wing bones directly.
##
## Everything else is still procedural. She has no gravity and no collider - she
## drifts along a steered heading, sinks and rises on a slow bob, banks into her
## turns, and picks a new flower to visit whenever she reaches one.

const WING_HZ := 7.5              # beats per second at cruise
const WING_SWING := 0.85          # radians either side of flat
const SPEED := 2.3
const TURN_SPEED := 1.9
const BOB_HEIGHT := 0.35
const BOB_HZ := 0.55

const ARRIVE_DIST := 0.9
const LINGER_MIN := 1.2           # hover at a flower before moving on
const LINGER_MAX := 3.0

const CRUISE_HEIGHT := 1.7        # metres above whatever she is visiting
const HEIGHT_LERP := 1.6

## Her pastels come out of the generator with its lighting already baked in and
## wash out to near-white in the meadow. See Models.tint_albedo.
const ALBEDO_TINT := Color(0.78, 0.76, 0.80)

## Places worth visiting, handed over by Game.gd - the flowers and toadstools.
## Falls back to wandering the roam disc if the list is empty.
var perches: PackedVector3Array = PackedVector3Array()

const ROAM_CENTRE := Vector3(0, 0, -1)
const ROAM_RADIUS := 12.0

var _visual: Node3D
var _skel: Skeleton3D
var _wing_l := -1
var _wing_r := -1
var _rest_l := Transform3D.IDENTITY
var _rest_r := Transform3D.IDENTITY

var _target := Vector3.ZERO
var _heading := Vector3.FORWARD
var _linger := 0.0
var _phase := 0.0
var _flap_phase := 0.0
var _bank := 0.0


func _ready() -> void:
	_visual = Models.spawn("res://assets/models/butterfly.glb", 0.55)
	Models.tint_albedo(_visual, ALBEDO_TINT)
	add_child(_visual)
	_find_wings()

	_phase = randf() * TAU
	_heading = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	_target = _pick_perch()


## The rig is three bones: Body, Wing_L, Wing_R. Cache the two wing indices and
## their rest poses so `_flap` can swing from rest instead of accumulating.
func _find_wings() -> void:
	for node in _visual.find_children("*", "Skeleton3D", true, false):
		_skel = node as Skeleton3D
		break
	if _skel == null:
		push_warning("Butterfly: no Skeleton3D - wings will not beat")
		return

	_wing_l = _skel.find_bone("Wing_L")
	_wing_r = _skel.find_bone("Wing_R")
	if _wing_l < 0 or _wing_r < 0:
		push_warning("Butterfly: rig has no Wing_L/Wing_R bones")
		return
	_rest_l = _skel.get_bone_rest(_wing_l)
	_rest_r = _skel.get_bone_rest(_wing_r)


func _process(delta: float) -> void:
	_phase += delta
	_steer(delta)
	_move(delta)
	_flap(delta)


# -- flight --------------------------------------------------------------

func _steer(delta: float) -> void:
	var flat := _target - global_position
	flat.y = 0.0

	if flat.length() < ARRIVE_DIST:
		# Arrived: hover a moment, then choose somewhere new.
		_linger -= delta
		if _linger <= 0.0:
			_target = _pick_perch()
			_linger = randf_range(LINGER_MIN, LINGER_MAX)
		return

	var want := flat.normalized()
	var before := _heading
	_heading = _heading.slerp(want, minf(TURN_SPEED * delta, 1.0)).normalized()

	# Bank into the turn: the sign of the cross product tells which way she is
	# swinging, and how hard.
	var turn: float = before.cross(_heading).y
	_bank = lerp(_bank, clampf(turn * 26.0, -0.6, 0.6), minf(4.0 * delta, 1.0))


func _move(delta: float) -> void:
	# A butterfly does not fly straight - weave the heading a little.
	var weave := _heading.rotated(Vector3.UP, sin(_phase * 2.3) * 0.35)
	global_position += weave * SPEED * delta

	# Rise towards cruise height over the target, with a slow bob on top so she
	# never holds a dead-flat altitude.
	var want_y: float = _target.y + CRUISE_HEIGHT + sin(_phase * TAU * BOB_HZ) * BOB_HEIGHT
	global_position.y = lerp(global_position.y, want_y, minf(HEIGHT_LERP * delta, 1.0))

	# Face along travel, then roll into the bank.
	var yaw := atan2(-weave.x, -weave.z)
	rotation.y = lerp_angle(rotation.y, yaw, minf(6.0 * delta, 1.0))
	rotation.z = lerp(rotation.z, _bank, minf(5.0 * delta, 1.0))


func _pick_perch() -> Vector3:
	if perches.is_empty():
		var a := randf() * TAU
		var r: float = sqrt(randf()) * ROAM_RADIUS
		return ROAM_CENTRE + Vector3(cos(a) * r, 0.0, sin(a) * r)

	# Re-roll a couple of times so she does not pick the flower she is already
	# sitting on.
	var best: Vector3 = perches[randi() % perches.size()]
	for _i in 4:
		if best.distance_to(global_position) > 3.0:
			break
		best = perches[randi() % perches.size()]
	return best


# -- wing beat -----------------------------------------------------------

## Roll each wing about its own length, which tips the flat of the wing up and
## down - the beat. Blender builds bones with their local Y along the bone, and
## that survives the glTF round trip, so the axis here is Vector3.UP rather than
## the wing's world direction.
##
## Both wings take the SAME local sign. Their rest frames are mirrored (Wing_L's
## local Y points along world +X, Wing_R's along -X), so an identical local roll
## already comes out mirrored in world space, which is what symmetric flapping
## needs. Negating one would fold them the same way and look broken.
##
## The beat is not a plain sine: butterflies snap the downstroke and coast at
## the top, so the wave is skewed to linger near the peak.
func _flap(delta: float) -> void:
	if _skel == null or _wing_l < 0:
		return

	_flap_phase += delta * TAU * WING_HZ
	var s := sin(_flap_phase)
	var beat: float = signf(s) * pow(absf(s), 0.65)
	var swing := Quaternion(Vector3.UP, beat * WING_SWING)

	_skel.set_bone_pose_rotation(_wing_l, _rest_l.basis.get_rotation_quaternion() * swing)
	_skel.set_bone_pose_rotation(_wing_r, _rest_r.basis.get_rotation_quaternion() * swing)
