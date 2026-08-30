class_name SafariPlains
extends Node3D

## The Safari Plains: a giraffe, a pride of lions, a hippo at the waterhole, an
## elephant and a zebra, under a flat-topped acacia horizon.
##
## The animals roam with `RoamingAnimal`, the same script Dino Valley uses -
## a Triceratops and a rhinoceros want identical behaviour, and the differences
## that matter (how fast, how heavy the gait, how long the pauses) are numbers
## in ANIMALS below rather than a second copy of the movement code.
##
## The game is "I spy" by FEATURE: who has a long neck, a mane, stripes, a
## trunk, the biggest mouth. Dino Valley already asks about size and the other
## islands about names, so this one asks a child to LOOK at an animal and
## describe what they can see. Every question names something unmistakable on
## its animal and absent from all the others, which is what makes it answerable
## by observation rather than by already knowing the answer.

signal round_started(question: String)
signal answered(correct: bool, species: String)
signal completed

## species -> height, where it lives, how far it wanders, and how it moves.
## `count` puts more than one on the plain: the lions are a pride, which is
## also why "who has a mane" has to match by SPECIES and not by a single node.
const ANIMALS := {
	"giraffe": {
		"h": 4.2, "home": Vector3(-8.0, 0, -6.0), "roam": 6.0, "count": 1,
		"speed": 1.1, "gait": 0.9, "roll": 0.045, "pause": Vector2(2.0, 5.0),
	},
	"elephant": {
		"h": 3.0, "home": Vector3(9.0, 0, -5.0), "roam": 6.0, "count": 1,
		"speed": 1.0, "gait": 0.8, "roll": 0.075, "pause": Vector2(2.5, 5.5),
	},
	"hippo": {
		"h": 1.6, "home": Vector3(0.0, 0, 10.5), "roam": 3.5, "count": 1,
		"speed": 0.8, "gait": 1.0, "roll": 0.085, "pause": Vector2(3.5, 7.0),
	},
	"lion": {
		"h": 1.4, "home": Vector3(-7.0, 0, 6.0), "roam": 4.5, "count": 3,
		"speed": 1.4, "gait": 1.6, "roll": 0.05, "pause": Vector2(2.0, 6.0),
	},
	"zebra": {
		"h": 1.7, "home": Vector3(8.0, 0, 7.0), "roam": 6.5, "count": 1,
		"speed": 2.1, "gait": 2.1, "roll": 0.04, "pause": Vector2(0.8, 2.5),
	},
}

## Each question names one feature. Every answer is a different animal.
const ROUNDS := [
	{"clip": "spy_neck", "answer": "giraffe", "text": "Who has a very LONG NECK?"},
	{"clip": "spy_stripes", "answer": "zebra", "text": "Who has black and white STRIPES?"},
	{"clip": "spy_trunk", "answer": "elephant", "text": "Who has a long TRUNK?"},
	{"clip": "spy_mane", "answer": "lion", "text": "Who has a big fluffy MANE?"},
	{"clip": "spy_mouth", "answer": "hippo", "text": "Who has the BIGGEST MOUTH?"},
]

const GROUND_R := 28.0
const HINT_AFTER := 2
const WATERHOLE := Vector3(0, 0, 11.0)

var _animals: Array[RoamingAnimal] = []
var _round := 0
var _wrong := 0
var _done := false
var _busy := false
var _voice: AudioStreamPlayer
var _call: AudioStreamPlayer

var _names := {}
var _calls := {}
var _asks := {}


func _ready() -> void:
	_load_clips()
	_build_ground()
	_build_waterhole()
	_build_acacias()
	_build_rocks()
	_build_animals()

	_voice = AudioStreamPlayer.new()
	_voice.name = "SafariVoice"
	_voice.volume_db = 2.0
	add_child(_voice)

	# Separate player so a name and a call can overlap, exactly as in the
	# valley - the animal answers and is introduced at the same moment.
	_call = AudioStreamPlayer.new()
	_call.name = "SafariCall"
	_call.volume_db = -1.0
	add_child(_call)


func _load_clips() -> void:
	for s in ANIMALS:
		_names[s] = load("res://assets/audio/animal_%s.wav" % s)
		_calls[s] = load("res://assets/audio/roar_%s.wav" % s)
	for r in ROUNDS:
		_asks[r["clip"]] = load("res://assets/audio/%s.wav" % r["clip"])


# -- the plains ----------------------------------------------------------

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "SafariGround"

	var mesh := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = GROUND_R
	drum.bottom_radius = GROUND_R * 0.96
	drum.height = 1.2
	drum.radial_segments = 56
	var mat := StandardMaterial3D.new()
	# Dry savanna gold. Every biome so far has needed its ground set darker than
	# the swatch looks, because the meadow sun and filmic tonemap lift it.
	mat.albedo_color = Color("#9c8340")
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


