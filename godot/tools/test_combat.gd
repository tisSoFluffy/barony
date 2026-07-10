extends SceneTree
## Headless combat test: proves whether Player._resolve_melee_hit() connects
## with an enemy at close range from various relative directions.
## Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path <project> -s tools/test_combat.gd

var _root: Node3D
var PlayerScript: GDScript
var EnemyScript: GDScript

func _init() -> void:
	_root = Node3D.new()
	get_root().add_child(_root)
	call_deferred("_run")

func _run() -> void:
	PlayerScript = load("res://scripts/Player.gd")
	EnemyScript  = load("res://scripts/Enemy.gd")
	var all_pass := true

	# Directions to approach the enemy from, relative to player's forward.
	# 0 = enemy directly ahead, 90 = enemy to the side, 180 = enemy behind.
	var angles := [0.0, 45.0, 90.0, 135.0, 180.0, -90.0]

	for ang in angles:
		var ok := await _run_case(ang)
		all_pass = all_pass and ok
		print("[%s] angle=%d deg" % ["PASS" if ok else "FAIL", int(ang)])

	var nearest_ok := await _run_nearest_target_case()
	all_pass = all_pass and nearest_ok
	print("[%s] nearest-target selection" % ("PASS" if nearest_ok else "FAIL"))

	var facing_ok := await _run_facing_flip_mapping_case()
	all_pass = all_pass and facing_ok
	print("[%s] facing-to-flip_h mapping matches ART_FACES_LEFT (2026-07-08)" % ("PASS" if facing_ok else "FAIL"))

	var barrel_ok := await _run_breakable_barrel_case()
	all_pass = all_pass and barrel_ok
	print("[%s] melee damages and breaks BreakableBarrel (2026-07-09)" % ("PASS" if barrel_ok else "FAIL"))

	var crate_ok := await _run_breakable_crate_case()
	all_pass = all_pass and crate_ok
	print("[%s] melee damages and breaks BreakableCrate (2026-07-09)" % ("PASS" if crate_ok else "FAIL"))

	var pots_ok := await _run_breakable_pots_case()
	all_pass = all_pass and pots_ok
	print("[%s] melee damages and breaks BreakablePots (2026-07-09)" % ("PASS" if pots_ok else "FAIL"))

	print("=== %s ===" % ("ALL PASS" if all_pass else "SOME FAILED"))
	quit(0 if all_pass else 1)

# Regression guard for the "faces left at rest after moving right" bug: proves
# _update_anim's flip_h mapping is self-consistent with Player.ART_FACES_LEFT
# rather than pixel-perfect (that's DevRigShot's job) — moving/facing screen-
# right must always flip_h == ART_FACES_LEFT, and screen-left must flip_h ==
# (not ART_FACES_LEFT), regardless of which way the const is ever set in the
# future (art could get re-baked facing right some day).
func _run_facing_flip_mapping_case() -> bool:
	var player: Node3D = PlayerScript.new()
	_root.add_child(player)
	player._ready()
	player.global_position = Vector3.ZERO

	# Facing screen-right: dot(_facing_dir, (0.707,0,-0.707)) > 0.05.
	player._facing_dir = Vector3(1, 0, 0)
	player._update_anim()
	var right_ok: bool = player._sprite.flip_h == PlayerScript.ART_FACES_LEFT

	# Facing screen-left: dot(...) < -0.05.
	player._facing_dir = Vector3(-1, 0, 0)
	player._update_anim()
	var left_ok: bool = player._sprite.flip_h == (not PlayerScript.ART_FACES_LEFT)

	# Stop (zero velocity/no new intent): flip_h must persist the last facing,
	# not snap back — this is the actual "resting pose flipped" bug shape.
	player.velocity = Vector3.ZERO
	player._update_anim()
	var persists_ok: bool = player._sprite.flip_h == (not PlayerScript.ART_FACES_LEFT)

	player.queue_free()
	await process_frame
	return right_ok and left_ok and persists_ok

