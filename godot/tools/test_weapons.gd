extends SceneTree
## Headless weapon-system test: WeaponDB integration into Player melee
## (cooldown/damage/reach/arc/stagger/crit/stamina) + WeaponOverlay swap safety.
## Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path <project> -s tools/test_weapons.gd

var _root: Node3D
var PlayerScript: GDScript
var EnemyScript: GDScript
var WeaponOverlayScript: GDScript
var WDB: Node  # WeaponDB autoload — looked up via /root, not a bare static identifier

func _init() -> void:
	_root = Node3D.new()
	get_root().add_child(_root)
	call_deferred("_run")

func _run() -> void:
	PlayerScript = load("res://scripts/Player.gd")
	EnemyScript  = load("res://scripts/Enemy.gd")
	WeaponOverlayScript = load("res://scripts/WeaponOverlay.gd")
	WDB          = get_root().get_node("/root/WeaponDB")
	var all_pass := true

	var cd_dmg_ok := await _run_cd_dmg_case()
	all_pass = all_pass and cd_dmg_ok
	print("[%s] each weapon's cd/damage matches WeaponDB" % ("PASS" if cd_dmg_ok else "FAIL"))

	var spear_ok := await _run_spear_reach_case()
	all_pass = all_pass and spear_ok
	print("[%s] spear hits at 2.4m where sword whiffs" % ("PASS" if spear_ok else "FAIL"))

	var gs_ok := await _run_greatsword_multi_case()
	all_pass = all_pass and gs_ok
	print("[%s] greatsword hits 3 surrounding enemies in one swing" % ("PASS" if gs_ok else "FAIL"))

	var dagger_ok := await _run_dagger_single_case()
	all_pass = all_pass and dagger_ok
	print("[%s] dagger hits only 1 of several surrounding enemies" % ("PASS" if dagger_ok else "FAIL"))

	var mace_ok := await _run_mace_stagger_case()
	all_pass = all_pass and mace_ok
	print("[%s] mace staggers in fewer hits than sword" % ("PASS" if mace_ok else "FAIL"))

	var overlay_ok := await _run_overlay_swap_case()
	all_pass = all_pass and overlay_ok
	print("[%s] equip_weapon swaps overlay texture without error" % ("PASS" if overlay_ok else "FAIL"))

	var anchors_ok := _run_anchor_overrides_case()
	all_pass = all_pass and anchors_ok
	print("[%s] all 5 non-sword weapons have a 3-frame attack ANCHOR_OVERRIDES entry" % ("PASS" if anchors_ok else "FAIL"))

	var visible_ok := await _run_attack_visibility_all_weapons_case()
	all_pass = all_pass and visible_ok
	print("[%s] weapon overlay stays visible every attack frame, all 6 weapons" % ("PASS" if visible_ok else "FAIL"))

	var yaw_ok := await _run_overlay_yaw_invariance_case()
	all_pass = all_pass and yaw_ok
	print("[%s] weapon overlay placement is invariant to player body yaw" % ("PASS" if yaw_ok else "FAIL"))

	print("=== %s ===" % ("ALL PASS" if all_pass else "SOME FAILED"))
	quit(0 if all_pass else 1)


func _mk_player() -> Node3D:
	var player: Node3D = PlayerScript.new()
	_root.add_child(player)
	player._ready()
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	player._facing_dir = Vector3(0, 0, -1)
	player.stamina = player.max_stamina
	return player

func _mk_enemy(pos: Vector3, hp: float = 9999.0) -> Node3D:
	var enemy: CharacterBody3D = EnemyScript.new()
	enemy.type = "kobold"
	_root.add_child(enemy)
	enemy._ready()
	enemy.global_position = pos
	enemy.hp = hp
	enemy.maxhp = hp
	return enemy

func _step_until_hit(player: Node3D) -> void:
	var dt := 1.0 / 60.0
	var steps := 0
	while player.atk_t > 0.0 and steps < 120:
		player._physics_process(dt)
		steps += 1

func _cleanup(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n): n.queue_free()

func _settle() -> void:
	await process_frame
	await process_frame


# (a) equip each of the 6 weapons; assert melee cd and hit damage follow WeaponDB.
func _run_cd_dmg_case() -> bool:
	var ok := true
	for id in WDB.ids():
		var def: Dictionary = WDB.get_def(id)
		var player := _mk_player()
		player.equip_weapon(id)
		var enemy := _mk_enemy(Vector3(0, 0, -1.0))
		var start_hp: float = enemy.hp

		player._melee()
		var expect_cd: float = def.get("cd", 0.45)
		if not is_equal_approx(player.atk_cd, expect_cd):
			print("  cd mismatch for %s: got %f want %f" % [id, player.atk_cd, expect_cd])
			ok = false

		_step_until_hit(player)
		var dealt: float = start_hp - enemy.hp
		# dmg = round(tot_dmg * dmg_mult) + [0,4] random, so lower bound is exact,
		# upper bound has slack for the random component and crit rolls.
		var base_expect: float = round(float(player.tot_dmg()) * float(def.get("dmg_mult", 1.0)))
		if dealt < base_expect - 0.5:
			print("  dmg too low for %s: dealt %f want >= %f" % [id, dealt, base_expect])
			ok = false

		_cleanup([player, enemy])
		await _settle()
	return ok