## A shallow waterhole for the hippo to stand in - the one landmark on an
## otherwise open plain, and the reason the hippo has somewhere to be.
func _build_waterhole() -> void:
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 5.0
	disc.bottom_radius = 4.6
	disc.height = 0.3
	disc.radial_segments = 40
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.26, 0.55, 0.62, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.12
	disc.material = mat
	water.mesh = disc
	# Just below ground level, so the animals stand IN it rather than on it.
	water.position = WATERHOLE + Vector3(0, -0.1, 0)
	add_child(water)

	# A muddy rim so the edge reads instead of the water floating on gold.
	var rim := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 5.8
	rm.bottom_radius = 5.8
	rm.height = 0.16
	rm.radial_segments = 40
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color("#6d5a33")
	rmat.roughness = 1.0
	rm.material = rmat
	rim.mesh = rm
	rim.position = WATERHOLE + Vector3(0, -0.16, 0)
	add_child(rim)


## Acacias: the meadow's tree repainted savanna green and squashed flat on top,
## which is the whole silhouette of an African plain. Scaling by width rather
## than height is what flattens the canopy.
func _build_acacias() -> void:
	var greens := [Color(0.34, 0.40, 0.20), Color(0.28, 0.36, 0.19),
		Color(0.38, 0.43, 0.22)]
	for i in 10:
		var a: float = TAU * float(i) / 10.0 + 0.6
		var r: float = 19.0 + randf_range(-1.5, 3.5)
		var prop := Decor.new()
		prop.name = "Acacia%d" % i
		prop.model_path = "res://assets/models/candy_tree.glb"
		prop.height = randf_range(5.0, 7.0)
		prop.by_width = true
		prop.yaw = randf() * TAU
		prop.sway = 0.014
		prop.repaint = greens[i % greens.size()]
		prop.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		add_child(prop)


## A few sun-bleached boulders, reusing the crystal cluster repainted to stone.
func _build_rocks() -> void:
	for i in 6:
		var a: float = TAU * float(i) / 6.0 + 1.1
		var r: float = 13.0 + randf_range(-2.0, 3.0)
		var prop := Decor.new()
		prop.name = "Rock%d" % i
		prop.model_path = "res://assets/models/crystal_cluster.glb"
		prop.height = randf_range(1.2, 2.2)
		prop.yaw = randf() * TAU
		prop.repaint = Color(0.44, 0.39, 0.32)
		prop.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		add_child(prop)


func _build_animals() -> void:
	for species in ANIMALS:
		var spec: Dictionary = ANIMALS[species]
		var count: int = int(spec["count"])
		for i in count:
			var animal := RoamingAnimal.new()
			animal.name = "Safari_%s%d" % [species, i] if count > 1 \
				else "Safari_%s" % species
			animal.species = species
			animal.height = float(spec["h"])
			# ANIMALS holds local offsets; RoamingAnimal steers in world space.
			animal.home = global_position + spec["home"]
			animal.roam_radius = float(spec["roam"])
			animal.walk_speed = float(spec["speed"])
			animal.gait_hz = float(spec["gait"])
			animal.body_roll = float(spec["roll"])
			var pause: Vector2 = spec["pause"]
			animal.pause_min = pause.x
			animal.pause_max = pause.y

			# Spread a group out so a pride starts as three animals rather than
			# one animal wearing two others.
			var spread := Vector3.ZERO
			if count > 1:
				var a: float = TAU * float(i) / float(count)
				spread = Vector3(cos(a), 0, sin(a)) * 2.2
			animal.position = spec["home"] + spread + Vector3(0, 0.5, 0)
			animal.touched.connect(_on_touched)
			add_child(animal)
			_animals.append(animal)


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


## Count an animal the player is ALREADY standing beside when a round begins.
## body_entered only fires on a crossing; see the note in DinoValley.
func _claim_overlaps() -> void:
	await get_tree().physics_frame
	if _done:
		return
	var want := String(ROUNDS[_round]["answer"])
	for a in _animals:
		if a.species != want:
			continue
		for area in a.get_children():
			if area is Area3D:
				for body in (area as Area3D).get_overlapping_bodies():
					if body is Player:
						_on_touched(a)
						return


func _on_touched(animal: RoamingAnimal) -> void:
	# Meeting an animal always introduces it, question outstanding or not. The
	# naming is the part worth having; the quiz is a reason to go looking.
	_say(_names[animal.species])
	_call_of(animal)
	animal.cheer()

	if _done or _busy:
		return

	# Matched by SPECIES, so any lion in the pride answers "who has a mane".
	var want := String(ROUNDS[_round]["answer"])
	if animal.species == want:
		_busy = true
		answered.emit(true, animal.species)
		_next_round_soon()
	else:
		_wrong += 1
		answered.emit(false, animal.species)
		if _wrong >= HINT_AFTER:
			_hint(want)


## Nudge every animal that answers - for the lions that is the whole pride,
## which reads as the group calling the child over.
func _hint(want: String) -> void:
	for a in _animals:
		if a.species == want:
			a.stomp()
	for a in _animals:
		if a.species == want:
			_call_of(a)
			return


func _call_of(animal: RoamingAnimal) -> void:
	var clip: AudioStream = _calls.get(animal.species)
	if clip != null:
		_call.stream = clip
		_call.play()


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
	for a in _animals:
		a.cheer()


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
