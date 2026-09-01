class_name HauntedHouse
extends Node3D

## The Haunted House: a crooked manor on a dark hill, five friendly ghosts
## floating in the yard, and the game of reading their faces.
##
## The game is EMOTIONS - who looks happy, sad, angry, scared, sleepy. Every
## other island asks about a property of the world: what number comes next, which
## one is the triangle, what sound does this letter make, which dinosaur is
## biggest, who has stripes. This one asks about a FEELING, which is the first
## thing a three-year-old learns to read off a face and the only subject here
## that is about people rather than things.
##
## Why these five and not the textbook set: "surprised" and "scared" are the same
## face - wide eyes, open mouth, raised brows - and the Safari Plains rule
## applies just as hard here, that every question must name something
## unmistakable on its answer and absent from all the rest. Sleepy is
## unmistakable (closed eyes, a yawn) where surprised is a coin flip, so sleepy
## is in and surprised is out.
##
## The ghosts share one body and differ only in expression, so the face is the
## only thing that can answer the question. See GhostFigure.

signal round_started(question: String)
signal answered(correct: bool, emotion: String)
signal completed

## The five feelings, in ring order. Each ghost is generated from the same body
## prompt with only the face changed - see tools/import_assets.py.
const EMOTIONS: Array[String] = ["happy", "sad", "angry", "scared", "sleepy"]

## Washes multiplied into each near-white ghost so it does not render as a
## featureless blob (trap 4).
##
## These started around 0.9 and that was nowhere near enough: the bodies still
## clipped to flat white under the sun and took the faces with them, which on
## an island whose entire lesson is the face is the whole thing failing. At
## about 0.65 the body sits inside the exposure and the eyes and mouth survive.
## They read as pale grey rather than white, which a ghost can afford.
##
## Deliberately DECORRELATED from the feelings - sad is not the blue one, angry
## is not the red one - because a child who can sort these by colour has
## stopped looking at the faces. hauntedhousetest asserts they stay both
## distinct and too close together to rank by.
const TINTS := {
	"happy": Color("#a1a6ae"),
	"sad": Color("#aba89e"),
	"angry": Color("#a4aba6"),
	"scared": Color("#a8a3ae"),
	"sleepy": Color("#aea3a6"),
}

## One round per feeling. `clip` is the spoken question, which is the real
## instruction - the text is the backup, exactly as in Shape Cove.
## Typed, unlike the Safari's, because `restart` shuffles a duplicate of this
## into `_queue: Array[Dictionary]` - and duplicating an UNtyped const array
## into a typed variable is a runtime type error, not a parse one, so it would
## have shipped as an island that throws the moment you walk through its door.
const ROUNDS: Array[Dictionary] = [
	{"clip": "feel_happy", "answer": "happy", "text": "Who looks HAPPY?"},
	{"clip": "feel_sad", "answer": "sad", "text": "Who looks SAD?"},
	{"clip": "feel_angry", "answer": "angry", "text": "Who looks ANGRY?"},
	{"clip": "feel_scared", "answer": "scared", "text": "Who looks SCARED?"},
	{"clip": "feel_sleepy", "answer": "sleepy", "text": "Who looks SLEEPY?"},
]

const GROUND_R := 26.0
const RING_R := 9.0
## Matched to a Shape Cove figure rather than made bigger for effect: these are
## floated off the ground on top of this (GhostFigure.HOVER), so anything taller
## puts the faces out of a three-year-old's comfortable eyeline.
const GHOST_H := 1.6
const HINT_AFTER := 2
const HOUSE_AT := Vector3(0, 0, -16.5)

## Set by Game.gd before this enters the tree, and handed on to every ghost so
## they can turn to watch - see GhostFigure.player for why that matters here.
var player: Node3D

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
	_build_house()
	_build_trees()
	_build_graves()
	_build_lanterns()
	_build_ghosts()

	_voice = AudioStreamPlayer.new()
	_voice.name = "HauntedVoice"
	_voice.volume_db = 2.0
	add_child(_voice)


func _load_clips() -> void:
	for e in EMOTIONS:
		_names[e] = load("res://assets/audio/emotion_%s.wav" % e)
	for r in ROUNDS:
		_asks[r["clip"]] = load("res://assets/audio/%s.wav" % r["clip"])
	_praise = load("res://assets/audio/say_wellDone.wav")
	_retry = load("res://assets/audio/say_tryAgain.wav")


# -- the grounds ---------------------------------------------------------

## A dark hill. There is ONE sun in this world and one environment - every
## island shares the meadow's sky, because it is all a single scene - so
## "haunted" cannot be done with lighting without turning the meadow off too.
## It has to come from the palette instead: a near-black violet earth, bare
## trees and cold stone, which is why this ground is far darker than any other
## island's and still lands mid-grey on screen (trap 4).
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
	# Trap 4, and worse here than anywhere else: #332b40 - already a dark
	# swatch - came back off the GPU as a pale lavender field that read as a
	# meadow at dusk. This is roughly half that again, and it lands as the dim
	# violet earth the picker makes it look far too dark to be.
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


## The manor, set at the back of the yard so it is the thing you walk towards
## from the door and never the thing you have to walk around. It is scenery with
## a collider, not a building you can enter - the game is in the yard.
func _build_house() -> void:
	var house := Models.spawn("res://assets/models/haunted_house.glb", 11.0)
	house.name = "Manor"
	house.position = HOUSE_AT
	add_child(house)

	# Stop a player walking into the facade. A box is enough: nothing about the
	# silhouette rewards a tighter fit, and the model is one welded shell.
	var body := StaticBody3D.new()
	body.name = "ManorCollider"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(11.0, 11.0, 7.0)
	col.shape = box
	col.position.y = 5.5
	body.add_child(col)
	body.position = HOUSE_AT
	add_child(body)