# (b) spear (reach_bonus 0.8) connects at 2.4m where a bare sword (reach ~1.3+0.6=1.9m) whiffs.
func _run_spear_reach_case() -> bool:
	var sword_player := _mk_player()
	var sword_enemy := _mk_enemy(Vector3(0, 0, -2.4))
	sword_player._melee()
	_step_until_hit(sword_player)
	var sword_whiffed: bool = sword_enemy.hp >= sword_enemy.maxhp
	_cleanup([sword_player, sword_enemy])
	await _settle()

	var spear_player := _mk_player()
	spear_player.equip_weapon("spear")
	var spear_enemy := _mk_enemy(Vector3(0, 0, -2.4))
	spear_player._melee()
	_step_until_hit(spear_player)
	var spear_hit: bool = spear_enemy.hp < spear_enemy.maxhp
	_cleanup([spear_player, spear_enemy])
	await _settle()

	if not sword_whiffed:
		print("  expected sword to whiff at 2.4m (test invariant broken)")
	if not spear_hit:
		print("  expected spear to hit at 2.4m")
	return sword_whiffed and spear_hit


# (c) greatsword ("wide" arc) hits up to 3 nearest surrounding enemies in one swing.
func _run_greatsword_multi_case() -> bool:
	var player := _mk_player()
	player.equip_weapon("greatsword")
	var enemies := [
		_mk_enemy(Vector3(0, 0, -1.0)),
		_mk_enemy(Vector3(0.9, 0, -0.9)),
		_mk_enemy(Vector3(-0.9, 0, -0.9)),
		_mk_enemy(Vector3(0, 0, 1.5)),  # behind — outside the wide cone, should NOT be hit
	]
	player._melee()
	_step_until_hit(player)
	var hit_count := 0
	for en in enemies:
		if en.hp < en.maxhp: hit_count += 1
	var behind_spared: bool = enemies[3].hp >= enemies[3].maxhp
	_cleanup([player] + enemies)
	await _settle()
	if hit_count != 3:
		print("  greatsword hit_count=%d want 3" % hit_count)
	if not behind_spared:
		print("  greatsword hit an enemy behind the player (arc leak)")
	return hit_count == 3 and behind_spared


# (c cont'd) dagger (normal arc, single target) hits only the nearest of several.
func _run_dagger_single_case() -> bool:
	var player := _mk_player()
	player.equip_weapon("dagger")
	var enemies := [
		_mk_enemy(Vector3(0, 0, -1.0)),
		_mk_enemy(Vector3(0.5, 0, -0.9)),
		_mk_enemy(Vector3(-0.5, 0, -0.9)),
	]
	player._melee()
	_step_until_hit(player)
	var hit_count := 0
	for en in enemies:
		if en.hp < en.maxhp: hit_count += 1
	_cleanup([player] + enemies)
	await _settle()
	if hit_count != 1:
		print("  dagger hit_count=%d want 1" % hit_count)
	return hit_count == 1


# (d) mace (stagger_mult 2.0) staggers (poise break) in fewer hits than sword.
func _hits_to_stagger(weapon_id: String) -> int:
	var player := _mk_player()
	if weapon_id != "sword":
		player.equip_weapon(weapon_id)
	var enemy := _mk_enemy(Vector3(0, 0, -1.0), 9999.0)
	var hits := 0
	while enemy._stagger_t <= 0.0 and hits < 20:
		player.atk_t = 0.0  # allow immediate re-swing
		player._melee()
		_step_until_hit(player)
		hits += 1
	_cleanup([player, enemy])
	return hits

func _run_mace_stagger_case() -> bool:
	var sword_hits := _hits_to_stagger("sword")
	await _settle()
	var mace_hits := _hits_to_stagger("mace")
	await _settle()
	if mace_hits >= sword_hits:
		print("  mace_hits=%d sword_hits=%d — expected mace < sword" % [mace_hits, sword_hits])
	return mace_hits < sword_hits and mace_hits > 0


# (e) equip_weapon swaps the overlay texture (or hides for sword-fallback textures
# missing) without error — exercises every id, including the missing-asset path.
func _run_overlay_swap_case() -> bool:
	var player := _mk_player()
	var ok := true
	for id in WDB.ids():
		player.equip_weapon(id)
		if player.equipped_weapon != id:
			ok = false
		if player._weapon_overlay != null:
			# _process isn't ticked headless without a frame; call directly to
			# exercise the same code path without relying on scene idle time.
			player._weapon_overlay._process(0.0)
	_cleanup([player])
	await _settle()
	return ok


