extends SceneTree

## Proves Shape Cove's door, its geometry, and that the find-the-shape game
## judges answers and can be finished.
##
##   Godot_console.exe --headless --path rainbow-sparkle-squad -s tools/shapecovetest.gd
##
## Steps wait on STATE, not on the clock - see the note in blocklandtest.gd.
## The geometry checks matter more here than they look: these shapes are what
## the game is teaching, so a triangle with the wrong number of sides, or a
## figure sunk into the sand, is a wrong lesson rather than a cosmetic bug.

## Generous on purpose: a full play-through is six rounds, and each one waits a
## real beat after a correct answer so the spoken name finishes before the next
## instruction starts. That pacing is a feature, so the test has to out-wait it.
const STEP_TIMEOUT := 25.0

var _root: Node
var _player: CharacterBody3D
var _cove: Node3D
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
	_cove = _root.get_node_or_null("ShapeCove")
	if _player == null or _cove == null:
		_check(false, "Main.tscn builds a Player and a ShapeCove")
		return _finish()

	_check(_root.get_node_or_null("DoorToCove") != null, "there is a door to Shape Cove")
	_check(_root.get_node_or_null("DoorFromCove") != null, "and a door back to the meadow")

	var figs := _figures()
	_check(figs.size() == ShapeCove.SHAPES.size(),
		"the cove has all %d shapes" % ShapeCove.SHAPES.size())

	# Every shape must be solid, the right way up, and standing ON the sand -
	# a figure sunk into the ground reads as the wrong shape entirely.
	var geometry_ok := true
	var grounded_ok := true
	for f in figs:
		var mi: MeshInstance3D = null
		for c in f.get_node("Visual").get_children():
			if c is MeshInstance3D and c.mesh is ArrayMesh:
				mi = c
				break
		if mi == null or mi.mesh.get_surface_count() == 0:
			geometry_ok = false
			continue
		var aabb: AABB = mi.mesh.get_aabb()
		# Extruded from a 2D outline, so it must have real width, height and
		# a slab depth - never a degenerate sliver.
		if aabb.size.x < 0.2 or aabb.size.y < 0.2 or aabb.size.z < 0.05:
			geometry_ok = false
		if absf(aabb.position.y) > 0.02:
			grounded_ok = false
	_check(geometry_ok, "every shape extruded into solid geometry")
	_check(grounded_ok, "and stands on the sand rather than sunk into it")

	_cove.answered.connect(func(correct: bool, _n: String) -> void:
		if not correct:
			_wrong_seen = true)

	_steps = [
		{
			"what": "the door carries the player to Shape Cove",
			"act": func() -> void:
				_player.global_position = _root.COVE_DOOR + Vector3(0, 1.0, 0),
			"ready": func() -> bool:
				return _player.global_position.distance_to(
					_root.ARRIVALS["cove"]) < 3.0,
		},
		{
			"what": "arriving starts a round and names a shape to find",
			"act": func() -> void: pass,
			"ready": func() -> bool: return _cove.target() != "",
		},
		{
			"what": "touching the wrong shape does not score",
			"act": func() -> void: _touch_wrong(),
			"ready": func() -> bool: return _wrong_seen and _cove.score() == 0,
		},
		{
			"what": "touching the named shape scores it",
			"act": func() -> void: _touch(_cove.target()),
			"ready": func() -> bool: return _cove.score() == 1,
		},
		{
			"what": "and the game can be played through to the end",
			# Answer each round as it is asked until every shape is done.
			"act": func() -> void: pass,
			"ready": func() -> bool:
				if _cove.is_complete():
					return true
				var t: String = _cove.target()
				if t != "":
					_touch(t)
				return false,
		},
		{
			"what": "finishing scores every shape exactly once",
			"act": func() -> void: pass,
			"ready": func() -> bool:
				return _cove.score() == ShapeCove.SHAPES.size(),
		},
	]
	return false


func _touch(shape_name: String) -> void:
	for f in _figures():
		if f.shape_name == shape_name:
			_player.velocity = Vector3.ZERO
			_player.global_position = f.global_position + Vector3(0, 0.6, 0)
			return


## Any shape that is NOT the current answer.
func _touch_wrong() -> void:
	for f in _figures():
		if f.shape_name != _cove.target():
			_player.velocity = Vector3.ZERO
			_player.global_position = f.global_position + Vector3(0, 0.6, 0)
			return


func _figures() -> Array:
	var out: Array = []
	for c in _cove.get_children():
		if c is ShapeFigure:
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
		print("shapecovetest: %d/%d checks passed" % [_checks, _checks])
	else:
		print("shapecovetest: %d of %d FAILED" % [_failures.size(), _checks])
		for f in _failures:
			print("   - %s" % f)
	quit(0 if _failures.is_empty() else 1)
	return true
