extends SceneTree

## Proves the Haunted House door, its five ghosts, and the feelings game.
##
##   Godot_console.exe --headless --path rainbow-sparkle-squad -s tools/hauntedhousetest.gd
##
## Steps wait on STATE, not on the clock - see the note in blocklandtest.gd.
##
## The checks that matter here are the ones holding the island to the claim its
## questions make. "Who looks sad?" is only answerable by looking at a face if
## the face is the ONLY thing that differs, so this suite asserts that directly:
## every ghost the same height, every tint different from every other but all of
## them within a hair of each other, so a child cannot sort five ghosts by size
## or by colour and never look up at all. Get that wrong and every test about
## the game loop still passes while the island quietly teaches nothing.
##
## It also tests trap 1 head-on rather than hoping. The ghosts FLOAT, so a
## player can drift to a stop inside one without meaning to; if a round then
## begins whose answer is the ghost they are already in, `body_entered` has no
## crossing to fire on and the island deadlocks. The "already standing in the
## answer" step parks the player and reshuffles until that exact case comes up.

const STEP_TIMEOUT := 30.0
## How close two ghost tints may be and still count as "cannot be sorted by
## colour". The five sit at about 0.10 apart; 0.15 leaves room to retune them
## without silently letting colour become the answer.
const TINT_SPREAD_MAX := 0.15

