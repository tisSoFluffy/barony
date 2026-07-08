extends SceneTree
## Headless ranged-attacker test: proves troll/necro wind up, fire a projectile
## at release (not anim start), the projectile damages the player on hit, and
## the firing enemy never damages itself.
## Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path <project> -s tools/test_ranged.gd

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

	for etype in ["troll", "necro"]:
		var ok := await _run_case(etype)
		all_pass = all_pass and ok
		print("[%s] %s ranged attack" % ["PASS" if ok else "FAIL", etype])

	print("=== %s ===" % ("ALL PASS" if all_pass else "SOME FAILED"))
	quit(0 if all_pass else 1)

func _run_case(etype: String) -> bool:
	var player: Node3D = PlayerScript.new()
	_root.add_child(player)
	player._ready()
	player.global_position = Vector3.ZERO
	player.hp = 120.0
	player.maxhp = 120.0

	var enemy: CharacterBody3D = EnemyScript.new()
	enemy.type = etype
	_root.add_child(enemy)
	enemy._ready()
	enemy.awake = true
	var pref: float = enemy.RANGED[etype]["range"]
	enemy.global_position = Vector3(0, 0, -pref)  # sit at preferred range
	enemy.hp = 60.0
	enemy.maxhp = 60.0
	var start_enemy_hp: float = enemy.hp
	var start_player_hp: float = player.hp

	var dt := 1.0 / 60.0
	var steps := 0
	var proj: Node = null
	var saw_wind_before_proj := false

	# Step until a projectile appears (proves wind-up telegraph fired first,
	# since _winding_up must be true before release fires) or we time out.
	while proj == null and steps < 300:
		if enemy._winding_up:
			saw_wind_before_proj = true
		enemy._physics_process(dt)
		player._physics_process(dt)
		for child in _root.get_children():
			if child is Projectile:
				proj = child
				break
		steps += 1

	var proj_appeared := proj != null and saw_wind_before_proj

	# Step until the projectile connects or times out.
	var connect_steps := 0
	while proj != null and is_instance_valid(proj) and connect_steps < 300:
		proj._physics_process(dt)
		connect_steps += 1
		if not is_instance_valid(proj):
			break

	var player_hit: bool = player.hp < start_player_hp
	var enemy_self_safe: bool = enemy.hp >= start_enemy_hp  # firing enemy took no damage from its own shot

	var ok: bool = proj_appeared and player_hit and enemy_self_safe
	if not proj_appeared:
		print("  fail: projectile never appeared (wind-up=%s)" % saw_wind_before_proj)
	if not player_hit:
		print("  fail: player hp unchanged (%.1f -> %.1f)" % [start_player_hp, player.hp])
	if not enemy_self_safe:
		print("  fail: firing enemy took self-damage (%.1f -> %.1f)" % [start_enemy_hp, enemy.hp])

	player.queue_free(); enemy.queue_free()
	if proj != null and is_instance_valid(proj):
		proj.queue_free()
	await process_frame
	return ok
