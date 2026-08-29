extends SceneTree

## Proves the doorway works and the counting game actually judges answers.
##
## The interesting failures here are quiet ones: a door that fires twice and
## ping-pongs the player, a puzzle that accepts any block, or one that never
## resets after a mistake. So this walks the player through the door, counts
## correctly for a couple of blocks, deliberately gets one wrong, and checks
## the row goes out again.
##
##   Godot_console.exe --headless --path rainbow-sparkle-squad -s tools/blocklandtest.gd
##
## Steps wait on STATE, not on the clock. A touch registers on the next physics
## frame while these steps run on idle frames, and headless runs idle frames as
## fast as the machine allows - so a fixed delay between steps is a race, and
## was one. Each step polls its own condition and only fails on a deadline.

const STEP_TIMEOUT := 3.0

var _root: Node
var _player: CharacterBody3D
var _land: Node3D
var _steps: Array = []
var _at := 0
var _elapsed := 0.0
var _entered := false
var _failures: Array[String] = []
var _checks := 0


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
		var act: Callable = step["act"]
		act.call()

	_elapsed += delta
	var ready: Callable = step["ready"]
	if ready.call():
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
	_land = _root.get_node_or_null("Blockland")
	if _player == null or _land == null:
		_check(false, "Main.tscn builds a Player and a Blockland")
		return _finish()

	_check(_root.get_node_or_null("DoorToBlockland") != null,
		"there is a door in the meadow")
	_check(_root.get_node_or_null("DoorFromBlockland") != null,
		"and a door back from Blockland")
	_check(_blocks().size() == 10, "Blockland has ten Numberblocks")

	var shapes_ok := true
	for b in _blocks():
		# The shape is the maths: N really is built from N cubes.
		var grid: Vector2i = Numberblock.SHAPES[b.number]
		if grid.x * grid.y != b.number:
			shapes_ok = false
	_check(shapes_ok, "every block is built from exactly its own number of cubes")

	_steps = [
		{
			"what": "the door carries the player to Blockland",
			"act": func() -> void:
				_player.global_position = _root.MEADOW_DOOR + Vector3(0, 1.0, 0),
			"ready": func() -> bool:
				return _player.global_position.distance_to(
					_root.ARRIVALS["blockland"]) < 3.0,
		},
		{
			"what": "and does not bounce them straight back",
			"act": func() -> void: pass,
			# Give the return door every chance to misfire before believing it.
			"ready": func() -> bool:
				return _elapsed > 1.6 and _player.global_position.z > 100.0,
		},
		{
			"what": "touching 1 first advances the count",
			"act": func() -> void: _touch(1),
			"ready": func() -> bool: return _land.next_number() == 2,
		},
		{
			"what": "then 2",
			"act": func() -> void: _touch(2),
			"ready": func() -> bool: return _land.next_number() == 3,
		},
		{
			"what": "a wrong block resets the count to 1",
			"act": func() -> void: _touch(9),
			"ready": func() -> bool: return _land.next_number() == 1,
		},
		{
			"what": "and puts every block out again",
			"act": func() -> void: pass,
			"ready": func() -> bool:
				for b in _blocks():
					if b.is_lit():
						return false
				return true,
		},
	]
	return false


## Drop the player onto a block so its Area3D fires, the way walking into it
## would. Lifted clear of the ground so the landing is a real crossing.
func _touch(n: int) -> void:
	for b in _blocks():
		if b.number == n:
			_player.velocity = Vector3.ZERO
			_player.global_position = b.global_position + Vector3(0, 0.6, 0)
			return


func _blocks() -> Array:
	var out: Array = []
	for c in _land.get_children():
		if c is Numberblock:
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
		print("blocklandtest: %d/%d checks passed" % [_checks, _checks])
	else:
		print("blocklandtest: %d of %d FAILED" % [_failures.size(), _checks])
		for f in _failures:
			print("   - %s" % f)
	quit(0 if _failures.is_empty() else 1)
	return true
