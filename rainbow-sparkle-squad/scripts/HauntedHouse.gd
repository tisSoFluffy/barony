class_name HauntedHouse
extends Node3D

## The Haunted House: a two-floor house you go inside, with five ghosts hiding
## in its rooms.
##
## The game is EMOTIONS - who looks happy, sad, angry, scared, sleepy - but it
## is played by SEARCHING. A round names a feeling and the ghost wearing it is
## somewhere in the house, which means walking room to room and up the stairs
## to find it. Every other island stands its subject in a ring and waits; this
## one hides them, and the name lands because a child had to go and look.
##
## Built as an OPEN-TOPPED dollhouse: real walls, real rooms, two real floors,
## and no ceilings at all. That is not a shortcut, it is the only shape that
## works here. FollowCamera orbits 4.6 m out and pulls in to a floor of 1.2 m
## on any obstruction, so inside a roofed room it would sit on the player's
## back and jitter every time a wall swung past; and there is ONE sun in this
## whole game, so a roofed interior would also be a black box. With the tops
## open the camera rides above the walls and looks down into whichever room the
## player is in, and the meadow sun lights every room for free.
##
## The five ghosts share one body and differ only in expression - see
## GhostFigure - so the face is the only thing that can answer the question.

signal round_started(question: String)
signal answered(correct: bool, emotion: String)
signal completed

const EMOTIONS: Array[String] = ["happy", "sad", "angry", "scared", "sleepy"]

## Pale washes multiplied into each near-white ghost so it does not render as a
## featureless blob (trap 4). Deliberately DECORRELATED from the feelings - sad
## is not the blue one, angry is not the red one - because a child who can sort
## these by colour has stopped looking at the faces. hauntedhousetest asserts
## they stay both distinct and too close together to rank by.
const TINTS := {
	"happy": Color("#a1a6ae"),
	"sad": Color("#aba89e"),
	"angry": Color("#a4aba6"),
	"scared": Color("#a8a3ae"),
	"sleepy": Color("#aea3a6"),
}

## Typed, because `restart` shuffles a duplicate of this into a typed _queue -
## and duplicating an UNtyped const array into a typed variable is a runtime
## type error, not a parse one.
const ROUNDS: Array[Dictionary] = [
	{"clip": "feel_happy", "answer": "happy", "text": "Who looks HAPPY?"},
	{"clip": "feel_sad", "answer": "sad", "text": "Who looks SAD?"},
	{"clip": "feel_angry", "answer": "angry", "text": "Who looks ANGRY?"},
	{"clip": "feel_scared", "answer": "scared", "text": "Who looks SCARED?"},
	{"clip": "feel_sleepy", "answer": "sleepy", "text": "Who looks SLEEPY?"},
]

const GROUND_R := 26.0
const GHOST_H := 1.6
const HINT_AFTER := 2

# -- the house -----------------------------------------------------------
# Footprint x [-8, 8], z [-7, 5]. A corridor runs front to back at |x| < 1.5
# and a cross corridor left to right at |z| < 1.5, which leaves four corner
# rooms per floor, each reached through one doorway.

const HOUSE_MIN := Vector2(-10.5, -11.5)
const HOUSE_MAX := Vector2(10.5, 8.0)