## A ring of bare trees on the rim. Same job as Shape Cove's palms and the
## savanna's acacias - a horizon that says where you are - but generated
## properly rather than repainted, because a leafless silhouette is the single
## strongest read of "spooky" available and the repainted candy_tree could never
## give it (see the known rough edge about that stand-in).
func _build_trees() -> void:
	for i in 11:
		var a: float = TAU * float(i) / 11.0 + 0.35
		# Leave the arrival corridor clear. The rim is at r ~20 and the player
		# lands at z = +18, so a tree at +Z stands about two metres in front of
		# the door and fills the screen the instant you walk in - the first
		# shot of this island was a close-up of bark with the whole yard
		# hidden behind it.
		if absf(angle_difference(a, PI * 0.5)) < 0.55:
			continue
		var r: float = 20.5 + randf_range(-1.5, 2.5)
		var prop := Decor.new()
		prop.name = "SpookyTree%d" % i
		prop.model_path = "res://assets/models/spooky_tree.glb"
		prop.height = randf_range(4.4, 6.4)
		prop.yaw = randf() * TAU
		prop.sway = 0.02
		# The generated bark reads green-black under the meadow sun, which puts
		# a living forest around a dead yard. Repainted for the same reason the
		# savanna repaints its acacias: on a silhouette prop the colour is the
		# whole read, and the texture underneath is not carrying anything.
		prop.repaint = Color(0.20, 0.17, 0.23)
		prop.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		add_child(prop)


## Gravestones and pumpkins, scattered off the ring so they dress the yard
## without ever standing between a player and a ghost.
func _build_graves() -> void:
	var spots := [
		Vector3(-14.0, 0, -6.0), Vector3(-15.5, 0, 1.5), Vector3(-12.5, 0, 8.0),
		Vector3(14.0, 0, -6.5), Vector3(15.5, 0, 1.0), Vector3(12.5, 0, 8.5),
	]
	for i in spots.size():
		var prop := Decor.new()
		prop.name = "Gravestone%d" % i
		prop.model_path = "res://assets/models/gravestone.glb"
		prop.height = randf_range(1.1, 1.5)
		prop.yaw = randf_range(-0.35, 0.35)
		# The generated stone is so pale it comes back as ice-blue out here.
		prop.repaint = Color(0.38, 0.36, 0.41)
		prop.position = spots[i]
		add_child(prop)

	var pumpkins := [
		Vector3(-6.5, 0, 13.5), Vector3(-3.0, 0, 15.0), Vector3(4.0, 0, 14.5),
		Vector3(7.5, 0, 12.5), Vector3(-9.5, 0, -11.0), Vector3(9.0, 0, -11.5),
	]
	for i in pumpkins.size():
		var prop := Decor.new()
		prop.name = "Pumpkin%d" % i
		prop.model_path = "res://assets/models/pumpkin.glb"
		prop.height = randf_range(0.55, 0.85)
		prop.yaw = randf() * TAU
		prop.position = pumpkins[i]
		add_child(prop)


## Lanterns on the path from the door to the ring. They are the only warm thing
## on the island, which is what makes the walk in read as arriving somewhere
## rather than wandering onto a dark field.
func _build_lanterns() -> void:
	for i in 4:
		var z: float = 17.0 - float(i) * 3.0
		for side in [-1.0, 1.0]:
			var prop := Decor.new()
			prop.name = "Lantern%d_%d" % [i, int(side)]
			prop.model_path = "res://assets/models/lantern.glb"
			prop.height = 0.75
			# Stood on the ground, not hung. The model has a carrying ring on
			# top, and hovering it at waist height with no post and no chain
			# just looked like a prop that had lost its collider.
			prop.position = Vector3(side * 2.6, 0.0, z)
			add_child(prop)


## The five ghosts in a fixed ring, evenly spaced, facing the middle.
##
## Fixed and not shuffled between rounds for the same reason Shape Cove's
## figures are: at three, knowing where the sad one lives is a win worth
## keeping, and the puzzle is the face, not the memory of where it moved to.
func _build_ghosts() -> void:
	for i in EMOTIONS.size():
		var ghost := GhostFigure.new()
		ghost.emotion = EMOTIONS[i]
		ghost.name = "Ghost_%s" % EMOTIONS[i]
		ghost.height = GHOST_H
		ghost.tint = TINTS[EMOTIONS[i]]
		ghost.player = player

		var a: float = TAU * float(i) / float(EMOTIONS.size()) - PI * 0.5
		var pos := Vector3(cos(a) * RING_R, 0.0, sin(a) * RING_R)
		ghost.position = pos
		# Models.spawn already turned the model to face -Z, so this aims the
		# face at the centre of the ring. An extra PI here would show a plaza of
		# ghosts their own backs (trap 5).
		ghost.rotation.y = atan2(pos.x, pos.z)
		ghost.touched.connect(_on_touched)
		add_child(ghost)
		_ghosts.append(ghost)


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
## arrive, and the island would deadlock with no way out but walking off and
## back on (trap 1). Every island carries this guard; this one needs it more
## than most, because the ghosts float and a player can drift to a stop inside
## one without ever meaning to.
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


## Nudge the right answer without lighting it - a bob is enough of a clue and
## keeps the discovery with the player.
func _hint() -> void:
	if _current.is_empty():
		return
	var want := String(_current["answer"])
	for g in _ghosts:
		if g.emotion == want:
			g.hint()


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


func round_index() -> int:
	return _round


func is_complete() -> bool:
	return _done
