extends SceneTree

## Drives the game with synthetic input and asserts that it actually plays.
##
## The screenshot test only proves the world builds. This proves the verbs
## work: that the stick moves you, that jump leaves the ground and comes back,
## that swapping swaps, that a sparkle can be collected, and that collecting
## enough opens the gate. Runs with no controller attached, so it is safe in CI.
##
##   Godot_console.exe --path rainbow-sparkle-squad -s tools/playtest.gd
##
## The schedule is in seconds, not frames. Headless runs idle frames as fast as
## the machine allows while physics stays pinned at 60 Hz, so a frame counter
## would fire the checks long before the character had finished moving.

var _root: Node
var _player: CharacterBody3D
var _clock := 0.0
var _done: Dictionary = {}
var _failures: Array[String] = []
var _checks := 0

var _start := Vector3.ZERO
var _max_height := 0.0
var _first_name := ""
var _picked_up := false


func _initialize() -> void:
	_root = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(_root)


func _process(delta: float) -> bool:
	# Adding the scene during _initialize does not run its _ready until the
	# first frame, so the world does not exist yet at that point.
	if _player == null:
		_player = _root.get_node_or_null("Player")
		if _player == null:
			_check(false, "Main.tscn builds a Player")
			return _finish()
		_start = _player.global_position
		_first_name = String(_player.get("character")["name"])
		return false

	_clock += delta

	if _clock < 1.0:
		Input.action_press("move_forward")
	elif _at(1.0):
		var travel := (_player.global_position - _start).normalized()
		var moved := _player.global_position.distance_to(_start)
		_check(moved > 2.0, "stick input moves the player (travelled %.2f m)" % moved)

		# The models face +Z and Models.MODEL_YAW turns them to match the node's
		# -Z, so the node's forward must track travel or the character moonwalks.
		var facing := -_player.global_transform.basis.z
		_check(facing.dot(travel) > 0.9,
			"character faces the way it is running (dot %.2f)" % facing.dot(travel))
		Input.action_release("move_forward")

	elif _at(1.4):
		_tap("jump")

	if _clock > 1.4:
		_max_height = maxf(_max_height, _player.global_position.y - _start.y)

	if _at(3.6):
		_check(_max_height > 1.0, "jump leaves the ground (peak %.2f m)" % _max_height)
		_check(_player.is_on_floor(), "and lands again")

	elif _at(3.9):
		_tap("swap")
	elif _at(4.2):
		var now := String(_player.get("character")["name"])
		_check(now != _first_name, "swap changes character (%s -> %s)" % [_first_name, now])
		_check(_player.get_node("Visual").get_child_count() == 1,
			"swap leaves exactly one model attached")
		_check_whole_cast()

	elif _at(4.5):
		var sparkle := _find_first("Sparkle")
		if sparkle == null:
			_check(false, "a sparkle exists to collect")
		else:
			sparkle.connect("collected", func(_s: Node) -> void: _picked_up = true)
			_player.global_position = (sparkle as Node3D).global_position
	elif _at(5.0):
		# The pickup despawns on a 0.25s tween, so counting nodes would still
		# see it here. Watch the signal instead.
		_check(_picked_up, "touching a sparkle collects it")

	elif _at(5.3):
		var gate := _root.get_node("Gate")
		gate.call("set_sparkles", 8)
		_check(gate.call("is_open"), "gate opens once the quota is met")

	elif _at(5.8):
		return _finish()

	return false


## True exactly once, on the first frame at or after `t` seconds.
func _at(t: float) -> bool:
	if _clock < t or _done.has(t):
		return false
	_done[t] = true
	return true


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


## One-frame press: held just long enough for `is_action_just_pressed` to see
## it, then released so it cannot retrigger.
func _tap(action: String) -> void:
	Input.action_press(action)
	get_root().get_tree().create_timer(0.05).timeout.connect(
		func() -> void: Input.action_release(action)
	)


## Swap all the way round the cast and prove every character actually arrives.
##
## Models.spawn PUSHES AN ERROR AND RETURNS AN EMPTY HOLDER when a model path is
## wrong, so a typo in Cast does not crash - it hands you an invisible player
## and a game that still runs. Counting meshes is what turns that into a
## failure. Going the whole way round also proves the swap wraps, which is the
## only thing that could break when a character is added.
func _check_whole_cast() -> void:
	var started_as := String(_player.get("character")["name"])
	var seen: Array[String] = []
	var bodiless: Array[String] = []
	var visual := _player.get_node("Visual")

	for _i in Cast.ALL.size():
		_player.swap_character()
		var who := String(_player.get("character")["name"])
		if not seen.has(who):
			seen.append(who)

		# Count meshes under the NEWLY ADDED model only, not under Visual.
		#
		# _apply_character frees the outgoing model with queue_free, which is
		# DEFERRED - it does not detach until the end of the frame. Swapping the
		# whole way round inside one frame therefore leaves every previous
		# model still parented, and a Visual-wide count happily reports meshes
		# that belong to a character we already swapped away from. The first
		# version of this check did exactly that and passed against a model path
		# pointing at a file that does not exist.
		var newest := visual.get_child(visual.get_child_count() - 1)
		if _mesh_count(newest) == 0:
			bodiless.append(who)

	_check(seen.size() == Cast.ALL.size(),
		"swapping cycles all %d characters (saw %s)" % [Cast.ALL.size(), ", ".join(seen)])
	_check(bodiless.is_empty(),
		"and every one of them has a model" if bodiless.is_empty()
			else "but these have NO model: %s" % ", ".join(bodiless))
	_check(String(_player.get("character")["name"]) == started_as,
		"and the swap wraps back round to %s" % started_as)


func _mesh_count(node: Node) -> int:
	var n := 0
	if node is MeshInstance3D:
		n += 1
	for child in node.get_children():
		n += _mesh_count(child)
	return n


func _find_first(script_name: String) -> Node:
	for child in _root.get_children():
		var script: Script = child.get_script()
		if script != null and script.resource_path.get_file().get_basename() == script_name:
			return child
	return null


func _finish() -> bool:
	print("")
	if _failures.is_empty():
		print("playtest: %d/%d checks passed" % [_checks, _checks])
	else:
		print("playtest: %d of %d FAILED" % [_failures.size(), _checks])
		for f in _failures:
			print("   - %s" % f)
	quit(0 if _failures.is_empty() else 1)
	return true