## Wall height and corridor width are both set by the CAMERA, not by taste.
##
## FollowCamera sits DISTANCE * cos(pitch) = 4.14 m behind the player and
## 2.40 m above the focus point at its default pitch, so its sight line climbs
## at about 0.58 for every metre back. A wall `d` metres away therefore blocks
## the view of the player whenever it is taller than 0.75 + 0.58 * d above the
## floor. At the half-width of a 4 m corridor that ceiling is 1.91 m, which is
## why the walls are 1.72 and the corridor is 4 m and not 3.
##
## Layer 2 stops the camera being SHOVED INTO the player's back by these walls;
## this is what stops them standing in front of the player instead. Both are
## needed, and the first build of this house had neither.
##
## 1.72 m is not a low wall here. The cast are 0.80-0.90 m tall, so it is twice
## the height of the character walking past it - the same as a 3.5 m wall to an
## adult. The earlier 2.6 m walls were three times player height, which is why
## the house read as a canyon.
## Ceiling height is set by the GHOSTS, and corridor width is then set by the
## ceiling. Both are arithmetic; neither is taste.
##
## A ghost stands 2.13 m tall at rest - 0.4 m of hover, a 1.6 m body, and 0.13 m
## of bob - and reaches 2.80 m for a moment mid-cheer, because the squash spring
## stretches it to 1.42x. The house was first built with a 1.60 m ceiling, so
## every ghost on the ground floor had its head through the floor above.
##
## The fix is a taller house rather than smaller ghosts, and taller walls fight
## the camera: a wall `d` metres away hides the player once it is taller than
## 0.75 + 0.58 * d above the floor, where 0.58 is FollowCamera's sight line at
## its default pitch. A 2.75 m ceiling therefore needs the player to be able to
## keep 3.45 m from a wall, so the corridors are 8 m across and the whole house
## grew to suit. That buys 0.62 m of clearance over a resting ghost and leaves
## a cheer overshooting by 5 cm for about a third of a second, which is nothing.
const UPPER_Y := 3.00               # the upper floor's walking surface
const WALL_H := 2.75                # ground floor walls, up to the slab
## The upper walls are deliberately SHORTER than the ground floor's. Nothing
## upstairs has a ceiling to clear, so the only thing setting this is the
## camera - and at 2.5 m the front wall filled two thirds of the screen the
## moment you walked towards it. At 1.9 m it clears from two metres out.
##
## It buys something as well as costing nothing: an upstairs ghost stands 5.13 m
## and the walls top out at 4.9 m, so their heads show over the tops. On a floor
## whose whole point is hunting for them, being able to see where they are from
## the landing is the difference between searching and wandering.
const UPPER_WALL_H := 1.90          # upper floor walls, open above
const SLAB_T := 0.25
const WALL_T := 0.40
const CORRIDOR := 4.0               # half-width of the corridors
## The front doorway is NOT the corridor's width. An 8 m opening is a hole in
## the facade, not a door; this is a door that opens into a big hall.
const DOOR_W := 1.6                 # half-width of the front doorway

## Stairs. A RAMP, not steps: CharacterBody3D has no step-up, so a staircase
## built from boxes is a row of walls a three-year-old would have to jump. The
## visible steps are dressing sitting on the ramp with no collider of their own.
## The staircase is a SWITCHBACK, and it has to be.
##
## It first ran the full 3 m width of a 4 m corridor from the back wall up to
## the cross corridor - which meant the only end you could reach was the TOP,
## presenting a 1.78 m face, with its foot walled in behind it. The upper floor
## was unreachable in play. (The test did not catch it because it teleported
## the player onto the foot, proving the ramp was climbable while never proving
## it could be got to. See hauntedhousetest.)
##
## So: the flight is narrow and pushed to the right, leaving a clear walkway
## down the left of the corridor, and its foot stops short of the back wall to
## leave a bay to turn round in. Walk down the left, turn round in the bay, walk
## back up the right. There is no sideways step onto a raised surface anywhere
## in that route - CharacterBody3D has no step-up, so meeting the flight side-on
## even 18 cm up the slope would simply stop the player dead.
const STAIR_Z0 := -9.5              # foot, with a turning bay behind it
const STAIR_Z1 := -4.0              # top, where it meets the upper corridor
const STAIR_W := 3.2
const STAIR_X := 2.3                # pushed right; the walkway is left of it
const STAIR_EDGE := STAIR_X - STAIR_W * 0.5   # left edge of the flight

