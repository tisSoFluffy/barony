class_name ShapeCove
extends Node3D

## Shape Cove: a sand island ringed by water, where the six shapes live, and
## the find-the-shape game they are there for.
##
## Blockland teaches order - what number comes next. This teaches recognition -
## which one is the triangle - so the loop is deliberately different. There is
## no sequence to remember and no way to be "behind": a round names one shape,
## you go and touch it, and a wrong answer costs nothing but another go.
##
## It is built for a player who cannot read. The round is SPOKEN, and the text
## on screen is the backup rather than the other way round. Two wrong guesses
## and the right shape hops on the spot, so nobody can get stuck.

signal round_started(shape_name: String)
signal answered(correct: bool, shape_name: String)
signal completed

const SHAPES: Array[String] = [
	"circle", "square", "triangle", "rectangle", "star", "heart"]
const RADIUS := 9.0
const ROUNDS := 6
const HINT_AFTER := 2             # wrong guesses in a round before a nudge

const ISLAND_R := 15.0
const WATER_R := 34.0

var _figures: Array[ShapeFigure] = []
var _queue: Array[String] = []
var _target := ""
var _wrong := 0
var _score := 0
var _done := false
var _busy := false                # true between a correct answer and the next round
var _voice: AudioStreamPlayer

var _find_clips := {}
var _name_clips := {}
var _praise: AudioStream
var _retry: AudioStream


func _ready() -> void:
	_load_clips()
	_build_water()
	_build_island()
	_build_figures()
	_build_palms()

	_voice = AudioStreamPlayer.new()
	_voice.name = "ShapeVoice"
	_voice.volume_db = 2.0
	add_child(_voice)


func _load_clips() -> void:
	for s in SHAPES:
		_find_clips[s] = load("res://assets/audio/find_%s.wav" % s)
		_name_clips[s] = load("res://assets/audio/shape_%s.wav" % s)
	_praise = load("res://assets/audio/say_wellDone.wav")
	_retry = load("res://assets/audio/say_tryAgain.wav")


# -- the island ----------------------------------------------------------

func _build_water() -> void:
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = WATER_R
	disc.bottom_radius = WATER_R
	disc.height = 0.3
	disc.radial_segments = 64
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.62, 0.82, 0.86)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	mat.metallic = 0.0
	disc.material = mat
	mesh.mesh = disc
	# Surface must sit BELOW the island's top (y = 0) or the sea covers the
	# sand and the island simply is not there.
	mesh.position.y = -0.22
	add_child(mesh)


## The island proper: a shallow sand drum you can actually stand on. Its top is
## at y = 0 so everything else here shares the meadow's ground height.
func _build_island() -> void:
	var body := StaticBody3D.new()
	body.name = "CoveGround"

	var mesh := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = ISLAND_R
	drum.bottom_radius = ISLAND_R * 0.94
	drum.height = 1.2
	drum.radial_segments = 56
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#dfc48a")
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


## The six shapes in a fixed ring, evenly spaced and always in the same places.
## Deliberately NOT shuffled between rounds: at three, knowing where the star
## lives is a win worth keeping, and the puzzle is the name, not the memory.
func _build_figures() -> void:
	for i in SHAPES.size():
		var fig := ShapeFigure.new()
		fig.shape_name = SHAPES[i]
		fig.name = "Shape_%s" % SHAPES[i]

		var a: float = TAU * float(i) / float(SHAPES.size()) - PI * 0.5
		var pos := Vector3(cos(a) * RADIUS, 0.0, sin(a) * RADIUS)
		fig.position = pos
		fig.rotation.y = atan2(pos.x, pos.z)   # -Z is the face; aim it inward
		fig.touched.connect(_on_touched)
		add_child(fig)
		_figures.append(fig)


## A sparse fringe of trees right out on the rim. Kept small and few on
## purpose: they are a horizon, and anything that out-scales the shapes pulls
## the eye off the only things here that matter.
func _build_palms() -> void:
	for i in 6:
		var a: float = TAU * float(i) / 6.0 + 0.5
		var prop := Decor.new()
		prop.name = "CovePalm%d" % i
		prop.model_path = "res://assets/models/candy_tree.glb"
		prop.height = randf_range(2.6, 3.2)
		prop.yaw = randf() * TAU
		prop.sway = 0.02
		prop.position = Vector3(cos(a) * 13.4, 0.0, sin(a) * 13.4)
		add_child(prop)


# -- the game ------------------------------------------------------------

## Fresh game. Every shape is asked exactly once, in a shuffled order, so the
## round count is honest and nothing repeats.
func restart() -> void:
	_done = false
	_busy = false
	_score = 0
	_wrong = 0
	for f in _figures:
		f.set_lit(false)
	_queue = SHAPES.duplicate()
	_queue.shuffle()
	_next_round()


func _next_round() -> void:
	if _queue.is_empty():
		_finish()
		return
	_target = _queue.pop_front()
	_wrong = 0
	_busy = false
	round_started.emit(_target)
	_say(_find_clips[_target])


func _on_touched(fig: ShapeFigure) -> void:
	# Free play once the game is won: every shape just says its own name.
	if _done:
		_say(_name_clips[fig.shape_name])
		fig.cheer()
		return
	if _busy or _target == "":
		return

	if fig.shape_name == _target:
		_busy = true
		_score += 1
		fig.cheer()
		_say(_name_clips[fig.shape_name])
		answered.emit(true, fig.shape_name)
		_after_correct()
	else:
		fig.buzz()
		_wrong += 1
		_say(_retry)
		answered.emit(false, fig.shape_name)
		if _wrong >= HINT_AFTER:
			_hint()


## Nudge the right answer without lighting it - a hop is enough of a clue, and
## keeps the discovery with the player.
func _hint() -> void:
	for f in _figures:
		if f.shape_name == _target:
			f.hint()


func _after_correct() -> void:
	await get_tree().create_timer(1.35).timeout
	if not _done:
		_next_round()


func _finish() -> void:
	_done = true
	_target = ""
	completed.emit()
	_say(_praise)
	for f in _figures:
		f.cheer()


func _say(clip: AudioStream) -> void:
	if _voice == null or clip == null:
		return
	_voice.stream = clip
	_voice.play()


## Say the current round again - used when the player walks back in, and useful
## if the instruction was missed.
func repeat_prompt() -> void:
	if not _done and _target != "":
		_say(_find_clips[_target])


func target() -> String:
	return _target


func score() -> int:
	return _score


func is_complete() -> bool:
	return _done
