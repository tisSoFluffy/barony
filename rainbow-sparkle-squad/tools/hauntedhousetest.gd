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

	# Every ghost has to be INSIDE the house, or the search is not a search.
	var inside := true
	for g in ghosts:
		var off: Vector3 = g.global_position - _house.global_position
		if off.x < HauntedHouse.HOUSE_MIN.x or off.x > HauntedHouse.HOUSE_MAX.x \
				or off.z < HauntedHouse.HOUSE_MIN.y or off.z > HauntedHouse.HOUSE_MAX.y:
			inside = false
	_check(inside, "every ghost is hiding inside the house")

	# Split across the floors. All five on one floor would make the upstairs
	# decorative and the stairs pointless.
	var upstairs := 0
	for e in HauntedHouse.EMOTIONS:
		if _house.is_upstairs(e):
			upstairs += 1
	_check(upstairs > 0 and upstairs < HauntedHouse.EMOTIONS.size(),
		"they are split across both floors (%d up, %d down)"
			% [upstairs, HauntedHouse.EMOTIONS.size() - upstairs])

	# And each one somewhere of its own - two in a room means one round can be
	# answered by walking into the other one's room by accident.
	var spots: Array[Vector3] = []
	var shared := false
	for g in ghosts:
		for s in spots:
			if s.distance_to(g.position) < 1.0:
				shared = true
		spots.append(g.position)
	_check(not shared, "and no two of them share a hiding place")

	var named := true
	for e in HauntedHouse.EMOTIONS:
		if _house.room_of(e) == "":
			named = false
	_check(named, "every hiding place has a room name for the hint")

	# The ceiling has to clear a ghost's HEAD, which is not the same as clearing
	# its nominal height: it hovers, it bobs, and the model is scaled to the top
	# of all that. The house shipped once with a 1.60 m ceiling and 2.13 m
	# ghosts, so every one of them downstairs had its head through the floor
	# above - visible from the moment you walked in, and asserted by nothing.
	var ceiling: float = HauntedHouse.UPPER_Y - HauntedHouse.SLAB_T
	var tallest := 0.0
	for g in ghosts:
		if _house.is_upstairs(g.emotion):
			continue      # nothing above them but sky
		tallest = maxf(tallest,
			g.position.y + GhostFigure.HOVER + GhostFigure.BOB_HEIGHT + g.height)
	_check(tallest < ceiling,
		"the ceiling clears a ghost's head downstairs (%.2f m under a %.2f m ceiling)"
			% [tallest, ceiling])

	# -- the furniture ----------------------------------------------------
	var missing_models: Array[String] = []
	var too_tall: Array[String] = []
	var crowding: Array[String] = []
	for spec in HauntedHouse.FURNISHINGS:
		var model := String(spec["m"])
		if not ResourceLoader.exists("res://assets/models/%s.glb" % model):
			if not missing_models.has(model):
				missing_models.append(model)
		# Nothing may be taller than the room it stands in.
		if float(spec["h"]) > ceiling:
			too_tall.append(model)
		# The centre of a room WITH A GHOST IN IT is where that ghost floats, and
		# its touch box is 2.2 m across - a wardrobe parked there would be
		# answering the round. Three rooms hold no ghost at all, and their
		# middles are the best spot in them: the dining table wants to be
		# centred, not shoved against a wall to satisfy a rule about ghosts.
		var at: Vector2 = spec["at"]
		if at.length() < 1.4 and _holds_a_ghost(String(spec["room"])):
			crowding.append("%s in %s" % [model, spec["room"]])
	_check(missing_models.is_empty(),
		"every piece of furniture has a model" if missing_models.is_empty()
			else "but these furniture models are MISSING: %s" % ", ".join(missing_models))
	_check(too_tall.is_empty(), "and none of it is taller than the ceiling")

	# Inside the room's own four walls. An offset past the half-extent puts a
	# wardrobe through a wall and into the corridor, where it is both wrong and
	# in the way.
	var escaped: Array[String] = []
	for spec in HauntedHouse.FURNISHINGS:
		var room: Dictionary = HauntedHouse.ROOMS[spec["room"]]
		var half: Vector2 = room["half"]
		var at: Vector2 = spec["at"]
		if absf(at.x) > half.x - 0.3 or absf(at.y) > half.y - 0.3:
			escaped.append("%s in %s" % [spec["m"], spec["room"]])
	_check(escaped.is_empty(),
		"and all of it stands inside its own room" if escaped.is_empty()
			else "but these are through a wall: %s" % ", ".join(escaped))
	_check(crowding.is_empty(),
		"and none of it stands where a ghost floats" if crowding.is_empty()
			else "but these crowd the ghost: %s" % ", ".join(crowding))

	var furnished: Array[String] = []
	for spec in HauntedHouse.FURNISHINGS:
		if not furnished.has(String(spec["room"])):
			furnished.append(String(spec["room"]))
	_check(furnished.size() == HauntedHouse.ROOMS.size(),
		"every one of the %d rooms is furnished (%d are)"
			% [HauntedHouse.ROOMS.size(), furnished.size()])

	var rooms_real := true
	for spec in HauntedHouse.FURNISHINGS:
		if not HauntedHouse.ROOMS.has(spec["room"]):
			rooms_real = false
	for e in HauntedHouse.EMOTIONS:
		if not HauntedHouse.ROOMS.has(_house.room_of(e)):
			rooms_real = false
	_check(rooms_real,
		"and every room named by the furniture and the hints is a real room")

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
					+ Vector3(0, 1.0, HauntedHouse.HOUSE_MAX.y + 6.0),
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
			# The bug this exists for: the flight once filled the corridor, so
			# its foot could not be reached and the upper floor did not exist in
			# play. The climb check below did not catch it, because teleporting
			# onto the foot proves a ramp is CLIMBABLE while saying nothing
			# about whether a child can get to it. This walks the route.
			"what": "you can walk down the corridor past the stairs to their foot",
			"act": func() -> void:
				_player.velocity = Vector3.ZERO
				# Just inside the front door, on the walkway side of the corridor.
				_player.global_position = _house.global_position \
					+ Vector3(-1.0, 0.6, HauntedHouse.HOUSE_MAX.y - 1.0)
				Input.action_press("move_forward"),
			"ready": func() -> bool:
				var off: Vector3 = _player.global_position - _house.global_position
				# Past the foot of the flight, and still on the ground - having
				# walked BESIDE the stairs rather than up them.
				if off.z < HauntedHouse.STAIR_Z0 - 0.5 and off.y < 0.5:
					Input.action_release("move_forward")
					return true
				return false,
		},
		{
			# The single most important thing on this island: if a child cannot
			# get up the stairs, two of the five ghosts do not exist. Walked
			# rather than teleported, because the ramp has to be climbable by
			# holding forward - CharacterBody3D does not step up, so a
			# staircase built from boxes would look perfect and stop the player
			# dead at the first riser.
			"what": "the stairs actually carry the player to the upper floor",
			"act": func() -> void:
				_player.velocity = Vector3.ZERO
				# In the turning bay at the foot of the flight, lined up with it.
				_player.global_position = _house.global_position \
					+ Vector3(HauntedHouse.STAIR_X, 0.6,
						HauntedHouse.STAIR_Z0 - 0.9)
				Input.action_press("move_back"),
			"ready": func() -> bool:
				# -Z is "forward" for the stick; the ramp climbs towards +Z, so
				# hold the key that drives that way and wait to gain height.
				var y: float = _player.global_position.y - _house.global_position.y
				if y > HauntedHouse.UPPER_Y - 0.35:
					Input.action_release("move_back")
					return true
				return false,
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
					var spot: Dictionary = HauntedHouse.HIDING[g.emotion]
					var want: Vector2 = spot["pos"]
					var off: Vector3 = g.global_position - _house.global_position
					if Vector2(off.x, off.z).distance_to(want) > 0.5:
						return false
					var want_y: float = HauntedHouse.UPPER_Y if spot["upper"] else 0.0
					if absf(off.y - want_y) > 0.5:
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


func _holds_a_ghost(room: String) -> bool:
	for e in HauntedHouse.EMOTIONS:
		if _house.room_of(e) == room:
			return true
	return false


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