## Walls shared by both floors, as [x1, z1, x2, z2] segments. Gaps between
## segments ARE the doorways - laying them out as explicit spans rather than
## computing holes is what makes the plan readable as data.
const WALLS: Array[Array] = [
	# outer shell, minus the front wall (which differs per floor)
	[-10.5, -11.5, 10.5, -11.5],    # back
	[-10.5, -11.5, -10.5, 8.0],     # left
	[10.5, -11.5, 10.5, 8.0],       # right
	# front-left room: doorway onto the corridor at z 5.0 -> 6.8
	[-4.0, 4.0, -4.0, 5.0],
	[-4.0, 6.8, -4.0, 8.0],
	[-10.5, 4.0, -4.0, 4.0],
	# front-right room: doorway at z 5.0 -> 6.8
	[4.0, 4.0, 4.0, 5.0],
	[4.0, 6.8, 4.0, 8.0],
	[4.0, 4.0, 10.5, 4.0],
	# back-left room: doorway onto the cross corridor at x -8.2 -> -6.4
	[-4.0, -11.5, -4.0, -4.0],
	[-10.5, -4.0, -8.2, -4.0],
	[-6.4, -4.0, -4.0, -4.0],
	# back-right room: doorway at x 6.4 -> 8.2
	[4.0, -11.5, 4.0, -4.0],
	[4.0, -4.0, 6.4, -4.0],
	[8.2, -4.0, 10.5, -4.0],
]

## Where each ghost hides: room centre, and which floor. Three downstairs and
## two up, so the first rounds can be found without the stairs and the later
## ones cannot.
const HIDING := {
	"happy": {"pos": Vector2(-7.25, 6.0), "upper": false, "room": "the parlour"},
	"sleepy": {"pos": Vector2(-7.25, -7.75), "upper": false, "room": "the pantry"},
	"sad": {"pos": Vector2(7.25, -7.75), "upper": false, "room": "the kitchen"},
	"angry": {"pos": Vector2(7.25, 6.0), "upper": true, "room": "the nursery"},
	"scared": {"pos": Vector2(-7.25, -7.75), "upper": true, "room": "the attic"},
}

## Set by Game.gd before this enters the tree, and handed to every ghost so
## they can turn to watch - see GhostFigure.player.
var player: Node3D

## Everything belonging to the upper storey: the slab, its walls, its lanterns
## and the two ghosts hiding up there. Hidden while the player is underneath it
## - see _update_storey.
var _upper_parts: Array[Node3D] = []
var _upper_shown := true

var _ghosts: Array[GhostFigure] = []
var _queue: Array[Dictionary] = []
var _current := {}
var _round := 0
var _wrong := 0
var _done := false
var _busy := false
var _voice: AudioStreamPlayer

var _asks := {}
var _names := {}
var _praise: AudioStream
var _retry: AudioStream


func _ready() -> void:
	_load_clips()
	_build_ground()
	_build_floors()
	_build_walls()
	_build_stairs()
	_build_exterior_detail()
	_build_yard()
	_build_interior_dressing()
	_build_ghosts()

	_voice = AudioStreamPlayer.new()
	_voice.name = "HauntedVoice"
	_voice.volume_db = 2.0
	add_child(_voice)


## Take the top floor off while the player is under it, and put it back when
## they climb the stairs or step outside.
##
## This is the thing that makes a two-storey interior work at all. Skipping the
## walls in FollowCamera's obstruction ray stops the camera being shoved into
## the player's back, but it cannot help with the FLOOR: an orbit camera sitting
## 4 m behind a player who is stood in a ground-floor room is underneath the
## slab, and the slab is between it and them. No wall height and no camera pitch
## fixes that - the sight line leaves the room through the ceiling barely half a
## metre from the player.
##
## So the upper storey lifts off, exactly the way it does on a real dollhouse.
## Approaching from the yard the house is two storeys; step through the front
## door and the lid comes away; climb the stairs and it is back, with the ground
## floor open below. It is only hidden when the player is BOTH inside the
## footprint AND downstairs, so the house never looks single-storey from outside.
func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var local: Vector3 = player.global_position - global_position
	var inside: bool = local.x > HOUSE_MIN.x and local.x < HOUSE_MAX.x \
		and local.z > HOUSE_MIN.y and local.z < HOUSE_MAX.y
	var upstairs: bool = local.y > UPPER_Y * 0.5
	var show: bool = upstairs or not inside
	if show == _upper_shown:
		return
	_upper_shown = show
	for n in _upper_parts:
		if is_instance_valid(n):
			n.visible = show


