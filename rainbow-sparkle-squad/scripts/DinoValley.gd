class_name DinoValley
extends Node3D

## Dino Valley: three dinosaurs roaming the ground, one wheeling overhead, and
## a smoking volcano at the far end.
##
## This island is the odd one out on purpose. Blockland, Shape Cove and Letter
## Lagoon all put their subject in a ring and wait to be touched - the thing
## being learned stands still. Here the subject walks away from you. A
## three-year-old chasing a Triceratops around a valley is doing something the
## other islands cannot offer, and the naming lands *because* they had to work
## to catch it.
##
## The structured game underneath is SIZE - biggest, smallest, and which one
## flies. Comparison is the one preschool idea the other three islands never
## touch, and dinosaurs are the perfect excuse for it because the size
## difference is the first thing a child notices about them.

signal round_started(question: String)
signal answered(correct: bool, species: String)
signal completed

## species -> (height in metres, roaming home offset, roam radius)
## Heights are the game: T-rex is unmistakably the biggest and Triceratops the
## smallest, so "find the biggest" is answerable by looking rather than by
## knowing. The toy liberty of a small Triceratops is worth a working question.
const DINOS := {
	"trex":        {"h": 2.8, "home": Vector3(-6.0, 0, -2.0), "roam": 6.5},
	"stegosaurus": {"h": 2.2, "home": Vector3(7.0, 0, -3.0), "roam": 6.0},
	"triceratops": {"h": 1.5, "home": Vector3(0.5, 0, 6.5), "roam": 6.0},
	"pteranodon":  {"h": 1.8, "home": Vector3(0.0, 0, 0.0), "roam": 11.0},
}

## The three questions, in order, with the species that answers each. Every
## answer is a different dinosaur - two questions with the same answer would
## teach nothing on the second.
const ROUNDS := [
	{"clip": "ask_biggest", "answer": "trex", "text": "Find the BIGGEST dinosaur!"},
	{"clip": "ask_smallest", "answer": "triceratops", "text": "Find the SMALLEST dinosaur!"},
	{"clip": "ask_flies", "answer": "pteranodon", "text": "Which dinosaur can FLY?"},
]

const GROUND_R := 26.0
const HINT_AFTER := 2

var _dinos: Array[Dinosaur] = []
var _round := 0
var _wrong := 0
var _done := false
var _busy := false
var _voice: AudioStreamPlayer
var _roar: AudioStreamPlayer

var _names := {}
var _roars := {}
var _asks := {}


func _ready() -> void:
	_load_clips()
	_build_ground()
	_build_volcano()
	_build_ferns()
	_build_dinos()

	_voice = AudioStreamPlayer.new()
	_voice.name = "DinoVoice"
	_voice.volume_db = 2.0
	add_child(_voice)

	# The roar gets its own player so a name and a roar can overlap - the
	# dinosaur bellows and is introduced at the same time, which is livelier
	# than waiting politely for each other.
	_roar = AudioStreamPlayer.new()
	_roar.name = "DinoRoar"
	_roar.volume_db = -1.0
	add_child(_roar)


func _load_clips() -> void:
	for s in DINOS:
		_names[s] = load("res://assets/audio/dino_%s.wav" % s)
		_roars[s] = load("res://assets/audio/roar_%s.wav" % s)
	for r in ROUNDS:
		_asks[r["clip"]] = load("res://assets/audio/%s.wav" % r["clip"])


# -- the valley ----------------------------------------------------------

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "ValleyGround"

	var mesh := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = GROUND_R
	drum.bottom_radius = GROUND_R * 0.96
	drum.height = 1.2
	drum.radial_segments = 56
	var mat := StandardMaterial3D.new()
	# Dry olive earth - it has to read as somewhere else entirely from the
	# meadow's green and the two sand islands. Set dark, because the meadow sun
	# and filmic tonemap lift every ground plane here well past its swatch.
	mat.albedo_color = Color("#6b6435")
	mat.roughness = 0.98
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


## A volcano at the far end, built from primitives: a wide cone, a dark crater,
## and a slow plume of smoke puffs drifting up. Pure backdrop - it is behind the
## roaming area and has no collider, because the point is the skyline, not an
## obstacle for a small player to get stuck on.
func _build_volcano() -> void:
	var here := Node3D.new()
	here.name = "Volcano"
	here.position = Vector3(0, 0, -21.0)
	add_child(here)

	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.2
	cm.bottom_radius = 9.0
	cm.height = 9.0
	cm.radial_segments = 24
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color("#5c4a42")
	cmat.roughness = 1.0
	cm.material = cmat
	cone.mesh = cm
	cone.position.y = 4.5
	here.add_child(cone)

	var crater := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = 1.9
	km.bottom_radius = 1.9
	km.height = 0.4
	km.radial_segments = 20
	var kmat := StandardMaterial3D.new()
	kmat.albedo_color = Color("#e2622c")
	kmat.emission_enabled = true
	kmat.emission = Color("#ff7a33")
	kmat.emission_energy_multiplier = 1.4
	km.material = kmat
	crater.mesh = km
	crater.position.y = 9.0
	here.add_child(crater)

	# Smoke drifts sideways as it rises and thins out as it goes, otherwise five
	# puffs stacked straight up just read as a column of boulders.
	for i in 5:
		var t: float = float(i) / 4.0
		var puff := Decor.new()
		puff.name = "Smoke%d" % i
		puff.model_path = "res://assets/models/cloud_puff.glb"
		puff.height = 2.6 + t * 3.4
		puff.by_width = true
		puff.bob = 0.4
		puff.bob_hz = 0.07 + i * 0.012
		puff.repaint = Color(0.62, 0.60, 0.58).lerp(Color(0.80, 0.79, 0.78), t)
		puff.position = Vector3(
			2.6 * t + randf_range(-0.5, 0.5),
			10.0 + t * 5.0,
			1.4 * t + randf_range(-0.5, 0.5))
		here.add_child(puff)


