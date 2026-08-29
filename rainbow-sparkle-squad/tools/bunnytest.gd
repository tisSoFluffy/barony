extends SceneTree

## Proves Ms. Bumbleflower is actually alive.
##
## playtest.gd covers the verbs the player has; this covers the one character
## who acts on her own. It watches her for a few seconds of undisturbed
## wandering, then teleports the player on top of her and checks she bolts.
##
##   Godot_console.exe --headless --path rainbow-sparkle-squad -s tools/bunnytest.gd
##
## Timed in seconds, not frames: headless runs idle frames as fast as the
## machine allows while physics stays pinned at 60 Hz.

const WANDER_UNTIL := 6.0
const FLEE_UNTIL := 8.5

var _root: Node
var _bunny: CharacterBody3D
var _player: CharacterBody3D
var _clock := 0.0
var _start := Vector3.ZERO
var _peak := 0.0
var _hops := 0
var _airborne := false
var _flee_from := Vector3.ZERO
var _phase := 0
var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_root = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(_root)


func _process(delta: float) -> bool:
	# Adding the scene during _initialize does not run its _ready until the
	# first frame, so the world does not exist yet at that point.
	if _bunny == null:
		_bunny = _root.get_node_or_null("Bunny")
		_player = _root.get_node_or_null("Player")
		if _bunny == null:
			_check(false, "Main.tscn builds a Bunny")
			return _finish()
		_start = _bunny.global_position
		# Park the player far away so the first phase is pure wandering.
		_player.global_position = Vector3(0, 1.2, 20)
		return false

	_clock += delta

	# Count a hop on each ground -> air transition.
	var up := not _bunny.is_on_floor()
	if up and not _airborne:
		_hops += 1
	_airborne = up
	_peak = maxf(_peak, _bunny.global_position.y)

	if _phase == 0 and _clock > WANDER_UNTIL:
		_check(_hops >= 3, "she hops unprompted (%d hops in %.0fs)" % [_hops, WANDER_UNTIL])
		_check(_peak > 0.35, "a hop leaves the ground (peak %.2f m)" % _peak)
		var moved := _bunny.global_position.distance_to(_start)
		_check(moved > 2.0, "she wanders away from where she started (%.1f m)" % moved)

		var here := Vector2(_bunny.global_position.x, _bunny.global_position.z)
		var centre := Vector2(Bunny.ROAM_CENTRE.x, Bunny.ROAM_CENTRE.z)
		var r := here.distance_to(centre)
		_check(r <= Bunny.ROAM_RADIUS + 1.0,
			"and stays inside the roam disc (r %.1f of %.0f)" % [r, Bunny.ROAM_RADIUS])

		# Now crowd her and check she bolts.
		_player.global_position = _bunny.global_position + Vector3(0.9, 0.0, 0.0)
		_flee_from = _bunny.global_position
		_phase = 1

	elif _phase == 1 and _clock > FLEE_UNTIL:
		var away := _bunny.global_position.distance_to(_flee_from)
		_check(away > 1.5, "she spooks and bounds away from the player (%.1f m)" % away)
		return _finish()

	return false


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _finish() -> bool:
	print("")
	if _failures.is_empty():
		print("bunnytest: %d/%d checks passed" % [_checks, _checks])
	else:
		print("bunnytest: %d of %d FAILED" % [_failures.size(), _checks])
		for f in _failures:
			print("   - %s" % f)
	quit(0 if _failures.is_empty() else 1)
	return true