func _load_clips() -> void:
	for e in EMOTIONS:
		_names[e] = load("res://assets/audio/emotion_%s.wav" % e)
	for r in ROUNDS:
		_asks[r["clip"]] = load("res://assets/audio/%s.wav" % r["clip"])
	_praise = load("res://assets/audio/say_wellDone.wav")
	_retry = load("res://assets/audio/say_tryAgain.wav")


# -- construction helpers ------------------------------------------------

func _box(size: Vector3, at: Vector3, colour: Color, solid: bool,
		node_name: String) -> Node3D:
	"""A painted box, optionally with a collider that matches it."""
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = at

	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 1.0
	cube.material = mat
	mesh.mesh = cube
	holder.add_child(mesh)

	if solid:
		var body := StaticBody3D.new()
		# Layer 2 only: solid to the player, invisible to FollowCamera's
		# obstruction ray. This is the whole trick that lets an indoor space
		# work with an orbit camera - see the note in FollowCamera.
		body.collision_layer = FollowCamera.SEE_OVER_LAYER_BIT
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		holder.add_child(body)

	add_child(holder)
	return holder


## The island the house stands on. Every colour here is far darker than its
## swatch looks, because the meadow sun and the filmic tonemap lift everything
## (trap 4) - the first version of this ground was #332b40 and read as pale
## lavender.
func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "HauntedGround"

	var mesh := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = GROUND_R
	drum.bottom_radius = GROUND_R * 0.96
	drum.height = 1.2
	drum.radial_segments = 56
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#1b1626")
	mat.roughness = 1.0
	drum.material = mat
	mesh.mesh = drum
	mesh.position.y = -0.6
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = GROUND_R
	shape.height = 1.2
	col.shape = shape
	col.position.y = -0.6
	body.add_child(col)
	add_child(body)


## Floorboards downstairs, and the upper slab in three pieces so the stairwell
## is left open. Piece 3 is the strip of upper corridor in front of the stairs;
## everything behind it, over the ramp, is deliberately missing.
func _build_floors() -> void:
	var w: float = HOUSE_MAX.x - HOUSE_MIN.x
	var d: float = HOUSE_MAX.y - HOUSE_MIN.y
	var cx: float = (HOUSE_MIN.x + HOUSE_MAX.x) * 0.5
	var cz: float = (HOUSE_MIN.y + HOUSE_MAX.y) * 0.5
	var boards := Color("#3a2c24")

	# Ground floor, laid just above the island so the two never z-fight.
	_box(Vector3(w, 0.08, d), Vector3(cx, 0.04, cz), boards, false, "Floorboards")

	# Upper slab, in three pieces around the stairwell.
	# The stairwell only has to be open over the FLIGHT, not over the whole
	# corridor: the walkway beside it and the turning bay behind it are both
	# walked at ground level, where a slab 1.6 m up is well over a 0.85 m
	# player's head. Four pieces, cut around that one hole.
	var slab_y: float = UPPER_Y - SLAB_T * 0.5
	var left_w: float = STAIR_EDGE - HOUSE_MIN.x
	_upper_parts.append(_box(Vector3(left_w, SLAB_T, d),
		Vector3(HOUSE_MIN.x + left_w * 0.5, slab_y, cz),
		boards, true, "UpperSlabLeft"))
	var right_w: float = HOUSE_MAX.x - (STAIR_X + STAIR_W * 0.5)
	_upper_parts.append(_box(Vector3(right_w, SLAB_T, d),
		Vector3(STAIR_X + STAIR_W * 0.5 + right_w * 0.5, slab_y, cz),
		boards, true, "UpperSlabRight"))
	var back_d: float = STAIR_Z0 - HOUSE_MIN.y
	_upper_parts.append(_box(Vector3(STAIR_W, SLAB_T, back_d),
		Vector3(STAIR_X, slab_y, HOUSE_MIN.y + back_d * 0.5),
		boards, true, "UpperSlabBay"))
	var front_d: float = HOUSE_MAX.y - STAIR_Z1
	_upper_parts.append(_box(Vector3(STAIR_W, SLAB_T, front_d),
		Vector3(STAIR_X, slab_y, STAIR_Z1 + front_d * 0.5),
		boards, true, "UpperSlabFront"))


