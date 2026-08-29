class_name LetterLagoon
extends Node3D

## Letter Lagoon: ten letters standing round a lagoon, and a word-building game.
##
## The ten are not A to J. They are Letters and Sounds Phase 2 Set 1 -
## s a t p i n - plus just enough more (m d g o) to spell real words. Teaching
## the alphabet in alphabetical order is the one thing phonics does not do,
## because you cannot build a word out of a, b, c. You can build six out of
## these.
##
## The game is blending, which is the actual skill: a word is named, and you
## walk to its letters in order, hearing each sound as you collect it. That
## makes it a cousin of Blockland's touch-in-order rather than of Shape Cove's
## find-the-one - three islands, three different things being learned.

signal word_started(word: String)
signal letter_found(word: String, index: int)
signal wrong_letter(expected: String, got: String)
signal completed

## Six words, each spelled from LETTERS with no letter used twice - a repeat
## would need one figure touched twice in a round, which the lighting cannot
## express.
const WORDS: Array[String] = ["pig", "dog", "sat", "map", "tin", "pot"]
const LETTERS: Array[String] = ["s", "a", "t", "p", "i", "n", "m", "d", "g", "o"]

const RADIUS := 9.5
const ISLAND_R := 17.0
const WATER_R := 38.0
const HINT_AFTER := 2

var _figures: Array[LetterFigure] = []
var _queue: Array[String] = []
var _word := ""
var _index := 0
var _wrong := 0
var _solved := 0
var _done := false
var _busy := false
var _voice: AudioStreamPlayer

var _snd := {}
var _key := {}
var _spell := {}
var _said := {}
var _praise: AudioStream
var _retry: AudioStream


func _ready() -> void:
	_load_clips()
	_build_water()
	_build_island()
	_build_letters()
	_build_palms()

	_voice = AudioStreamPlayer.new()
	_voice.name = "LetterVoice"
	_voice.volume_db = 2.0
	add_child(_voice)


func _load_clips() -> void:
	for l in LETTERS:
		_snd[l] = load("res://assets/audio/snd_%s.wav" % l)
		_key[l] = load("res://assets/audio/key_%s.wav" % l)
	for w in WORDS:
		_spell[w] = load("res://assets/audio/spell_%s.wav" % w)
		_said[w] = load("res://assets/audio/said_%s.wav" % w)
	_praise = load("res://assets/audio/say_wellDone.wav")
	_retry = load("res://assets/audio/say_tryAgain.wav")


# -- the lagoon ----------------------------------------------------------

func _build_water() -> void:
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = WATER_R
	disc.bottom_radius = WATER_R
	disc.height = 0.3
	disc.radial_segments = 64
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.68, 0.72, 0.86)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	disc.material = mat
	mesh.mesh = disc
	# Below the island's top (y = 0), or the water hides the ground.
	mesh.position.y = -0.22
	add_child(mesh)


func _build_island() -> void:
	var body := StaticBody3D.new()
	body.name = "LagoonGround"

	var mesh := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = ISLAND_R
	drum.bottom_radius = ISLAND_R * 0.94
	drum.height = 1.2
	drum.radial_segments = 56
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#cbbf96")
	mat.roughness = 0.95
	drum.material = mat
	mesh.mesh = drum
	mesh.position.y = -0.6
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = ISLAND_R
	shape.height = 1.2
	col.shape = shape
	col.position.y = -0.6
	body.add_child(col)
	add_child(body)


## Ten letters in a fixed ring, in the order they are taught rather than
## alphabetically, and never shuffled - the same reasoning as Shape Cove, only
## more so. Knowing where s lives is a foothold, and a child who has to
## re-find every letter every round never gets to the blending.
func _build_letters() -> void:
	for i in LETTERS.size():
		var fig := LetterFigure.new()
		fig.letter = LETTERS[i]
		fig.name = "Letter_%s" % LETTERS[i]

		var a: float = TAU * float(i) / float(LETTERS.size()) - PI * 0.5
		var pos := Vector3(cos(a) * RADIUS, 0.0, sin(a) * RADIUS)
		fig.position = pos
		fig.rotation.y = atan2(pos.x, pos.z)   # -Z is the face; aim it inward
		fig.touched.connect(_on_touched)
		add_child(fig)
		_figures.append(fig)