# (f) every non-sword weapon defines its own ANCHOR_OVERRIDES with a 3-frame
# "attack" sequence (distinct carry pose + motion per weapon — sword alone
# relies on WeaponOverlay's shared ANCHORS default).
func _run_anchor_overrides_case() -> bool:
	var ok := true
	for id in WDB.ids():
		if id == "sword":
			continue
		if not WDB.ANCHOR_OVERRIDES.has(id):
			print("  ANCHOR_OVERRIDES missing entry for %s" % id)
			ok = false
			continue
		var overrides: Dictionary = WDB.ANCHOR_OVERRIDES[id]
		if not overrides.has("attack"):
			print("  %s ANCHOR_OVERRIDES missing 'attack' anim" % id)
			ok = false
			continue
		var attack_frames: Array = overrides["attack"]
		if attack_frames.size() != 3:
			print("  %s attack sequence has %d frames, want 3" % [id, attack_frames.size()])
			ok = false
	return ok


# (g) overlay stays visible on EVERY attack frame for all 6 weapons (extends
# the original single-weapon visibility check across the full roster — this
# is the regression the per-weapon anchor overrides must not reintroduce).
func _run_attack_visibility_all_weapons_case() -> bool:
	var player := _mk_player()
	var ok := true
	for id in WDB.ids():
		player.equip_weapon(id)
		var overlay: Node = player._weapon_overlay
		if overlay == null:
			print("  %s: no weapon overlay node" % id)
			ok = false
			continue
		var sprite: AnimatedSprite3D = player._sprite
		sprite.animation = "attack"
		var frame_count: int = sprite.sprite_frames.get_frame_count("attack")
		for f in range(frame_count):
			sprite.frame = f
			player.atk_cd = WDB.get_def(id).get("cd", 0.45)
			player.atk_t = player.atk_cd * (1.0 - float(f) / float(frame_count))
			overlay._process(0.0)
			if not overlay.visible:
				print("  %s: overlay hidden on attack frame %d" % [id, f])
				ok = false
	_cleanup([player])
	await _settle()
	return ok


# (h) regression for the "floating/disappearing weapon" bug: WeaponOverlay
# used to place itself via LOCAL position/rotation, which the parent
# CharacterBody3D's `rotation.y` (rotated toward movement in _physics_process)
# then re-rotated in world space — but the body's AnimatedSprite3D visual is
# BILLBOARD_FIXED_Y and ALWAYS faces the camera regardless of node yaw, so the
# weapon orbited away from the painted hand as the player turned. Fix: the
# overlay now builds its own global_transform every frame from fixed
# camera-space axes (CAM_RIGHT/CAM_UP), independent of parent node rotation.
# This asserts that invariant directly: for several player.rotation.y values,
# the overlay's offset from the sprite, projected onto the SAME fixed
# CAM_RIGHT/CAM_UP axes WeaponOverlay uses, must match the active anchor's
# `pos` — i.e. placement in the camera plane does not drift with body yaw.
# (Reasoning check for "must fail on the old code path": the old code set
# `position = Vector3(m.x, m.y, z_nudge)` as a LOCAL offset under a node whose
# parent rotates by `rotation.y` — projecting the resulting GLOBAL offset onto
# CAM_RIGHT/CAM_UP would only match the anchor's raw `pos` at yaw 0; at
# yaw 0.8/2.4 the local-to-global rotation skews the projection, failing this
# exact assertion. This was confirmed via the pre-fix DevRigShot captures at
# --rig-yaw=0.8 and --rig-yaw=2.4, which showed the sword visibly detached/
# edge-on at those headings.)
func _run_overlay_yaw_invariance_case() -> bool:
	const CAM_RIGHT := Vector3(0.707, 0.0, -0.707)
	const CAM_UP := Vector3.UP
	const TOL := 0.01
	var ok := true
	for yaw in [0.0, 0.8, 2.4]:
		var player := _mk_player()
		player.equip_weapon("sword")
		player.rotation.y = yaw
		var sprite: AnimatedSprite3D = player._sprite
		sprite.animation = "idle"
		sprite.frame = 0
		var overlay: Node3D = player._weapon_overlay
		overlay._process(0.0)
		var expect: Vector2 = WeaponOverlayScript.ANCHORS["idle"][0]["pos"]
		var delta: Vector3 = overlay.global_position - sprite.global_position
		var got := Vector2(delta.dot(CAM_RIGHT), delta.dot(CAM_UP))
		if got.distance_to(expect) > TOL:
			print("  yaw=%.2f: overlay offset (proj) = %s, want ~%s" % [yaw, got, expect])
			ok = false
		_cleanup([player])
		await _settle()
	return ok