func _build_walls() -> void:
	var plaster := Color("#4a3f57")
	var i := 0
	for level in 2:
		var base: float = 0.0 if level == 0 else UPPER_Y
		var h: float = WALL_H if level == 0 else UPPER_WALL_H
		for seg in WALLS:
			var w := _wall_segment(seg, base, h, plaster, "Wall%d" % i)
			if level == 1:
				_upper_parts.append(w)
			i += 1

		# The front wall carries the front door downstairs and nothing upstairs
		# - an opening up there is a two-and-a-half metre drop onto the path.
		if level == 0:
			_wall_segment([HOUSE_MIN.x, HOUSE_MAX.y, -DOOR_W, HOUSE_MAX.y],
				base, h, plaster, "FrontWallLeft")
			_wall_segment([DOOR_W, HOUSE_MAX.y, HOUSE_MAX.x, HOUSE_MAX.y],
				base, h, plaster, "FrontWallRight")
		else:
			_upper_parts.append(_wall_segment(
				[HOUSE_MIN.x, HOUSE_MAX.y, HOUSE_MAX.x, HOUSE_MAX.y],
				base, h, plaster, "FrontWallUpper"))


func _wall_segment(seg: Array, base_y: float, h: float, colour: Color,
		node_name: String) -> Node3D:
	var a := Vector2(float(seg[0]), float(seg[1]))
	var b := Vector2(float(seg[2]), float(seg[3]))
	var mid: Vector2 = (a + b) * 0.5
	var span: Vector2 = b - a
	var size := Vector3(maxf(absf(span.x), WALL_T), h, maxf(absf(span.y), WALL_T))
	return _box(size, Vector3(mid.x, base_y + h * 0.5, mid.y), colour, true, node_name)


## The staircase: one inclined slab that the player actually walks on, with
## visible steps sitting on top of it purely as dressing.
##
## The steps have NO colliders. CharacterBody3D does not step up, so real risers
## would be a row of walls - a child would be stopped dead at the first one with
## no idea why, because it would look exactly like a staircase.
func _build_stairs() -> void:
	var run: float = STAIR_Z1 - STAIR_Z0
	var rise: float = UPPER_Y
	var angle: float = atan2(rise, run)
	var length: float = sqrt(run * run + rise * rise)

	var ramp := _box(Vector3(STAIR_W, 0.3, length),
		Vector3(STAIR_X, rise * 0.5 - 0.15 / cos(angle),
			(STAIR_Z0 + STAIR_Z1) * 0.5),
		Color("#3a2c24"), true, "Staircase")
	# Rotating about +X tips +Z downward, so the rise wants the NEGATIVE angle.
	ramp.rotation.x = -angle

	# Dressing: treads laid along the slope, inset so they never poke through.
	var treads := 9
	for i in treads:
		var t: float = (float(i) + 0.5) / float(treads)
		var step := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(STAIR_W * 0.94, 0.10, length / float(treads) * 0.82)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#4a3a2e")
		mat.roughness = 1.0
		cube.material = mat
		step.mesh = cube
		step.position = Vector3(0.0, 0.18, (t - 0.5) * length)
		ramp.add_child(step)


