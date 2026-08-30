extends SceneTree

## Proves Dino Valley's door, its inhabitants, and that the size game works.
##
##   Godot_console.exe --headless --path rainbow-sparkle-squad -s tools/dinovalleytest.gd
##
## Steps wait on STATE, not on the clock - see the note in blocklandtest.gd.
##
## The data checks are the ones that matter most here, because this island's
## questions are claims about the models. "Find the biggest" is only answerable
## if the T-rex really is the tallest thing in the valley; if someone retunes a
## height later and breaks that ordering, the game starts teaching a lie and
## nothing else would catch it.

const STEP_TIMEOUT := 30.0

var _root: Node
var _player: CharacterBody3D
var _valley: Node3D
var _steps: Array = []
var _at := 0
var _elapsed := 0.0
var _entered := false
var _failures: Array[String] = []
var _checks := 0
var _wrong_seen := false
var _named: Array[String] = []


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
	_valley = _root.get_node_or_null("DinoValley")
	if _player == null or _valley == null:
		_check(false, "Main.tscn builds a Player and a DinoValley")
		return _finish()

	_check(_root.get_node_or_null("DoorToValley") != null, "there is a door to Dino Valley")
	_check(_root.get_node_or_null("DoorFromValley") != null, "and a door back to the meadow")

	var dinos := _dinos()
	_check(dinos.size() == 4, "the valley has four dinosaurs")

	var flyers := 0
	var walkers := 0
	for d in dinos:
		if d.mode == RoamingAnimal.Mode.FLYER:
			flyers += 1
		else:
			walkers += 1
	_check(flyers == 1 and walkers == 3, "three walk and one flies")

	# The questions are claims about the models - hold them to it.
	var tallest := ""
	var shortest := ""
	var hi := -1.0
	var lo := 999.0
	for d in dinos:
		if d.height > hi:
			hi = d.height
			tallest = d.species
		if d.height < lo:
			lo = d.height
			shortest = d.species
	_check(tallest == "trex", "the T-rex really is the tallest (%s is)" % tallest)
	_check(shortest == "triceratops",
		"the Triceratops really is the shortest (%s is)" % shortest)

	var species: Array[String] = []
	for d in dinos:
		species.append(d.species)
	var answers: Array[String] = []
	var all_real := true
	var all_distinct := true
	for r in DinoValley.ROUNDS:
		var a := String(r["answer"])
		if not species.has(a):
			all_real = false
		if answers.has(a):
			all_distinct = false
		answers.append(a)
	_check(all_real, "every question has an answer that lives here")
	_check(all_distinct, "and no two questions share an answer")

	_valley.answered.connect(func(correct: bool, s: String) -> void:
		if not correct:
			_wrong_seen = true
		if not _named.has(s):
			_named.append(s))

	_steps = [
		{
			"what": "the door carries the player to Dino Valley",
			"act": func() -> void:
				_player.global_position = _root.VALLEY_DOOR + Vector3(0, 1.0, 0),
			"ready": func() -> bool:
				return _player.global_position.distance_to(
					_root.ARRIVALS["valley"]) < 3.0,
		},
		{
			"what": "arriving asks the first question",
			"act": func() -> void: pass,
			"ready": func() -> bool: return _valley.question() != "",
		},
		{
			"what": "the wrong dinosaur does not advance the round",
			"act": func() -> void: _touch_wrong(),
			"ready": func() -> bool:
				return _wrong_seen and _valley.round_index() == 0,
		},
		{
			"what": "the right dinosaur advances it",
			"act": func() -> void: _touch(_answer()),
			"ready": func() -> bool: return _valley.round_index() >= 1,
		},
		{
			# The layout table holds LOCAL offsets but the dinosaurs steer in
			# world space, and getting that conversion wrong sent all four of
			# them walking towards the meadow two hundred metres away. Nothing
			# else notices until a child arrives to an empty valley, so let them
			# roam a while and then check they are still on their island.
			"what": "after roaming freely they are all still in the valley",
			"act": func() -> void: pass,
			"ready": func() -> bool:
				if _elapsed < 6.0:
					return false
				for d in _dinos():
					var off: Vector3 = d.global_position - _valley.global_position
					if Vector2(off.x, off.z).length() > DinoValley.GROUND_R:
						return false
				return true,
		},
		{
			"what": "and the whole quiz can be played through",
			# Chase down whichever dinosaur answers the current question. They
			# are moving targets, so re-aim every frame.
			"act": func() -> void: pass,
			"ready": func() -> bool:
				if _valley.is_complete():
					return true
				_touch(_answer())
				return false,
		},
	]
	return false


func _answer() -> String:
	var i: int = _valley.round_index()
	if i >= DinoValley.ROUNDS.size():
		return ""
	return String(DinoValley.ROUNDS[i]["answer"])


func _touch(species: String) -> void:
	if species == "":
		return
	for d in _dinos():
		if d.species == species:
			_player.velocity = Vector3.ZERO
			_player.global_position = d.global_position + Vector3(0, 0.5, 0)
			return


func _touch_wrong() -> void:
	var want := _answer()
	for d in _dinos():
		if d.species != want:
			_player.velocity = Vector3.ZERO
			_player.global_position = d.global_position + Vector3(0, 0.5, 0)
			return


func _dinos() -> Array:
	var out: Array = []
	for c in _valley.get_children():
		if c is RoamingAnimal:
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
		print("dinovalleytest: %d/%d checks passed" % [_checks, _checks])
	else:
		print("dinovalleytest: %d of %d FAILED" % [_failures.size(), _checks])
		for f in _failures:
			print("   - %s" % f)
	quit(0 if _failures.is_empty() else 1)
	return true
