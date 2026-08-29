extends SceneTree

## Proves Letter Lagoon's door, its letters, and that the word game blends.
##
##   Godot_console.exe --headless --path rainbow-sparkle-squad -s tools/letterlagoontest.gd
##
## Steps wait on STATE, not on the clock - see the note in blocklandtest.gd.
##
## The data checks at the top are the ones that would otherwise rot silently.
## Every word has to be spellable from the letters actually standing in the
## lagoon, and no word may use a letter twice, because a repeat would need one
## figure touched twice in a round and the lighting cannot express that. Adding
## a word later without checking is exactly how that breaks.

const STEP_TIMEOUT := 30.0

var _root: Node
var _player: CharacterBody3D
var _lagoon: Node3D
var _steps: Array = []
var _at := 0
var _elapsed := 0.0
var _entered := false
var _failures: Array[String] = []
var _checks := 0
var _wrong_seen := false


func _initialize() -> void:
	_root = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(_root)


func _process(delta: float) -> bool:
	if _player == null:
		return _setup()
	if _at >= _steps.size():
		return _finish()

	var step: Dictionary = _steps[_at]
	if not _entered:
		_entered = true
		_elapsed = 0.0
		(step["act"] as Callable).call()

	_elapsed += delta
	if (step["ready"] as Callable).call():
		_check(true, step["what"])
		_advance()
	elif _elapsed > STEP_TIMEOUT:
		_check(false, "%s (timed out after %.0fs)" % [step["what"], STEP_TIMEOUT])
		_advance()
	return false


func _advance() -> void:
	_at += 1
	_entered = false


func _setup() -> bool:
	_player = _root.get_node_or_null("Player")
	_lagoon = _root.get_node_or_null("LetterLagoon")
	if _player == null or _lagoon == null:
		_check(false, "Main.tscn builds a Player and a LetterLagoon")
		return _finish()

	_check(_root.get_node_or_null("DoorToLagoon") != null, "there is a door to Letter Lagoon")
	_check(_root.get_node_or_null("DoorFromLagoon") != null, "and a door back to the meadow")

	var figs := _figures()
	_check(figs.size() == LetterLagoon.LETTERS.size(),
		"the lagoon has all %d letters" % LetterLagoon.LETTERS.size())

	# Every word must be spellable from the letters that are actually here.
	var spellable := true
	var no_repeats := true
	for w in LetterLagoon.WORDS:
		var seen: Array[String] = []
		for i in w.length():
			var ch: String = w[i]
			if not LetterLagoon.LETTERS.has(ch):
				spellable = false
			if seen.has(ch):
				no_repeats = false
			seen.append(ch)
	_check(spellable, "every word is spellable from the letters standing here")
	_check(no_repeats, "and no word needs the same letter twice")

	# Letters are real extruded glyphs standing on the ground, not flat sprites.
	var glyphs_ok := true
	var grounded_ok := true
	for f in figs:
		var mi: MeshInstance3D = null
		for c in f.get_node("Visual").get_children():
			if c is MeshInstance3D and c.mesh is TextMesh:
				mi = c
				break
		if mi == null:
			glyphs_ok = false
			continue
		var aabb: AABB = mi.mesh.get_aabb()
		if aabb.size.z < 0.05 or aabb.size.y < 0.1:
			glyphs_ok = false
		# Stood on the ground by measuring the glyph, so the base must land at 0.
		var base: float = mi.position.y + aabb.position.y * mi.scale.y
		if absf(base) > 0.02:
			grounded_ok = false
	_check(glyphs_ok, "every letter is a solid extruded glyph")
	_check(grounded_ok, "and every letter stands on the sand at the same height")

	_lagoon.wrong_letter.connect(func(_e: String, _g: String) -> void: _wrong_seen = true)

	_steps = [
		{
			"what": "the door carries the player to Letter Lagoon",
			"act": func() -> void:
				_player.global_position = _root.LAGOON_DOOR + Vector3(0, 1.0, 0),
			"ready": func() -> bool:
				return _player.global_position.distance_to(
					_root.ARRIVALS["lagoon"]) < 3.0,
		},
		{
			"what": "arriving starts a word to spell",
			"act": func() -> void: pass,
			"ready": func() -> bool: return _lagoon.word() != "",
		},
		{
			"what": "a wrong letter does not advance the word",
			"act": func() -> void: _touch_wrong(),
			"ready": func() -> bool:
				return _wrong_seen and _lagoon.progress_text().begins_with("_"),
		},
		{
			"what": "the right letter fills the first blank",
			"act": func() -> void: _touch(_lagoon.word()[0]),
			"ready": func() -> bool:
				return not _lagoon.progress_text().begins_with("_"),
		},
		{
			"what": "and every word can be spelled through to the end",
			# Answer whatever letter the current word wants next, round after
			# round, until the whole set is done.
			"act": func() -> void: pass,
			"ready": func() -> bool:
				if _lagoon.is_complete():
					return true
				var w: String = _lagoon.word()
				if w != "":
					var i := _next_index(w)
					if i >= 0:
						_touch(w[i])
				return false,
		},
		{
			"what": "finishing solves every word exactly once",
			"act": func() -> void: pass,
			"ready": func() -> bool:
				return _lagoon.solved() == LetterLagoon.WORDS.size(),
		},
	]
	return false


## How many letters of the current word are already filled in, read off the
## progress text so the test does not reach into private state.
func _next_index(w: String) -> int:
	var text: String = _lagoon.progress_text().replace(" ", "")
	for i in text.length():
		if text[i] == "_":
			return i
	return -1


func _touch(letter: String) -> void:
	for f in _figures():
		if f.letter == letter:
			_player.velocity = Vector3.ZERO
			_player.global_position = f.global_position + Vector3(0, 0.6, 0)
			return


## Any letter that is not the one the word wants next.
func _touch_wrong() -> void:
	var want: String = _lagoon.word()[0]
	for f in _figures():
		if f.letter != want:
			_player.velocity = Vector3.ZERO
			_player.global_position = f.global_position + Vector3(0, 0.6, 0)
			return


func _figures() -> Array:
	var out: Array = []
	for c in _lagoon.get_children():
		if c is LetterFigure:
			out.append(c)
	return out


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _finish() -> bool:
	print("")
	if _failures.is_empty():
		print("letterlagoontest: %d/%d checks passed" % [_checks, _checks])
	else:
		print("letterlagoontest: %d of %d FAILED" % [_failures.size(), _checks])
		for f in _failures:
			print("   - %s" % f)
	quit(0 if _failures.is_empty() else 1)
	return true