## Lit windows, eaves and a door frame.
##
## Without these the house is a wide flat box from the yard - it has to read as
## somewhere worth going into from the moment a child comes through the island
## door, and a plain wall does not. The windows are the only lit thing on the
## whole island besides the path lanterns, which is what makes it look occupied.
func _build_exterior_detail() -> void:
	var lit := Color("#f2c14e")
	var trim := Color("#241d31")
	var out: float = WALL_T * 0.5 + 0.03

	# [wall coordinate, along-axis positions, is the wall running along x]
	var runs := [
		{"at": HOUSE_MAX.y, "on": [-7.25, 7.25], "along_x": true, "dir": 1.0},
		{"at": HOUSE_MIN.y, "on": [-7.25, 7.25], "along_x": true, "dir": -1.0},
		{"at": HOUSE_MIN.x, "on": [-7.75, 6.0], "along_x": false, "dir": -1.0},
		{"at": HOUSE_MAX.x, "on": [-7.75, 6.0], "along_x": false, "dir": 1.0},
	]
	var n := 0
	for level in 2:
		var y: float = (1.45 if level == 0 else UPPER_Y + 1.35)
		for run in runs:
			for p in run["on"]:
				var size: Vector3
				var at: Vector3
				if run["along_x"]:
					size = Vector3(1.6, 1.15, 0.06)
					at = Vector3(p, y, float(run["at"]) + out * float(run["dir"]))
				else:
					size = Vector3(0.06, 1.15, 1.6)
					at = Vector3(float(run["at"]) + out * float(run["dir"]), y, p)
				var win := _glass(size, at, lit, "Window%d" % n)
				if level == 1:
					_upper_parts.append(win)
				n += 1

	# An eave capping the upper walls, so the silhouette ends in a line rather
	# than just stopping. Four bars around the perimeter.
	# Hung so its TOP lines up with the wall top rather than sitting proud of it.
	# Perched on top it adds 13 cm above every upper wall, which is enough to put
	# it back in the way of the camera that the wall height was just tuned to
	# clear - a decorative trim undoing the arithmetic above it.
	var top: float = UPPER_Y + UPPER_WALL_H - 0.13
	var w: float = HOUSE_MAX.x - HOUSE_MIN.x + 0.7
	var d: float = HOUSE_MAX.y - HOUSE_MIN.y + 0.7
	var cx: float = (HOUSE_MIN.x + HOUSE_MAX.x) * 0.5
	var cz: float = (HOUSE_MIN.y + HOUSE_MAX.y) * 0.5
	_upper_parts.append(_box(Vector3(w, 0.26, 0.7),
		Vector3(cx, top, HOUSE_MAX.y + 0.2), trim, false, "EaveFront"))
	_upper_parts.append(_box(Vector3(w, 0.26, 0.7),
		Vector3(cx, top, HOUSE_MIN.y - 0.2), trim, false, "EaveBack"))
	_upper_parts.append(_box(Vector3(0.7, 0.26, d),
		Vector3(HOUSE_MIN.x - 0.2, top, cz), trim, false, "EaveLeft"))
	_upper_parts.append(_box(Vector3(0.7, 0.26, d),
		Vector3(HOUSE_MAX.x + 0.2, top, cz), trim, false, "EaveRight"))

	# A frame round the front door, so the way in is unmistakable.
	var head: float = WALL_H
	_box(Vector3(DOOR_W * 2.0 + 0.8, 0.3, 0.5),
		Vector3(0.0, head, HOUSE_MAX.y), trim, false, "DoorHead")
	for side in [-1.0, 1.0]:
		_box(Vector3(0.4, head, 0.5),
			Vector3(side * (DOOR_W + 0.2), head * 0.5, HOUSE_MAX.y),
			trim, false, "DoorPost%d" % int(side))