var _root: Node
var _player: CharacterBody3D
var _house: Node3D
var _steps: Array = []
var _at := 0
var _elapsed := 0.0
var _entered := false
var _failures: Array[String] = []
var _checks := 0
var _wrong_seen := false
var _parked := ""
var _retry_at := 0.0


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
	_house = _root.get_node_or_null("HauntedHouse")
	if _player == null or _house == null:
		_check(false, "Main.tscn builds a Player and a HauntedHouse")
		return _finish()

	_check(_root.get_node_or_null("DoorToHauntedHouse") != null,
		"there is a door to the Haunted House")
	_check(_root.get_node_or_null("DoorFromHauntedHouse") != null,
		"and a door back to the meadow")

	var ghosts := _all()
	_check(ghosts.size() == HauntedHouse.EMOTIONS.size(),
		"all %d ghosts are here" % HauntedHouse.EMOTIONS.size())

	var feelings: Array[String] = []
	for g in ghosts:
		if not feelings.has(g.emotion):
			feelings.append(g.emotion)
	_check(feelings.size() == ghosts.size(), "no feeling is worn by two ghosts")

	# Every asset the island names must actually exist. A missing GLB renders as
	# nothing at all, which looks like a placement bug rather than a build one.
	var models_ok := true
	var audio_ok := true
	for e in HauntedHouse.EMOTIONS:
		if not ResourceLoader.exists("res://assets/models/ghost_%s.glb" % e):
			models_ok = false
		if not ResourceLoader.exists("res://assets/audio/emotion_%s.wav" % e):
			audio_ok = false
		if not ResourceLoader.exists("res://assets/audio/feel_%s.wav" % e):
			audio_ok = false
	_check(models_ok, "every ghost has a model")
	_check(audio_ok, "every feeling has a spoken name and a spoken question")

	# -- the lesson is the face, and nothing else -------------------------
	#
	# This asserts the height every ghost is SPAWNED at, which is the part that
	# is a decision. It is not the same as their bodies being identical on
	# screen: Models.spawn normalises the tallest axis, so a ghost whose bbox
	# includes raised arms or a floating sleep bubble spends some of that 1.6 m
	# on them and has a slightly smaller body. That is inherent to the poses and
	# is fine - the raised arms ARE the scared one's expression - but it is why
	# this check is worded as it is rather than claiming more than it measures.
	var same_height := true
	for g in ghosts:
		if not is_equal_approx(g.height, HauntedHouse.GHOST_H):
			same_height = false
	_check(same_height, "every ghost is spawned at the same height, so none is scaled to stand out")

	var tints: Array[Color] = []
	for e in HauntedHouse.EMOTIONS:
		tints.append(HauntedHouse.TINTS[e])
	var all_distinct := true
	var spread := 0.0
	for i in tints.size():
		for j in range(i + 1, tints.size()):
			var d: float = Vector3(tints[i].r - tints[j].r, tints[i].g - tints[j].g,
				tints[i].b - tints[j].b).length()
			if d < 0.0001:
				all_distinct = false
			spread = maxf(spread, d)
	_check(all_distinct, "no two ghosts share a tint")
	_check(spread < TINT_SPREAD_MAX,
		"and the tints are too close to sort by (spread %.3f < %.2f)"
			% [spread, TINT_SPREAD_MAX])

	# -- the questions ----------------------------------------------------
	var answers: Array[String] = []
	var all_real := true
	var no_repeats := true
	for r in HauntedHouse.ROUNDS:
		var ans := String(r["answer"])
		if not feelings.has(ans):
			all_real = false
		if answers.has(ans):
			no_repeats = false
		answers.append(ans)
	_check(all_real, "every question has an answer that lives here")
	_check(no_repeats, "and no two questions share an answer")
	_check(HauntedHouse.ROUNDS.size() == feelings.size(),
		"every feeling is asked about exactly once")

	# The ring: evenly spaced and all well inside the ground, so no ghost is
	# hiding behind the manor or off the edge of the island.
	var on_ring := true
	for g in ghosts:
		var off: Vector3 = g.global_position - _house.global_position
		var r: float = Vector2(off.x, off.z).length()
		if absf(r - HauntedHouse.RING_R) > 0.5 or r > HauntedHouse.GROUND_R - 2.0:
			on_ring = false
	_check(on_ring, "the ghosts stand on the ring, inside the island")

	_house.answered.connect(func(correct: bool, _e: String) -> void:
		if not correct:
			_wrong_seen = true)

	_steps = [
		{
			"what": "the door carries the player to the Haunted House",
			"act": func() -> void:
				_player.global_position = _root.HAUNTED_DOOR + Vector3(0, 1.0, 0),
			"ready": func() -> bool:
				return _player.global_position.distance_to(
					_root.ARRIVALS["haunted"]) < 3.0,
		},
		{
			"what": "arriving asks the first question",
			"act": func() -> void: pass,
			"ready": func() -> bool: return _house.question() != "",
		},
		{
			"what": "the wrong ghost does not advance the round",
			"act": func() -> void: _touch_wrong(),
			"ready": func() -> bool:
				return _wrong_seen and _house.round_index() == 0,
		},
		{
			"what": "the right ghost advances it",
			"act": func() -> void: _touch(_house.target()),
			"ready": func() -> bool: return _house.round_index() >= 1,
		},
		{
			# Trap 1, tested rather than assumed. Park the player inside one
			# ghost, then reshuffle until that ghost is the answer: with no
			# crossing left to fire, only _claim_overlaps can save the round.
			#
			# The reshuffling is done synchronously inside one frame rather
			# than a restart per frame, so the case is REACHED deterministically
			# instead of waiting on a lucky shuffle - a test that only
			# sometimes exercises the bug is worth very little.
			"what": "a round whose answer is the ghost already being touched still counts",
			"act": func() -> void:
				_parked = HauntedHouse.EMOTIONS[0]
				_retry_at = 0.0
				_arm_claim(),
			"ready": func() -> bool:
				if _house.round_index() >= 1:
					return true
				# One retry path, for a teleport that lands too late in the
				# frame for the area to have registered it. This cannot mask a
				# broken guard: a claim that never works still times out.
				if _elapsed > _retry_at:
					_retry_at = _elapsed + 3.0
					_arm_claim()
				return false,
		},
		{
			# The lesson is the face, so the face has to be pointed at the
			# player from wherever the player is. A wrong-signed yaw still
			# compiles and still turns smoothly - it just shows every ghost's
			# back - so this measures the direction rather than trusting it.
			"what": "every ghost turns its face towards the player",
			"act": func() -> void:
				_player.velocity = Vector3.ZERO
				_player.global_position = _house.global_position \
					+ Vector3(0, 1.0, HauntedHouse.RING_R + 6.0),
			"ready": func() -> bool:
				# Give the turn time to finish before judging it.
				if _elapsed < 3.0:
					return false
				for g in _all():
					var to_player: Vector3 = _player.global_position - g.global_position
					to_player.y = 0.0
					# -Z is the face; dot > 0 means it points at the player.
					var facing: Vector3 = -g.global_transform.basis.z
					if facing.dot(to_player.normalized()) < 0.8:
						return false
				return true,
		},
		{
			# They float on the spot rather than roam. This is the guard for
			# anyone who later gives them a wander.
			"what": "after floating a while they are all still on their marks",
			"act": func() -> void: _house.restart(),
			"ready": func() -> bool:
				if _elapsed < 6.0:
					return false
				for g in _all():
					var off: Vector3 = g.global_position - _house.global_position
					var r: float = Vector2(off.x, off.z).length()
					if absf(r - HauntedHouse.RING_R) > 0.5:
						return false
				return true,
		},
		{
			"what": "and the whole feelings game can be played through",
			"act": func() -> void: pass,
			"ready": func() -> bool:
				if _house.is_complete():
					return true
				_touch(_house.target())
				return false,
		},
		{
			"what": "finishing leaves every ghost lit for free play",
			"act": func() -> void: pass,
			"ready": func() -> bool:
				for g in _all():
					if not g.is_lit():
						return false
				return true,
		},
	]
	return false


## Park the player inside the `_parked` ghost and then reshuffle, in this one
## frame, until that ghost is the round's answer - so the next physics frame
## begins with the player standing in an answer they never crossed into.
func _arm_claim() -> void:
	_touch(_parked)
	for _i in 60:
		_house.restart()
		if _house.target() == _parked:
			return


func _touch(emotion: String) -> void:
	if emotion == "":
		return
	for g in _all():
		if g.emotion == emotion:
			_player.velocity = Vector3.ZERO
			_player.global_position = g.global_position + Vector3(0, 0.5, 0)
			return


func _touch_wrong() -> void:
	var want: String = _house.target()
	for g in _all():
		if g.emotion != want:
			_player.velocity = Vector3.ZERO
			_player.global_position = g.global_position + Vector3(0, 0.5, 0)
			return


func _all() -> Array:
	var out: Array = []
	for c in _house.get_children():
		if c is GhostFigure:
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
		print("hauntedhousetest: %d/%d checks passed" % [_checks, _checks])
	else:
		print("hauntedhousetest: %d of %d FAILED" % [_failures.size(), _checks])
		for f in _failures:
			print("   - %s" % f)
	quit(0 if _failures.is_empty() else 1)
	return true