## Prehistoric greenery, reusing the meadow's tree repainted to jungle greens.
## Generating a separate fern would look marginally better and cost another
## model; recolouring one that already exists is the cheaper honest answer.
func _build_ferns() -> void:
	var greens := [Color(0.30, 0.42, 0.22), Color(0.24, 0.38, 0.26),
		Color(0.36, 0.46, 0.24)]
	for i in 12:
		var a: float = TAU * float(i) / 12.0 + 0.35
		var r: float = 17.0 + randf_range(-1.5, 3.0)
		var prop := Decor.new()
		prop.name = "Fern%d" % i
		prop.model_path = "res://assets/models/candy_tree.glb"
		prop.height = randf_range(3.4, 5.2)
		prop.yaw = randf() * TAU
		prop.sway = 0.018
		prop.repaint = greens[i % greens.size()]
		prop.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		add_child(prop)


func _build_dinos() -> void:
	for species in DINOS:
		var spec: Dictionary = DINOS[species]
		var dino := Dinosaur.new()
		dino.name = "Dino_%s" % species
		dino.species = species
		dino.height = float(spec["h"])
		# DINOS holds local offsets, but Dinosaur steers in world space - convert
		# here rather than making every dinosaur know where its island sits.
		dino.home = global_position + spec["home"]
		dino.roam_radius = float(spec["roam"])
		dino.mode = Dinosaur.Mode.FLYER if species == "pteranodon" \
			else Dinosaur.Mode.WALKER
		dino.position = spec["home"] + Vector3(0, 0.5, 0)
		dino.touched.connect(_on_touched)
		add_child(dino)
		_dinos.append(dino)


# -- the game ------------------------------------------------------------

func restart() -> void:
	_done = false
	_busy = false
	_round = 0
	_wrong = 0
	_start_round()


func _start_round() -> void:
	if _round >= ROUNDS.size():
		_finish()
		return
	_wrong = 0
	_busy = false
	var r: Dictionary = ROUNDS[_round]
	round_started.emit(String(r["text"]))
	_say(_asks[r["clip"]])
	_claim_overlaps()


## Count a dinosaur the player is ALREADY standing next to when a round begins.
##
## body_entered only fires on a crossing, so a round whose answer is the animal
## you are already touching would otherwise wait for an event that can never
## come. The dinosaurs walk away on their own, which usually breaks the deadlock
## by accident - but "usually" is not a guarantee, and the same edge has cost
## this project three bugs already (Blockland's cooldown, Blockland's reset,
## Letter Lagoon's round boundary). Handled up front here rather than waited for.
func _claim_overlaps() -> void:
	await get_tree().physics_frame
	if _done:
		return
	var want := String(ROUNDS[_round]["answer"])
	for d in _dinos:
		if d.species != want:
			continue
		for area in d.get_children():
			if area is Area3D:
				for body in (area as Area3D).get_overlapping_bodies():
					if body is Player:
						_on_touched(d)
						return


func _on_touched(dino: Dinosaur) -> void:
	# Meeting a dinosaur ALWAYS introduces it, win or lose, game over or not.
	# The naming is the part worth having; the quiz is just a reason to go
	# looking.
	_say(_names[dino.species])
	_roar_of(dino)
	dino.cheer()

	if _done or _busy:
		return

	var want := String(ROUNDS[_round]["answer"])
	if dino.species == want:
		_busy = true
		answered.emit(true, dino.species)
		_next_round_soon()
	else:
		_wrong += 1
		answered.emit(false, dino.species)
		if _wrong >= HINT_AFTER:
			_hint(want)


## Nudge the right answer without saying which - a stomp and a roar from across
## the valley is a direction to run in, not the answer handed over.
func _hint(want: String) -> void:
	for d in _dinos:
		if d.species == want:
			d.stomp()
			_roar_of(d)


func _roar_of(dino: Dinosaur) -> void:
	var clip: AudioStream = _roars.get(dino.species)
	if clip != null:
		_roar.stream = clip
		_roar.play()


## Let the name and roar finish before the next question - they overlap each
## other happily, but a question underneath them would be lost.
func _next_round_soon() -> void:
	await get_tree().create_timer(2.0).timeout
	if _done:
		return
	_round += 1
	_start_round()


func _finish() -> void:
	_done = true
	completed.emit()
	_say(load("res://assets/audio/say_wellDone.wav"))
	for d in _dinos:
		d.cheer()


func _say(clip: AudioStream) -> void:
	if _voice == null or clip == null:
		return
	_voice.stream = clip
	_voice.play()


func question() -> String:
	if _done or _round >= ROUNDS.size():
		return ""
	return String(ROUNDS[_round]["text"])


func round_index() -> int:
	return _round


func is_complete() -> bool:
	return _done