## A pane that glows. Emissive rather than an actual light: there is one sun in
## this game and adding real lights to eight windows would cost more than it is
## worth for something only ever seen from outside.
func _glass(size: Vector3, at: Vector3, colour: Color, node_name: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = at
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.emission_enabled = true
	mat.emission = colour
	mat.emission_energy_multiplier = 0.9
	mat.roughness = 1.0
	cube.material = mat
	mesh.mesh = cube
	holder.add_child(mesh)
	add_child(holder)
	return holder


# -- the yard ------------------------------------------------------------

## Bare trees on the rim, with the arrival corridor left clear: the rim is at
## r ~20 and the player lands at z = +18, so a tree at +Z stands two metres in
## front of the door and fills the screen the instant you walk in.
func _build_yard() -> void:
	for i in 11:
		var a: float = TAU * float(i) / 11.0 + 0.35
		if absf(angle_difference(a, PI * 0.5)) < 0.55:
			continue
		var r: float = 21.0 + randf_range(-1.5, 2.5)
		var prop := Decor.new()
		prop.name = "SpookyTree%d" % i
		prop.model_path = "res://assets/models/spooky_tree.glb"
		prop.height = randf_range(4.4, 6.4)
		prop.yaw = randf() * TAU
		prop.sway = 0.02
		# The generated bark reads green-black under the meadow sun, which puts
		# a living forest around a dead yard.
		prop.repaint = Color(0.20, 0.17, 0.23)
		prop.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		add_child(prop)

	# Clear of the footprint, which now reaches x +-10.5 and z -11.5 to 8.
	var graves := [
		Vector3(-14.5, 0, 11.0), Vector3(-17.0, 0, 2.0), Vector3(-15.0, 0, -8.0),
		Vector3(14.5, 0, 11.5), Vector3(17.0, 0, 1.5), Vector3(15.0, 0, -8.5),
	]
	for i in graves.size():
		var prop := Decor.new()
		prop.name = "Gravestone%d" % i
		prop.model_path = "res://assets/models/gravestone.glb"
		prop.height = randf_range(1.1, 1.5)
		prop.yaw = randf_range(-0.35, 0.35)
		# The generated stone is so pale it comes back as ice-blue out here.
		prop.repaint = Color(0.38, 0.36, 0.41)
		prop.position = graves[i]
		add_child(prop)

	# Pumpkins either side of the path up to the front door.
	var pumpkins := [
		Vector3(-3.4, 0, 15.5), Vector3(3.6, 0, 14.5), Vector3(-3.8, 0, 11.0),
		Vector3(3.4, 0, 10.0), Vector3(-12.5, 0, 13.0), Vector3(12.0, 0, 12.5),
	]
	for i in pumpkins.size():
		var prop := Decor.new()
		prop.name = "Pumpkin%d" % i
		prop.model_path = "res://assets/models/pumpkin.glb"
		prop.height = randf_range(0.55, 0.85)
		prop.yaw = randf() * TAU
		prop.position = pumpkins[i]
		add_child(prop)

	# Lanterns down the path. The only warm thing outside, which is what makes
	# the walk to the door read as arriving somewhere.
	for i in 4:
		var z: float = 16.8 - float(i) * 2.2
		for side in [-1.0, 1.0]:
			var prop := Decor.new()
			prop.name = "PathLantern%d_%d" % [i, int(side)]
			prop.model_path = "res://assets/models/lantern.glb"
			prop.height = 0.8
			prop.position = Vector3(side * 2.2, 0.0, z)
			add_child(prop)


## A lantern in each room, on both floors. They are how a room reads as a room
## from above rather than as an empty box, and they mark the doorway you came
## in through when the walls all look alike.
func _build_interior_dressing() -> void:
	var corners := [Vector2(-7.25, 6.0), Vector2(7.25, 6.0),
		Vector2(-7.25, -7.75), Vector2(7.25, -7.75)]
	var i := 0
	for level in 2:
		var y: float = 0.0 if level == 0 else UPPER_Y
		for c in corners:
			var prop := Decor.new()
			prop.name = "RoomLantern%d" % i
			prop.model_path = "res://assets/models/lantern.glb"
			prop.height = 0.8
			# Tucked into the room's outer corner, clear of where a ghost floats.
			prop.position = Vector3(c.x + (2.6 if c.x > 0 else -2.6), y,
				c.y + (1.4 if c.y > 0 else -2.6))
			add_child(prop)
			if level == 1:
				_upper_parts.append(prop)
			i += 1


# -- the ghosts ----------------------------------------------------------

func _build_ghosts() -> void:
	for e in EMOTIONS:
		var spot: Dictionary = HIDING[e]
		var at: Vector2 = spot["pos"]
		var ghost := GhostFigure.new()
		ghost.emotion = e
		ghost.name = "Ghost_%s" % e
		ghost.height = GHOST_H
		ghost.tint = TINTS[e]
		ghost.player = player
		ghost.position = Vector3(at.x, UPPER_Y if spot["upper"] else 0.0, at.y)
		ghost.touched.connect(_on_touched)
		add_child(ghost)
		_ghosts.append(ghost)
		# An upstairs ghost goes with its floor. Left visible it would hang in
		# mid-air over a ground-floor room with its own storey lifted away,
		# which reads as a bug rather than as a ghost.
		if spot["upper"]:
			_upper_parts.append(ghost)


## Which room a feeling is hiding in, for the HUD's nudge after two wrong tries.
func room_of(emotion: String) -> String:
	var spot: Dictionary = HIDING.get(emotion, {})
	return String(spot.get("room", ""))


func is_upstairs(emotion: String) -> bool:
	var spot: Dictionary = HIDING.get(emotion, {})
	return bool(spot.get("upper", false))


# -- the game ------------------------------------------------------------

## Fresh game. Every feeling is asked exactly once, in a shuffled order, so the
## round count is honest and nothing repeats.
func restart() -> void:
	_done = false
	_busy = false
	_round = 0
	_wrong = 0
	for g in _ghosts:
		g.set_lit(false)
	_queue = ROUNDS.duplicate()
	_queue.shuffle()
	_next_round()


func _next_round() -> void:
	if _queue.is_empty():
		_finish()
		return
	_current = _queue.pop_front()
	_wrong = 0
	_busy = false
	round_started.emit(String(_current["text"]))
	_say(_asks[_current["clip"]])
	_claim_overlaps()


## Count a ghost the player is ALREADY touching when a round begins.
##
## body_entered only fires on a CROSSING, so a round whose answer is the ghost
## you are already standing in would wait forever for an event that cannot
## arrive, and the island would deadlock (trap 1). It matters more here than
## anywhere: the ghosts float in small rooms, and walking into one is how you
## find it, so a child is very often standing in a ghost when a round ends.
func _claim_overlaps() -> void:
	await get_tree().physics_frame
	if _done or _current.is_empty():
		return
	var want := String(_current["answer"])
	for g in _ghosts:
		if g.emotion != want:
			continue
		for body in g.get_overlapping_bodies():
			if body is Player:
				_on_touched(g)
				return


func _on_touched(ghost: GhostFigure) -> void:
	# Free play once the game is won: every ghost just names its own feeling.
	if _done:
		_say(_names[ghost.emotion])
		ghost.cheer()
		return
	if _busy or _current.is_empty():
		return

	if ghost.emotion == String(_current["answer"]):
		_busy = true
		ghost.cheer()
		_say(_names[ghost.emotion])
		answered.emit(true, ghost.emotion)
		_after_correct()
	else:
		ghost.buzz()
		_wrong += 1
		_say(_retry)
		answered.emit(false, ghost.emotion)
		if _wrong >= HINT_AFTER:
			_hint()


## Nudge the answer. A bob is no use when the ghost is two rooms away and out of
## sight, so the hint here is its VOICE - it says its own feeling, from wherever
## it is hiding, and Game.gd puts the room on the prompt line at the same time.
func _hint() -> void:
	if _current.is_empty():
		return
	var want := String(_current["answer"])
	for g in _ghosts:
		if g.emotion == want:
			g.hint()
	_say(_names[want])


func _after_correct() -> void:
	await get_tree().create_timer(1.5).timeout
	if _done:
		return
	_round += 1
	_next_round()


func _finish() -> void:
	_done = true
	_current = {}
	completed.emit()
	_say(_praise)
	for g in _ghosts:
		g.cheer()


func _say(clip: AudioStream) -> void:
	if _voice == null or clip == null:
		return
	_voice.stream = clip
	_voice.play()


## Say the current question again - used when the player walks back in.
func repeat_prompt() -> void:
	if not _done and not _current.is_empty():
		_say(_asks[_current["clip"]])


func question() -> String:
	if _done or _current.is_empty():
		return ""
	return String(_current["text"])


func target() -> String:
	if _done or _current.is_empty():
		return ""
	return String(_current["answer"])


func wrong_count() -> int:
	return _wrong


func round_index() -> int:
	return _round


func is_complete() -> bool:
	return _done
