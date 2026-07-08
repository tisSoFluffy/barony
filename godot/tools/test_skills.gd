extends SceneTree
## Headless skill test: whirlwind (Q, lvl 2) and charge (B, lvl 4) — unlock gating,
## AoE hit coverage, cooldown refusal, dash distance/damage, and dash i-frames.
## Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path <project> -s tools/test_skills.gd

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

	var locked_ok := await _run_whirlwind_locked_case()
	all_pass = all_pass and locked_ok
	print("[%s] whirlwind refused below level 2" % ("PASS" if locked_ok else "FAIL"))

	var aoe_ok := await _run_whirlwind_aoe_case()
	all_pass = all_pass and aoe_ok
	print("[%s] whirlwind hits all enemies in 360 degrees" % ("PASS" if aoe_ok else "FAIL"))

	var cd_ok := await _run_whirlwind_cooldown_case()
	all_pass = all_pass and cd_ok
	print("[%s] whirlwind respects cooldown" % ("PASS" if cd_ok else "FAIL"))

	var charge_ok := await _run_charge_case()
	all_pass = all_pass and charge_ok
	print("[%s] charge dashes and damages first enemy hit" % ("PASS" if charge_ok else "FAIL"))

	var iframe_ok := await _run_charge_iframe_case()
	all_pass = all_pass and iframe_ok
	print("[%s] charge grants i-frames during the dash" % ("PASS" if iframe_ok else "FAIL"))

	print("=== %s ===" % ("ALL PASS" if all_pass else "SOME FAILED"))
	quit(0 if all_pass else 1)


func _mk_player(lvl: int) -> Node3D:
	var player: Node3D = PlayerScript.new()
	_root.add_child(player)
	player._ready()
	player.global_position = Vector3.ZERO
	player.level = lvl
	player.mana = player.tot_maxmana()
	player.stamina = player.max_stamina
	return player


func _mk_enemy(pos: Vector3, hp: float = 30.0) -> Node3D:
	var enemy: CharacterBody3D = EnemyScript.new()
	enemy.type = "kobold"
	_root.add_child(enemy)
	enemy._ready()
	enemy.global_position = pos
	enemy.hp = hp
	enemy.maxhp = hp
	return enemy


func _run_whirlwind_locked_case() -> bool:
	var player := _mk_player(1)
	var enemy := _mk_enemy(Vector3(0, 0, -1.0))
	var start_hp: float = enemy.hp
	var start_mana: float = player.mana

	player._ability_q()
	await process_frame

	var ok: bool = enemy.hp == start_hp and player.mana == start_mana and player._ww_cd <= 0.0
	if not ok:
		print("  fail: enemy.hp %.1f->%.1f mana %.1f->%.1f cd=%.2f" %
			[start_hp, enemy.hp, start_mana, player.mana, player._ww_cd])

	player.queue_free(); enemy.queue_free()
	await physics_frame
	await physics_frame  # let the physics server release freed colliders
	return ok


func _run_whirlwind_aoe_case() -> bool:
	var player := _mk_player(2)
	var enemies: Array = []
	for ang_deg in [0.0, 120.0, 240.0]:
		var dir := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(ang_deg))
		enemies.append(_mk_enemy(dir * 2.0))  # within 2.4m radius

	var start_mana: float = player.mana
	player._ability_q()
	await process_frame

	var all_hit := true
	for en in enemies:
		if en.hp >= 30.0:
			all_hit = false
	var spent: bool = player.mana < start_mana
	var ok: bool = all_hit and spent

	if not ok:
		for i in range(enemies.size()):
			print("  enemy[%d].hp=%.1f" % [i, enemies[i].hp])
		print("  mana spent: %s (%.1f -> %.1f)" % [spent, start_mana, player.mana])

	player.queue_free()
	for en in enemies: en.queue_free()
	await physics_frame
	await physics_frame  # let the physics server release freed colliders
	return ok


func _run_whirlwind_cooldown_case() -> bool:
	var player := _mk_player(2)
	var enemy := _mk_enemy(Vector3(0, 0, -1.0))

	player._ability_q()
	await process_frame
	var hp_after_first: float = enemy.hp
	player.mana = player.tot_maxmana()
	player.stamina = player.max_stamina

	player._ability_q()  # immediate second cast — should be refused (on cooldown)
	await process_frame

	var ok: bool = enemy.hp == hp_after_first
	if not ok:
		print("  fail: second whirlwind connected despite cooldown (hp %.1f -> %.1f)" %
			[hp_after_first, enemy.hp])

	player.queue_free(); enemy.queue_free()
	await physics_frame
	await physics_frame  # let the physics server release freed colliders
	return ok


func _run_charge_case() -> bool:
	# Earlier cases may leave CombatJuice.hit_stop's async time_scale dip still
	# in flight (its restore timer runs on real time, which this headless
	# harness doesn't reliably advance between awaits) — reset before a case
	# that depends on precise per-frame movement distance.
	Engine.time_scale = 1.0
	var player := _mk_player(4)
	player.rotation.y = 0.0
	player._facing_dir = Vector3(0, 0, -1)
	var enemy := _mk_enemy(Vector3(0, 0, -4.2))  # near the end of the 5m dash path
	var start_hp: float = enemy.hp
	var start_pos: Vector3 = player.global_position

	player._ability_b()
	var dt := 1.0 / 60.0
	var steps := 0
	while (player._charge_t > 0.0 or steps == 0) and steps < 60:
		player._physics_process(dt)
		steps += 1

	var moved: float = player.global_position.distance_to(start_pos)
	var damaged: bool = enemy.hp < start_hp
	var ok: bool = moved >= 3.0 and damaged
	if not ok:
		print("  fail: moved=%.2fm damaged=%s (enemy hp %.1f -> %.1f)" %
			[moved, damaged, start_hp, enemy.hp])

	player.queue_free(); enemy.queue_free()
	await physics_frame
	await physics_frame  # let the physics server release freed colliders
	return ok


func _run_charge_iframe_case() -> bool:
	Engine.time_scale = 1.0
	var player := _mk_player(4)
	player.rotation.y = 0.0
	player._facing_dir = Vector3(0, 0, -1)
	# No enemy in the dash path this time — isolate the i-frame check from the
	# dash-hit early-out (charge ends the dash on contact).
	var start_hp: float = player.hp

	player._ability_b()
	# Mid-dash: apply a melee-style hit and confirm iframe blocks it entirely.
	var dt := 1.0 / 60.0
	player._physics_process(dt)
	var mid_dash: bool = player._charge_t > 0.0
	player.take_damage(50, "test")

	var ok: bool = mid_dash and player.hp == start_hp
	if not ok:
		print("  fail: mid_dash=%s hp %.1f -> %.1f" % [mid_dash, start_hp, player.hp])

	player.queue_free()
	await physics_frame
	await physics_frame  # let the physics server release freed colliders
	return ok