func _run_nearest_target_case() -> bool:
	# Two enemies dead ahead at different ranges: melee must hit the nearer one.
	var player: Node3D = PlayerScript.new()
	_root.add_child(player)
	player._ready()
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	player._facing_dir = Vector3(0, 0, -1)

	var near: Node3D = EnemyScript.new()
	near.type = "kobold"
	_root.add_child(near)
	near._ready()
	near.global_position = Vector3(0, 0, -1.0)
	near.hp = 30.0; near.maxhp = 30.0

	var far: Node3D = EnemyScript.new()
	far.type = "kobold"
	_root.add_child(far)
	far._ready()
	far.global_position = Vector3(0, 0, -1.8)
	far.hp = 30.0; far.maxhp = 30.0

	player._melee()
	var dt := 1.0 / 60.0
	var steps := 0
	while player.atk_t > 0.0 and steps < 120:
		player._physics_process(dt)
		steps += 1

	var ok: bool = near.hp < 30.0 and far.hp >= 30.0

	player.queue_free(); near.queue_free(); far.queue_free()
	await process_frame
	return ok

## Proves BreakableBarrel.gd plugs into the same group-scan hit detection
## melee/skills use for real enemies (group "enemy" + take_damage(amt,
## poise_mult)) without requiring any special-casing in Player.gd, and that
## enough hits actually breaks it (queue_free's itself).
func _run_breakable_barrel_case() -> bool:
	var player: Node3D = PlayerScript.new()
	_root.add_child(player)
	player._ready()
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	player._facing_dir = Vector3(0, 0, -1)

	var BarrelScript := load("res://scripts/BreakableBarrel.gd")
	var barrel: Node3D = BarrelScript.new()
	_root.add_child(barrel)
	barrel._ready()
	barrel.global_position = Vector3(0, 0, -1.0)
	barrel.hp = 35.0

	var start_hp: float = barrel.hp
	var dt := 1.0 / 60.0

	player._melee()
	var steps := 0
	while player.atk_t > 0.0 and steps < 120:
		player._physics_process(dt)
		steps += 1

	var first_hit_ok: bool = barrel.hp < start_hp and is_instance_valid(barrel)

	# Keep swinging until the barrel's hp is exhausted and _break() fires
	# (queue_free is deferred behind a short timer for the burst effect — we
	# check the _broken flag rather than instance validity so this test
	# doesn't depend on real wall-clock time elapsing).
	var swings := 0
	while is_instance_valid(barrel) and not barrel._broken and swings < 6:
		player._melee()  # direct call bypasses the input-gated atk_t<=0 check in _physics_process
		steps = 0
		while player.atk_t > 0.0 and steps < 120:
			player._physics_process(dt)
			steps += 1
		await process_frame
		swings += 1

	var broke_ok: bool = is_instance_valid(barrel) and barrel._broken

	player.queue_free()
	if is_instance_valid(barrel):
		barrel.queue_free()
	await process_frame
	await process_frame

	return first_hit_ok and broke_ok

## Proves BreakableCrate.gd plugs into the same group-scan hit detection
## melee/skills use for real enemies (group "enemy" + take_damage(amt,
## poise_mult)) without requiring any special-casing in Player.gd, and that
## enough hits actually breaks it (_broken flag set before queue_free defers).
func _run_breakable_crate_case() -> bool:
	var player: Node3D = PlayerScript.new()
	_root.add_child(player)
	player._ready()
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	player._facing_dir = Vector3(0, 0, -1)

	var CrateScript := load("res://scripts/BreakableCrate.gd")
	var crate: Node3D = CrateScript.new()
	_root.add_child(crate)
	crate._ready()
	crate.global_position = Vector3(0, 0, -1.0)
	crate.hp = 30.0

	var start_hp: float = crate.hp
	var dt := 1.0 / 60.0

	player._melee()
	var steps := 0
	while player.atk_t > 0.0 and steps < 120:
		player._physics_process(dt)
		steps += 1

	var first_hit_ok: bool = crate.hp < start_hp and is_instance_valid(crate)

	# Keep swinging until hp is exhausted and _break() fires.
	# Check _broken flag rather than instance validity — queue_free is deferred
	# behind a 0.7s timer for the burst effect; synthetic test time doesn't elapse.
	var swings := 0
	while is_instance_valid(crate) and not crate._broken and swings < 6:
		player._melee()
		steps = 0
		while player.atk_t > 0.0 and steps < 120:
			player._physics_process(dt)
			steps += 1
		await process_frame
		swings += 1

	var broke_ok: bool = is_instance_valid(crate) and crate._broken

	player.queue_free()
	if is_instance_valid(crate):
		crate.queue_free()
	await process_frame
	await process_frame

	return first_hit_ok and broke_ok


