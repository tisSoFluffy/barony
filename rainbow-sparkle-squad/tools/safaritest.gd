extends SceneTree

## Proves the Safari Plains door, its inhabitants, and the "I spy" game.
##
##   Godot_console.exe --headless --path rainbow-sparkle-squad -s tools/safaritest.gd
##
## Steps wait on STATE, not on the clock - see the note in blocklandtest.gd.
##
## Two checks here exist because of bugs this project has already paid for:
## the animals must still be on their island after roaming (the local-vs-world
## `home` mix-up that would have emptied Dino Valley), and every question must
## have exactly one answering SPECIES - the pride means three lions answer
## "who has a mane", and matching by node instead of species would make two of
## them wrong.

const STEP_TIMEOUT := 30.0

var _root: Node
var _player: CharacterBody3D
var _safari: Node3D
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
	_safari = _root.get_node_or_null("SafariPlains")
	if _player == null or _safari == null:
		_check(false, "Main.tscn builds a Player and a SafariPlains")
		return _finish()

	_check(_root.get_node_or_null("DoorToSafari") != null, "there is a door to the Safari Plains")
	_check(_root.get_node_or_null("DoorFromSafari") != null, "and a door back to the meadow")

	var animals := _all()
	var expected := 0
	for s in SafariPlains.ANIMALS:
		expected += int(SafariPlains.ANIMALS[s]["count"])
	_check(animals.size() == expected,
		"the plains hold all %d animals" % expected)

	var lions := 0
	for a in animals:
		if a.species == "lion":
			lions += 1
	_check(lions >= 2, "the lions are a pride, not a loner (%d of them)" % lions)

	# The giraffe has to actually be the tallest thing out here, or "who has a
	# long neck" stops being answerable by looking.
	var tallest := ""
	var hi := -1.0
	for a in animals:
		if a.height > hi:
			hi = a.height
			tallest = a.species
	_check(tallest == "giraffe", "the giraffe really is the tallest (%s is)" % tallest)

	var species: Array[String] = []
	for a in animals:
		if not species.has(a.species):
			species.append(a.species)
	var answers: Array[String] = []
	var all_real := true
	var all_distinct := true
	for r in SafariPlains.ROUNDS:
		var ans := String(r["answer"])
		if not species.has(ans):
			all_real = false
		if answers.has(ans):
			all_distinct = false
		answers.append(ans)
	_check(all_real, "every question has an answer that lives here")
	_check(all_distinct, "and no two questions share an answer")
	_check(SafariPlains.ROUNDS.size() == species.size(),
		"every species is asked about exactly once")

	_safari.answered.connect(func(correct: bool, _s: String) -> void:
		if not correct:
			_wrong_seen = true)

	_steps = [
		{
			"what": "the door carries the player to the Safari Plains",
			"act": func() -> void:
				_player.global_position = _root.SAFARI_DOOR + Vector3(0, 1.0, 0),
			"ready": func() -> bool:
				return _player.global_position.distance_to(
					_root.ARRIVALS["safari"]) < 3.0,
		},
		{
			"what": "arriving asks the first question",
			"act": func() -> void: pass,
			"ready": func() -> bool: return _safari.question() != "",
		},
		{
			"what": "the wrong animal does not advance the round",
			"act": func() -> void: _touch_wrong(),
			"ready": func() -> bool:
				return _wrong_seen and _safari.round_index() == 0,
		},
		{
			"what": "the right animal advances it",
			"act": func() -> void: _touch(_answer()),
			"ready": func() -> bool: return _safari.round_index() >= 1,
		},
		{
			# The layout table holds LOCAL offsets while RoamingAnimal steers in
			# world space; getting that wrong once sent a whole biome walking
			# towards the meadow. Let them roam, then check they are still here.
			"what": "after roaming freely they are all still on the plains",
			"act": func() -> void: pass,
			"ready": func() -> bool:
				if _elapsed < 6.0:
					return false
				for a in _all():
					var off: Vector3 = a.global_position - _safari.global_position
					if Vector2(off.x, off.z).length() > SafariPlains.GROUND_R:
						return false
				return true,
		},
		{
			"what": "and the whole I-spy game can be played through",
			"act": func() -> void: pass,
			"ready": func() -> bool:
				if _safari.is_complete():
					return true
				_touch(_answer())
				return false,
		},
	]
	return false


func _answer() -> String:
	var i: int = _safari.round_index()
	if i >= SafariPlains.ROUNDS.size():
		return ""
	return String(SafariPlains.ROUNDS[i]["answer"])


func _touch(species: String) -> void:
	if species == "":
		return
	for a in _all():
		if a.species == species:
			_player.velocity = Vector3.ZERO
			_player.global_position = a.global_position + Vector3(0, 0.5, 0)
			return


func _touch_wrong() -> void:
	var want := _answer()
	for a in _all():
		if a.species != want:
			_player.velocity = Vector3.ZERO
			_player.global_position = a.global_position + Vector3(0, 0.5, 0)
			return


func _all() -> Array:
	var out: Array = []
	for c in _safari.get_children():
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
		print("safaritest: %d/%d checks passed" % [_checks, _checks])
	else:
		print("safaritest: %d of %d FAILED" % [_failures.size(), _checks])
		for f in _failures:
			print("   - %s" % f)
	quit(0 if _failures.is_empty() else 1)
	return true
