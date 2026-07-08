extends SceneTree
## Headless progression test: proves per-type XP awards on enemy death,
## the level-up curve (level*100) raises maxhp/base_dmg, and player_xp_changed fires.
## Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path <project> -s tools/test_progression.gd

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

	var xp_ok := await _run_xp_award_case()
	all_pass = all_pass and xp_ok
	print("[%s] kill awards per-type XP" % ("PASS" if xp_ok else "FAIL"))

	var lvl_ok := await _run_level_up_case()
	all_pass = all_pass and lvl_ok
	print("[%s] level-up raises maxhp/base_dmg" % ("PASS" if lvl_ok else "FAIL"))

	var sig_ok := await _run_signal_case()
	all_pass = all_pass and sig_ok
	print("[%s] player_xp_changed signal fires" % ("PASS" if sig_ok else "FAIL"))

	print("=== %s ===" % ("ALL PASS" if all_pass else "SOME FAILED"))
	quit(0 if all_pass else 1)


func _run_xp_award_case() -> bool:
	var player: Node3D = PlayerScript.new()
	_root.add_child(player)
	player._ready()
	var start_xp: int = player.xp

	var enemy: CharacterBody3D = EnemyScript.new()
	enemy.type = "skeleton"  # XP_REWARD["skeleton"] == 25
	_root.add_child(enemy)
	enemy._ready()
	enemy.player = player
	enemy.hp = 30.0
	enemy.maxhp = 30.0
	enemy.take_damage(999)  # lethal — triggers _die() -> _award_xp()
	await process_frame

	var expect: int = EnemyScript.XP_REWARD["skeleton"]
	var ok: bool = player.xp == start_xp + expect
	if not ok:
		print("  fail: expected xp=%d got xp=%d" % [start_xp + expect, player.xp])

	player.queue_free()
	await process_frame
	return ok


func _run_level_up_case() -> bool:
	var player: Node3D = PlayerScript.new()
	_root.add_child(player)
	player._ready()
	var start_maxhp: float = player.maxhp
	var start_dmg: int = player.base_dmg
	var start_level: int = player.level

	player.gain_xp(player.level * 100)  # exactly enough to level once

	var leveled: bool = player.level == start_level + 1
	var hp_up: bool = player.maxhp > start_maxhp
	var dmg_up: bool = player.base_dmg > start_dmg
	var ok: bool = leveled and hp_up and dmg_up
	if not leveled:
		print("  fail: level unchanged (%d -> %d)" % [start_level, player.level])
	if not hp_up:
		print("  fail: maxhp unchanged (%.1f -> %.1f)" % [start_maxhp, player.maxhp])
	if not dmg_up:
		print("  fail: base_dmg unchanged (%d -> %d)" % [start_dmg, player.base_dmg])

	player.queue_free()
	await process_frame
	return ok


func _run_signal_case() -> bool:
	var player: Node3D = PlayerScript.new()
	_root.add_child(player)
	player._ready()

	# Array wrapper — GDScript lambdas capture locals by value, not reference,
	# so a reassignment inside the callback wouldn't be visible out here.
	var got := [-1, -1, -1]
	var cb := func(xp: int, xp_needed: int, level: int) -> void:
		got[0] = xp; got[1] = xp_needed; got[2] = level
	var signal_bus := get_root().get_node_or_null("/root/SignalBus")
	if signal_bus == null:
		print("  fail: SignalBus autoload not found")
		player.queue_free()
		return false
	signal_bus.player_xp_changed.connect(cb)

	player.gain_xp(10)
	await process_frame

	signal_bus.player_xp_changed.disconnect(cb)

	var ok: bool = got[0] == player.xp and got[1] == player.level * 100 and got[2] == player.level
	if not ok:
		print("  fail: signal payload xp=%d needed=%d level=%d (player xp=%d level=%d)" %
			[got[0], got[1], got[2], player.xp, player.level])

	player.queue_free()
	await process_frame
	return ok
