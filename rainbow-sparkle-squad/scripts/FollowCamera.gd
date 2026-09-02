class_name FollowCamera
extends Camera3D

## Third-person orbit camera driven by the right stick.
##
## Follows a target with a soft spring, and pulls in when scenery gets between
## the camera and the character so the castle walls never eat the view.

const STICK_SPEED := 2.8          # radians/sec at full deflection
const PITCH_MIN := -0.30
const PITCH_MAX := 1.15
const DISTANCE := 4.6
const HEIGHT := 1.6
const FOLLOW_LAG := 9.0

## Far clip. Every island fits comfortably inside this, and holding it well
## under the gap between islands is what stops a child on the savanna seeing a
## volcano and a pastel meadow parked on the horizon.
const FAR := 300.0

## Physics layer 2 is "solid to the player, invisible to this camera".
##
## It exists for the Haunted House, which is a real two-floor building you walk
## around inside. Obstruction pull-in is right outdoors - it stops the castle
## wall eating the view - but indoors it is fatal: the ray runs from the
## player's chest to a camera spot beyond the wall, so every wall in the room
## registers as an obstruction and the camera slams to its 1.2 m floor. The
## first build of that house was unplayable for exactly this reason, a corridor
## filling the screen with plaster.
##
## Putting the house's walls and floors on their own layer and skipping them
## here is what makes an open-topped dollhouse work: the camera rides ABOVE the
## wall tops and looks down into whichever room the player is in, instead of
## being shoved into their back. Player.gd masks layer 2 in so the player still
## collides with all of it.
const SEE_OVER_LAYER_BIT := 2
const OBSTRUCTION_MASK := 0xFFFFFFFF & ~SEE_OVER_LAYER_BIT

var target: Node3D
var yaw := 0.0
var pitch := 0.45

var _look_at := Vector3.ZERO
var _ready_done := false


func _ready() -> void:
	fov = 62.0
	far = FAR
	current = true


## Drop the follow lag for one frame. After a teleport the focus point would
## otherwise sail across the world from the old position, dragging the view
## through everything in between.
func snap_to_target() -> void:
	_ready_done = false


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	yaw -= stick.x * STICK_SPEED * delta
	pitch = clampf(pitch + stick.y * STICK_SPEED * delta, PITCH_MIN, PITCH_MAX)

	# Aim a little above the feet, and let the focus point lag the character so
	# small hops do not jitter the whole frame.
	var focus: Vector3 = target.global_position + Vector3.UP * 0.75
	if not _ready_done:
		_look_at = focus
		_ready_done = true
	else:
		_look_at = _look_at.lerp(focus, minf(FOLLOW_LAG * delta, 1.0))

	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)
	) * DISTANCE
	offset.y += HEIGHT * 0.25

	var want := _look_at + offset
	global_position = _unobstructed(_look_at, want)
	look_at(_look_at, Vector3.UP)


## Cast from the focus point out to the desired camera spot; if something solid
## is in the way, sit just in front of it instead.
func _unobstructed(from: Vector3, to: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collision_mask = OBSTRUCTION_MASK
	if target is CollisionObject3D:
		query.exclude = [target.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return to
	return from + (to - from).normalized() * maxf(from.distance_to(hit["position"]) - 0.35, 1.2)