## Proves BreakablePots.gd plugs into the same group-scan hit detection
## melee/skills use for real enemies (group "enemy" + take_damage(amt,
## poise_mult)) without requiring any special-casing in Player.gd, and that
## enough hits actually breaks it (_broken flag set before queue_free defers).
func _run_breakable_pots_case() -> bool:
	var player: Node3D = PlayerScript.new()
	_root.add_child(player)
	player._ready()
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	player._facing_dir = Vector3(0, 0, -1)

	var PotsScript := load("res://scripts/BreakablePots.gd")
	var pots: Node3D = PotsScript.new()
	_root.add_child(pots)
	pots._ready()
	pots.global_position = Vector3(0, 0, -1.0)
	pots.hp = 10.0

	var start_hp: float = pots.hp
	var dt := 1.0 / 60.0

	player._melee()
	var steps := 0
	while player.atk_t > 0.0 and steps < 120:
		player._physics_process(dt)
		steps += 1

	var first_hit_ok: bool = pots.hp < start_hp and is_instance_valid(pots)

	# Keep swinging until hp is exhausted and _break() fires.
	# Check _broken flag rather than instance validity — queue_free is deferred
	# behind a short timer for the burst effect; synthetic test time doesn't elapse.
	var swings := 0
	while is_instance_valid(pots) and not pots._broken and swings < 6:
		player._melee()
		steps = 0
		while player.atk_t > 0.0 and steps < 120:
			player._physics_process(dt)
			steps += 1
		await process_frame
		swings += 1

	var broke_ok: bool = is_instance_valid(pots) and pots._broken

	player.queue_free()
	if is_instance_valid(pots):
		pots.queue_free()
	await process_frame
	await process_frame

	return first_hit_ok and broke_ok


func _run_case(angle_deg: float) -> bool:
	var player: Node3D = PlayerScript.new()
	_root.add_child(player)
	player._ready()  # sets up sprite/collision; group membership etc.
	player.global_position = Vector3.ZERO
	# Face along -Z (default forward for rotation.y = 0).
	player.rotation.y = 0.0

	var enemy: Node3D = EnemyScript.new()
	enemy.type = "kobold"
	_root.add_child(enemy)
	enemy._ready()
	# Place enemy at fixed close range (1.0m) at `angle_deg` from player's forward.
	var fwd := Vector3(0, 0, -1)
	var rel := fwd.rotated(Vector3.UP, deg_to_rad(angle_deg))
	enemy.global_position = player.global_position + rel * 1.0
	enemy.hp = 30.0
	enemy.maxhp = 30.0

	# Simulate realistic play: player moved toward the enemy right before
	# attacking, so _facing_dir points at it (mirrors how the movement code
	# in _physics_process sets _facing_dir from input direction).
	player._facing_dir = rel.normalized()

	var start_hp: float = enemy.hp
	player._melee()

	# Step physics frames until the deferred hit resolves (atk_t/atk_cd <= _atk_hit_t)
	# or attack cooldown fully elapses.
	var dt := 1.0 / 60.0
	var steps := 0
	while player.atk_t > 0.0 and steps < 120:
		player._physics_process(dt)
		steps += 1

	var hit: bool = enemy.hp < start_hp

	player.queue_free()
	enemy.queue_free()
	await process_frame

	return hit