func _build_palms() -> void:
	for i in 7:
		var a: float = TAU * float(i) / 7.0 + 0.3
		var prop := Decor.new()
		prop.name = "LagoonPalm%d" % i
		prop.model_path = "res://assets/models/candy_tree.glb"
		prop.height = randf_range(2.6, 3.2)
		prop.yaw = randf() * TAU
		prop.sway = 0.02
		prop.position = Vector3(cos(a) * 15.4, 0.0, sin(a) * 15.4)
		add_child(prop)


# -- the game ------------------------------------------------------------

func restart() -> void:
	_done = false
	_busy = false
	_solved = 0
	for f in _figures:
		f.set_lit(false)
	_queue = WORDS.duplicate()
	_queue.shuffle()
	_next_word()


func _next_word() -> void:
	if _queue.is_empty():
		_finish()
		return
	_word = _queue.pop_front()
	_index = 0
	_wrong = 0
	_busy = false
	for f in _figures:
		f.set_lit(false)
	word_started.emit(_word)
	_say(_spell[_word])
	_claim_overlaps()


## Count a letter the player is ALREADY standing inside when a word begins.
##
## Area3D only fires body_entered on a crossing, and a new word can easily want
## the letter you are standing on - finish "sat" on the t and "tin" wants t
## first. Without this the game waits for an entry event that can never come and
## simply stops, with no way out but walking off the letter and back on. Every
## round boundary needs this, not just the first.
func _claim_overlaps() -> void:
	await get_tree().physics_frame
	if _done or _word == "":
		return
	for f in _figures:
		for body in f.get_overlapping_bodies():
			if body is Player:
				_on_touched(f)
				return


func _on_touched(fig: LetterFigure) -> void:
	# Free play once the game is won: every letter teaches itself.
	if _done:
		_say(_key[fig.letter])
		fig.cheer()
		return
	if _busy or _word == "":
		return

	var want := _word[_index]
	if fig.letter == want:
		fig.cheer()
		_say(_snd[fig.letter])
		_index += 1
		letter_found.emit(_word, _index)
		if _index >= _word.length():
			_busy = true
			_finish_word()
	else:
		fig.buzz()
		_wrong += 1
		_say(_retry)
		wrong_letter.emit(want, fig.letter)
		if _wrong >= HINT_AFTER:
			_hint(want)


func _hint(want: String) -> void:
	for f in _figures:
		if f.letter == want:
			f.hint()


## Let the last letter's sound land, then say the whole word - the moment the
## sounds become a word is the entire point of blending, so it gets its own beat.
func _finish_word() -> void:
	_solved += 1
	await get_tree().create_timer(0.55).timeout
	_say(_said[_word])
	await get_tree().create_timer(1.5).timeout
	if not _done:
		_next_word()


func _finish() -> void:
	_done = true
	_word = ""
	completed.emit()
	_say(_praise)
	for f in _figures:
		f.cheer()


func _say(clip: AudioStream) -> void:
	if _voice == null or clip == null:
		return
	_voice.stream = clip
	_voice.play()


func repeat_prompt() -> void:
	if not _done and _word != "":
		_say(_spell[_word])


## The word so far, with the letters still to find shown as dots: "pi*".
func progress_text() -> String:
	if _word == "":
		return ""
	var out := ""
	for i in _word.length():
		out += _word[i].to_upper() if i < _index else "_"
		out += " "
	return out.strip_edges()


func word() -> String:
	return _word


func solved() -> int:
	return _solved


func is_complete() -> bool:
	return _done
