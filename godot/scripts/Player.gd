extends CharacterBody3D
## Isometric player controller + combat. SNES USB joypad + WASD keyboard.

const SwingTrail := preload("res://scripts/SwingTrail.gd")
##
## Joypad D-pad buttons are tracked manually via _input() because some HID
## adapters (e.g. cheap SNES USB) send press events but drop release events,
## leaving Godot's internal button state permanently stuck. We own the state.

# Manual joypad button state — keys are JoyButton ints, values are bool.
# Reset when joypad disconnects so no ghost inputs carry over.
var _joy: Dictionary = {}
var _joy_press_time: Dictionary = {}  # button_index → Time.get_ticks_msec() of last press

# This SNES USB HID adapter sends press events during direction transitions but
# NEVER sends a release event when returning to neutral (hat switch center).
# Fix: when a new D-pad direction fires, clear all stale d-pad state (handles transitions);
# for the "full release with no new direction" case, expire after JOY_DPAD_EXPIRY_MS.
const JOY_DPAD_EXPIRY_MS := 5000  # max drift after full D-pad release (5 s)
const _DPAD_ALL  := [11, 12, 13, 14]
const _DPAD_OPP  := {11: 12, 12: 11, 13: 14, 14: 13}  # button → opposite
const STICK_DEADZONE := 0.2  # left-stick analog movement deadzone

func _ready_joy() -> void:
	Input.joy_connection_changed.connect(func(_dev: int, connected: bool) -> void:
		if not connected:
			_joy.clear()
			_joy_press_time.clear())

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		var btn: int = int(event.button_index)
		var now: int = Time.get_ticks_msec()
		if event.pressed:
			if btn in _DPAD_OPP:
				# New D-pad direction: clear all OTHER d-pad directions that predate this
				# press by more than one frame (~32 ms). Directions within the same
				# 32 ms window are part of the same diagonal and should be kept.
				for old in _DPAD_ALL:
					if old != btn:
						var age: int = now - _joy_press_time.get(old, now - 99999)
						if age > 32:
							_joy.erase(old)
							_joy_press_time.erase(old)
			_joy[btn] = true
			_joy_press_time[btn] = now
		else:
			_joy.erase(btn)
			_joy_press_time.erase(btn)

func _joy_btn(b: int) -> bool:
	if not _joy.get(b, false):
		return false
	# Expire D-pad buttons that have been "held" too long without a new press event.
	# The adapter never sends neutral → we auto-clear after JOY_DPAD_EXPIRY_MS.
	if b in _DPAD_OPP:
		var age: int = Time.get_ticks_msec() - _joy_press_time.get(b, 0)
		if age > JOY_DPAD_EXPIRY_MS:
			_joy.erase(b)
			_joy_press_time.erase(b)
			return false
	return true

@export var move_speed: float = 4.2

var cls := "war"

var maxhp      := 120.0
var hp         := 120.0
var maxmana    := 50.0
var mana       := 50.0
var base_dmg   := 18
var base_spell := 0
var regen      := 1.5
var level      := 1
var xp         := 0
var dead       := false
var blocking   := false

var _sprite: AnimatedSprite3D = null
var _weapon_overlay: Node = null

var equipped_weapon: String = "sword"

var gold  := 0
var keys  := 0
var hpots := 1
var mpots := 1
var kills := 0
var equip := {"weapon": null, "armor": null, "helm": null, "ring": null}
var bag: Array = []

var atk_t  := 0.0
var atk_cd := 0.0
var iframe  := 0.0
var hurt_t  := 0.0
var _kb_t      := 0.0
var _kb_vel    := Vector3.ZERO
var _backstep_t   := 0.0
var _backstep_vel := Vector3.ZERO
var _atk_hit_t    := -1.0
var _pending_dmg  := 0
var _pending_crit := false
var _facing_dir   := Vector3.FORWARD  # last non-zero move dir; used to aim melee

# skills — cooldowns count down in _physics_process; 0 == ready
var _ww_cd     := 0.0
var _charge_cd := 0.0
var _charge_t   := 0.0   # remaining dash time; >0 while charging
var _charge_dir := Vector3.FORWARD
var _charge_hit := false  # first-contact-only guard for the current dash
const WW_LEVEL     := 2
const WW_MANA      := 20.0
const WW_STAM      := 25.0
const WW_CD        := 6.0
const WW_RADIUS    := 2.4
const WW_DMG_MULT  := 1.4
const CHARGE_LEVEL := 4
const CHARGE_MANA  := 15.0
const CHARGE_STAM  := 20.0
const CHARGE_CD    := 8.0
const CHARGE_DIST  := 5.0
const CHARGE_DUR   := 0.28
const CHARGE_DMG_MULT := 1.8

# stamina
var stamina     := 100.0
var max_stamina := 100.0

# dodge roll
var _dodge_t   := 0.0
var _dodge_dir := Vector3.ZERO


# parry / riposte
var _parry_t    := 0.0
var _riposte_t  := 0.0
var _block_prev := false

const CRIT_CHANCE := {"war": 0.10}
const CRIT_MULT   := {"war": 1.8}

const STAM_REGEN := 18.0
const STAM_ATK   := 22.0
const STAM_DODGE := 30.0
const STAM_HEAVY := 42.0
const DODGE_DUR  := 0.28
const DODGE_CD   := 0.55
const DODGE_SPD  := 9.0

# Fixed camera yaw — 45° isometric
const ISO_YAW := deg_to_rad(45.0)

# Whether the UNFLIPPED source sheets (warrior/warrior-base) read as facing
# screen-LEFT at rest. Flip comparisons in _update_anim are derived from this
# flag so "screen_x > 0 (facing right) => flip_h == ART_FACES_LEFT" reads as
# "flip away from the art's native side" instead of a bare, undocumented sign
# flip. Confirmed correct via direct user comparison of the left/right poses
# (2026-07-08): facing left should show shield screen-right/sword screen-left
# (art's native, unflipped side), facing right should mirror it.
const ART_FACES_LEFT := true
# The walk and attack sheets were each generated independently of idle/hurt
# and read with the opposite native facing from them. User confirmed
# (2026-07-08): with ART_FACES_LEFT's mapping, idle read correctly but walk
# and attack both read mirrored, so they get their own flag.
const WALK_FACES_LEFT   := false
const ATTACK_FACES_LEFT := false

func _iso_basis() -> Basis:
	return Basis(Vector3.UP, ISO_YAW)

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	collision_layer = 1
	collision_mask = 1
	_ready_joy()
	_setup_warrior()
	# Collision: Player.tscn provides a CollisionShape3D child (scene path) —
	# reuse it as-is. When `.new()`'d directly (test suites), no such child
	# exists yet, so build it in code with the same dimensions the scene uses.
	var col := _find_collision_shape()
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.28
		cap.height = 1.4
		col.shape = cap
		col.position.y = 0.7
		add_child(col)
	# Sprite / shadow / weapon overlay. Guarded so a re-entrant _ready() can't double-add.
	if _sprite == null:
		# Prefer the weaponless "warrior-base" rig once its sheets exist so the
		# WeaponOverlay always shows a real hand-held weapon instead of doubling
		# up on the legacy baked-sword "warrior" sheet.
		var body := "warrior-base" if ResourceLoader.exists("res://sprites/sliced/warrior-base/idle_0.png") else "warrior"
		# Player.tscn provides an editable AnimatedSprite3D named "Sprite" (so
		# animations preview in the editor) — configure it in place. When `.new()`'d
		# directly (test suites) there's no such child, so build one in code.
		var scene_sprite := get_node_or_null("Sprite") as AnimatedSprite3D
		if scene_sprite != null:
			_sprite = scene_sprite
			SpriteFactory.configure_sprite(_sprite, body)
		else:
			_sprite = SpriteFactory.make_sprite(body)
			add_child(_sprite)
		add_child(ShadowFactory.make_shadow(0.6))
		_setup_weapon_overlay()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--equip-weapon="):
			equip_weapon(arg.trim_prefix("--equip-weapon="))
	SignalBus.player_xp_changed.emit(xp, level * 100, level)

func _find_collision_shape() -> CollisionShape3D:
	var existing := get_node_or_null("CollisionShape3D")
	if existing is CollisionShape3D:
		return existing
	for child in get_children():
		if child is CollisionShape3D:
			return child
	return null

func _setup_warrior() -> void:
	maxhp = 120.0;  hp    = maxhp
	maxmana = 50.0; mana  = maxmana
	base_dmg = 18;  base_spell = 0
	regen = 1.5
	hpots = 1; mpots = 1

# ---------------------------------------------------------------------------
# Gear / inventory
# ---------------------------------------------------------------------------

func gear_sum(stat: String) -> int:
	var s := 0
	for k in equip:
		var g = equip[k]
		if g != null:
			s += int(g["b"].get(stat, 0))
	return s

func tot_dmg() -> int:     return base_dmg + gear_sum("dmg")
func tot_spell() -> int:   return base_spell + gear_sum("spell")
func tot_maxhp() -> int:   return int(maxhp) + gear_sum("hp")
func tot_maxmana() -> int: return int(maxmana) + gear_sum("mana")
func tot_armor() -> int:   return gear_sum("armor")

# ---------------------------------------------------------------------------
# Weapons — WeaponDB drives melee cd/damage/reach/arc/stagger/knockback/crit/
# stamina (see _melee/_resolve_melee_hit). Swapping the id also swaps the
# paper-doll overlay texture (WeaponOverlay.gd) atop the baked-sword sprite.
# ---------------------------------------------------------------------------

func _weapon_def() -> Dictionary:
	return WeaponDB.get_def(equipped_weapon)

func equip_weapon(id: String) -> void:
	if not WeaponDB.defs.has(id):
		return
	equipped_weapon = id
	if _weapon_overlay != null and _weapon_overlay.has_method("set_weapon"):
		_weapon_overlay.set_weapon(id)
	_msg("Equipped %s." % WeaponDB.get_def(id).get("name", id), Color("a0c8ff"))

func _setup_weapon_overlay() -> void:
	if _sprite == null:
		return
	# Player.tscn ships a visible "WeaponOverlay" node under Sprite (editor
	# preview: sword at rest). Adopt it when present; build in code when the
	# player was `.new()`'d (test suites). set_weapon() replaces the preview
	# texture/pivot with the equipped weapon's cropped runtime version.
	var scene_overlay := _sprite.get_node_or_null("WeaponOverlay")
	if scene_overlay != null:
		_weapon_overlay = scene_overlay
	else:
		var overlay_script := load("res://scripts/WeaponOverlay.gd")
		if overlay_script == null:
			return
		_weapon_overlay = overlay_script.new()
		_sprite.add_child(_weapon_overlay)
	_weapon_overlay.set_weapon(equipped_weapon)

func add_gear(g: Dictionary) -> bool:
	if bag.size() >= 6: return false
	bag.append(g); return true

func equip_from_bag(i: int) -> void:
	if i < 0 or i >= bag.size(): return
	var g    = bag[i]
	var slot = g["slot"]
	var cur  = equip[slot]
	equip[slot] = g
	bag.remove_at(i)
	if cur != null: bag.append(cur)
	hp = minf(hp, tot_maxhp()); mana = minf(mana, tot_maxmana())

func unequip_slot(slot: String) -> void:
	var g = equip[slot]
	if g == null or bag.size() >= 6: return
	bag.append(g); equip[slot] = null
	hp = minf(hp, tot_maxhp()); mana = minf(mana, tot_maxmana())

func drop_from_bag(i: int) -> void:
	if i >= 0 and i < bag.size(): bag.remove_at(i)

# ---------------------------------------------------------------------------
# Consumables
# ---------------------------------------------------------------------------

func use_hpot() -> void:
	if dead: return
	if hpots <= 0: _msg("No health potions left!", Color("ff7050")); return
	hpots -= 1
	hp = minf(tot_maxhp(), hp + 45)
	SignalBus.player_health_changed.emit(int(hp), int(maxhp))
	_msg("You quaff a health potion. (+45)", Color("ff9a8a"))

func use_mpot() -> void:
	if dead: return
	if mpots <= 0: _msg("No mana potions left!", Color("ff7050")); return
	mpots -= 1
	mana = minf(tot_maxmana(), mana + 40)
	_msg("You quaff a mana potion. (+40)", Color("8ab8ff"))

func grant(kind: String, amt: int, gear) -> void:
	match kind:
		"gold": gold += amt; _msg("+%d gold" % amt, Color("ffd84a"))
		"hpot": hpots += 1; _msg("Picked up a health potion. (H)", Color("ff9a8a"))
		"mpot": mpots += 1; _msg("Picked up a mana potion.", Color("8ab8ff"))
		"key":  keys += 1;  _msg("You found a vault key!", Color("ffce42"))
		"gear":
			if gear and add_gear(gear):
				_msg("You found %s." % gear["name"], Color("a0c8ff"))

# ---------------------------------------------------------------------------
# XP / levelling
# ---------------------------------------------------------------------------

func gain_xp(amt: int) -> void:
	xp += amt
	while xp >= level * 100:
		xp -= level * 100
		level    += 1
		maxhp    += 12; maxmana  += 8
		base_dmg += 2
		hp = tot_maxhp(); mana = tot_maxmana()
		_msg("You reach level %d!" % level, Color("ffce42"))
		SignalBus.player_level_up.emit(level)
	SignalBus.player_xp_changed.emit(xp, level * 100, level)

# ---------------------------------------------------------------------------
# Physics loop
# ---------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	atk_t      = maxf(0.0, atk_t - dt)
	iframe     = maxf(0.0, iframe - dt)
	hurt_t     = maxf(0.0, hurt_t - dt)
	_kb_t      = maxf(0.0, _kb_t - dt)
	_backstep_t   = maxf(0.0, _backstep_t - dt)
	_dodge_t   = maxf(0.0, _dodge_t - dt)
	_parry_t   = maxf(0.0, _parry_t - dt)
	_riposte_t = maxf(0.0, _riposte_t - dt)

	var prev_ww_cd := _ww_cd
	_ww_cd = maxf(0.0, _ww_cd - dt)
	if prev_ww_cd > 0.0 and _ww_cd <= 0.0:
		SignalBus.player_skill_cooldown.emit("whirlwind", WW_CD, WW_CD)
	var prev_charge_cd := _charge_cd
	_charge_cd = maxf(0.0, _charge_cd - dt)
	if prev_charge_cd > 0.0 and _charge_cd <= 0.0:
		SignalBus.player_skill_cooldown.emit("charge", CHARGE_CD, CHARGE_CD)
	var _was_dashing := _charge_t > 0.0
	_charge_t = maxf(0.0, _charge_t - dt)

	var old_mana := mana
	mana = minf(tot_maxmana(), mana + regen * dt)
	if mana != old_mana:
		SignalBus.player_mana_changed.emit(mana, tot_maxmana())
	var old_stam := stamina
	stamina = minf(max_stamina, stamina + STAM_REGEN * dt)
	if stamina != old_stam:
		SignalBus.player_stamina_changed.emit(stamina, max_stamina)

	# fire deferred melee impact when animation reaches the downstroke
	if _atk_hit_t > 0.0 and not dead and atk_cd > 0.0 and atk_t / atk_cd <= _atk_hit_t:
		_atk_hit_t = -1.0
		_resolve_melee_hit()

	if dead:
		return

	# --- blocking / parry ---
	var wants_block := Input.is_action_pressed("parry")
	if wants_block and not _block_prev:
		_parry_t = 0.22
	_block_prev = wants_block
	if wants_block and mana >= 2.0:
		blocking = true
		mana = maxf(0.0, mana - 10.0 * dt)
	else:
		if blocking and mana < 2.0: _msg("Your shield arm gives out!", Color("ff8050"))
		blocking = false

	# --- movement input (isometric camera-relative) ---
	# Keyboard via action map; D-pad via manual tracker (_joy) to avoid HID
	# adapter bug where button-release events are silently dropped on macOS;
	# left stick read directly from the joypad axes for analog controllers
	# (e.g. Stadia over Bluetooth) that don't report a D-pad at all.
	var kb_r := Input.is_action_pressed("move_right")
	var kb_l := Input.is_action_pressed("move_left")
	var kb_b := Input.is_action_pressed("move_back")
	var kb_f := Input.is_action_pressed("move_forward")
	# D-pad button indices confirmed via live debug: 11=up 12=down 13=left 14=right
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() < STICK_DEADZONE:
		stick = Vector2.ZERO
	var ix := clampf(float(kb_r or _joy_btn(14)) - float(kb_l or _joy_btn(13)) + stick.x, -1.0, 1.0)
	var iz := clampf(float(kb_b or _joy_btn(12)) - float(kb_f or _joy_btn(11)) + stick.y, -1.0, 1.0)
	var dir := _iso_basis() * Vector3(ix, 0, iz)
	dir.y = 0
	if dir.length() > 0.001:
		dir = dir.normalized()

	# --- dodge roll ---
	if Input.is_action_just_pressed("dodge") and _dodge_t <= 0.0 and stamina >= STAM_DODGE:
		var atk_committed := atk_cd > 0.0 and atk_t > atk_cd * 0.45
		if not atk_committed:
			_dodge_dir = dir if dir.length_squared() > 0.001 else -transform.basis.z
			_dodge_dir.y = 0
			_dodge_dir = _dodge_dir.normalized()
			_dodge_t = DODGE_DUR + DODGE_CD
			iframe   = DODGE_DUR * 0.7
			stamina  = maxf(0.0, stamina - STAM_DODGE)
			SignalBus.player_stamina_changed.emit(stamina, max_stamina)

	# --- attack (fires on press for immediate feedback) ---
	if Input.is_action_just_pressed("attack") and atk_t <= 0.0:
		_melee()

	# --- facing toward movement ---
	if dir.length() > 0.001:
		var target_angle := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 12.0 * dt)
		_facing_dir = dir

	# --- velocity ---
	var spd := move_speed * (0.55 if blocking else 1.0)
	if _was_dashing:
		velocity.x = _charge_dir.x * (CHARGE_DIST / CHARGE_DUR)
		velocity.z = _charge_dir.z * (CHARGE_DIST / CHARGE_DUR)
	elif _dodge_t > DODGE_CD:
		velocity.x = _dodge_dir.x * DODGE_SPD
		velocity.z = _dodge_dir.z * DODGE_SPD
	else:
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	if _kb_t > 0.0:
		var kf := _kb_t / 0.2
		velocity.x += _kb_vel.x * kf
		velocity.z += _kb_vel.z * kf
	if _backstep_t > 0.0:
		var lf := _backstep_t / BACKSTEP_DUR
		velocity.x += _backstep_vel.x * lf
		velocity.z += _backstep_vel.z * lf
	velocity.y = 0
	move_and_slide()

	if _was_dashing:
		_resolve_charge_hit()

	# --- other actions ---
	if Input.is_action_just_pressed("ability_q"):   _ability_q()
	if Input.is_action_just_pressed("ability_b"):   _ability_b()
	if Input.is_action_just_pressed("heal_potion"): use_hpot()
	if Input.is_action_just_pressed("use_action"):  _on_use_action()
	_update_anim()

# ---------------------------------------------------------------------------
# Combat — melee
# ---------------------------------------------------------------------------

# Autoload may be absent in stripped headless test runs — degrade gracefully.
func _juice() -> Node:
	return get_node_or_null("/root/CombatJuice")

# Small recoil away from the target on a landed hit — sells impact weight and
# keeps combat feeling fluid without the old attack-lunge closing distance.
const BACKSTEP_DUR := 0.12

func _start_backstep(aim: Vector3, strength: float) -> void:
	var cj := _juice()
	if cj == null: return
	_backstep_vel = cj.lunge(-aim, strength)
	_backstep_t   = BACKSTEP_DUR

func _melee() -> void:
	var wdef := _weapon_def()
	var stam_cost := STAM_ATK * float(wdef.get("stam_mult", 1.0))
	if stamina < stam_cost:
		_msg("Too exhausted!", Color("ffb050")); return
	stamina = maxf(0.0, stamina - stam_cost)
	SignalBus.player_stamina_changed.emit(stamina, max_stamina)
	var cd: float = wdef.get("cd", 0.45)
	atk_t = cd; atk_cd = cd
	var dmg := int(round(float(tot_dmg()) * float(wdef.get("dmg_mult", 1.0))))
	var crit_ch: float = CRIT_CHANCE.get(cls, 0.0) + float(wdef.get("crit_bonus", 0.0))
	_pending_crit = crit_ch > 0.0 and randf() < crit_ch
	if _pending_crit: dmg = int(round(float(dmg) * CRIT_MULT.get(cls, 1.5)))
	_pending_dmg = dmg
	_atk_hit_t   = 0.55

func _heavy_melee() -> void:
	var wdef := _weapon_def()
	stamina = maxf(0.0, stamina - STAM_HEAVY * float(wdef.get("stam_mult", 1.0)))
	SignalBus.player_stamina_changed.emit(stamina, max_stamina)
	var cd: float = float(wdef.get("cd", 0.45)) * 1.5
	atk_t = cd; atk_cd = cd
	var dmg := int(round(float(tot_dmg()) * float(wdef.get("dmg_mult", 1.0)) * 1.8))
	_pending_crit = false
	_pending_dmg  = dmg
	_atk_hit_t    = 0.55

const MELEE_REACH_MARGIN := 0.6  # added on top of an enemy's own attack-hold distance
const MELEE_CONE_DOT     := -0.5 # cos(120°): generous soft-lock cone, Dark-Souls-style homing
const MELEE_POINT_BLANK  := 0.75 # inside this, cone is ignored — lunge can overshoot the target
const MELEE_CONE_NARROW  := 0.75 # cos(~41°): spear-like poke, must be roughly dead-on
const MELEE_CONE_WIDE    := -0.2 # cos(~102°): greatsword sweep, generous arc
const MELEE_WIDE_MAX_TARGETS := 3

func _weapon_cone_dot(arc: String) -> float:
	match arc:
		"narrow": return MELEE_CONE_NARROW
		"wide":   return MELEE_CONE_WIDE
		_:        return MELEE_CONE_DOT

func _resolve_melee_hit() -> void:
	# Aim at the intended attack direction: last non-zero move dir if we have
	# one, else current facing. Soft-lock onto the nearest enemy inside a wide
	# cone of that direction rather than requiring an exact facing match — a
	# stationary player swinging at an enemy that's chasing from any angle
	# should still connect. Cone width and target count are weapon-driven
	# (WeaponDB "arc": narrow=spear poke, wide=greatsword sweep hits up to 3).
	var aim := _facing_dir if _facing_dir.length_squared() > 0.001 else (-transform.basis.z)
	aim = aim.normalized()
	var is_heavy   := atk_cd > 0.45 * 1.2
	var is_riposte := _riposte_t > 0.0
	var wdef := _weapon_def()
	var arc: String = wdef.get("arc", "normal")
	var cone_dot := _weapon_cone_dot(arc)
	var reach_bonus: float = wdef.get("reach_bonus", 0.0)
	var stagger_mult: float = wdef.get("stagger_mult", 1.0)
	var kb_mult: float = wdef.get("knockback_mult", 1.0)
	var max_targets := MELEE_WIDE_MAX_TARGETS if arc == "wide" else 1

	# Collect all in-range, in-cone enemies sorted by distance; wide arc can
	# strike several, other arcs take only the nearest.
	var candidates: Array = []
	for en in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = en.global_position - global_position
		to.y = 0
		var dist := to.length()
		var stop_dist: float = en.get("atk_range") if en.get("atk_range") != null else 1.3
		var reach := float(stop_dist) + MELEE_REACH_MARGIN + reach_bonus
		var in_cone := dist < MELEE_POINT_BLANK or aim.dot(to.normalized()) > cone_dot
		if dist < reach and in_cone:
			candidates.append({"en": en, "to": to, "dist": dist})
	candidates.sort_custom(func(a, b) -> bool: return a["dist"] < b["dist"])

	_spawn_swing_trail(wdef, aim)

	if candidates.is_empty():
		return

	var hit_any := false
	for i in range(mini(max_targets, candidates.size())):
		var c: Dictionary = candidates[i]
		var target: Node = c["en"]
		var target_to: Vector3 = c["to"]
		hit_any = true

		var dmg := _pending_dmg + randi_range(0, 4)
		if is_riposte: dmg = int(round(float(dmg) * 3.0))
		target.take_damage(dmg, stagger_mult)
		if target.has_method("_apply_knockback"):
			target._apply_knockback(target_to.normalized() * (5.5 if is_heavy else 3.5) * kb_mult)
		if is_heavy and target.has_method("_force_stagger"):
			target._force_stagger()

		var cj := _juice()
		if cj != null:
			var big := is_heavy or is_riposte
			if big: cj.hit_stop(0.12, 0.03)
			else:   cj.hit_stop()
			var ring_parent: Node3D = get_tree().current_scene as Node3D
			if ring_parent == null: ring_parent = target.get_parent() as Node3D
			if ring_parent != null:
				var ring_col := Color(1.0, 0.3, 0.15) if big else Color(1.0, 0.85, 0.4)
				cj.impact_ring(ring_parent, target.global_position, ring_col)

	if not hit_any:
		return

	_start_backstep(aim, 2.2 if not is_heavy else 3.0)
	if is_riposte: _riposte_t = 0.0
	if is_riposte:      _msg("RIPOSTE!", Color("ff9a20"))
	elif _pending_crit: _msg("Critical Strike!", Color("ffce42"))
	elif is_heavy:      _msg("Heavy Strike!", Color("e08020"))
	_apply_camera_shake(0.035 + (0.04 if _pending_crit or is_riposte else 0.0))

# Pure-visual ghost-copy trail matching the equipped weapon's swing shape
# (WeaponDB "trail": "arc" default or "thrust" for spear/dagger pokes). Fired
# from the same deferred-hit release point as the actual damage resolution
# but never touches damage/hit logic — see SwingTrail.gd.
func _spawn_swing_trail(wdef: Dictionary, aim: Vector3) -> void:
	var shape: String = wdef.get("trail", "arc")
	if shape == "thrust":
		SwingTrail.spawn_thrust(get_tree(), _sprite, _weapon_overlay, global_position, aim)
	else:
		SwingTrail.spawn_arc(get_tree(), _sprite, _weapon_overlay, global_position, aim)

# ---------------------------------------------------------------------------
# Abilities (warrior stubs — expand later)
# ---------------------------------------------------------------------------

func _ability_q() -> void:
	if level < WW_LEVEL:
		_msg("Whirlwind needs level %d." % WW_LEVEL, Color("ff7050")); return
	if _ww_cd > 0.0:
		_msg("Whirlwind is cooling down.", Color("ff7050")); return
	if mana < WW_MANA or stamina < WW_STAM:
		_msg("Not enough mana/stamina for Whirlwind!", Color("ff7050")); return

	mana    = maxf(0.0, mana - WW_MANA)
	stamina = maxf(0.0, stamina - WW_STAM)
	SignalBus.player_mana_changed.emit(mana, tot_maxmana())
	SignalBus.player_stamina_changed.emit(stamina, max_stamina)
	_ww_cd = WW_CD

	var dmg := int(round(float(tot_dmg()) * WW_DMG_MULT * float(_weapon_def().get("dmg_mult", 1.0))))
	var hits := 0
	for en in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = en.global_position - global_position
		to.y = 0
		if to.length() > WW_RADIUS:
			continue
		en.take_damage(dmg)
		if en.has_method("_apply_knockback"):
			en._apply_knockback(to.normalized() * 6.0)
		hits += 1

	var cj := _juice()
	var ring_parent: Node3D = get_tree().current_scene as Node3D
	if ring_parent == null: ring_parent = get_parent() as Node3D
	if hits > 0 and cj != null:
		cj.hit_stop(0.09, 0.04)
	if cj != null and ring_parent != null:
		cj.impact_ring(ring_parent, global_position, Color(0.6, 0.85, 1.0))
		get_tree().create_timer(0.08).timeout.connect(func() -> void:
			if is_instance_valid(self) and ring_parent != null and is_instance_valid(ring_parent):
				cj.impact_ring(ring_parent, global_position, Color(0.75, 0.92, 1.0)))
	_spin_sprite()
	SwingTrail.spawn_arc(get_tree(), _sprite, _weapon_overlay, global_position,
		_facing_dir if _facing_dir.length_squared() > 0.001 else Vector3.FORWARD,
		Color(0.75, 0.9, 1.0), true)
	_apply_camera_shake(0.05)
	_msg("Whirlwind!", Color("a0c8ff"))

# Full 360° visual flourish — billboard sprites can't rotate in Y, so fake
# spin with a fast horizontal-flip flicker layered on a scale pulse.
func _spin_sprite() -> void:
	if _sprite == null: return
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", _sprite.scale * 1.35, 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sprite, "scale", _sprite.scale, 0.18).set_trans(Tween.TRANS_SINE)
	var flips := 4
	for i in range(flips):
		var t := (i + 1) * (0.35 / flips)
		get_tree().create_timer(t).timeout.connect(func() -> void:
			if is_instance_valid(_sprite): _sprite.flip_h = not _sprite.flip_h)

func _ability_b() -> void:
	if level < CHARGE_LEVEL:
		_msg("Charge needs level %d." % CHARGE_LEVEL, Color("ff7050")); return
	if _charge_cd > 0.0:
		_msg("Charge is cooling down.", Color("ff7050")); return
	if mana < CHARGE_MANA or stamina < CHARGE_STAM:
		_msg("Not enough mana/stamina for Charge!", Color("ff7050")); return

	mana    = maxf(0.0, mana - CHARGE_MANA)
	stamina = maxf(0.0, stamina - CHARGE_STAM)
	SignalBus.player_mana_changed.emit(mana, tot_maxmana())
	SignalBus.player_stamina_changed.emit(stamina, max_stamina)
	_charge_cd = CHARGE_CD

	_charge_dir  = _facing_dir.normalized() if _facing_dir.length_squared() > 0.001 else -transform.basis.z
	_charge_dir.y = 0.0
	_charge_t    = CHARGE_DUR
	_charge_hit  = false
	iframe       = maxf(iframe, CHARGE_DUR)
	_spawn_charge_trail()
	_msg("Charge!", Color("a0c8ff"))

const CHARGE_HIT_RANGE := 0.9

func _resolve_charge_hit() -> void:
	if _charge_hit: return
	for en in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = en.global_position - global_position
		to.y = 0
		if to.length() > CHARGE_HIT_RANGE:
			continue
		_charge_hit = true
		var dmg := int(round(float(tot_dmg()) * CHARGE_DMG_MULT * float(_weapon_def().get("dmg_mult", 1.0))))
		en.take_damage(dmg)
		if en.has_method("_apply_knockback"):
			en._apply_knockback(to.normalized() * 7.5)
		if en.has_method("_force_stagger"):
			en._force_stagger()
		_charge_t = 0.0  # dash ends on hit
		var cj := _juice()
		if cj != null:
			cj.hit_stop(0.11, 0.03)
			var ring_parent: Node3D = get_tree().current_scene as Node3D
			if ring_parent == null: ring_parent = en.get_parent() as Node3D
			if ring_parent != null:
				cj.impact_ring(ring_parent, en.global_position, Color(1.0, 0.55, 0.2))
		_apply_camera_shake(0.06)
		return

# Cheap ghost trail: duplicate the sprite's texture as a fading, stretched
# billboard dropped a few times over the dash — avoids GPUParticles setup cost.
func _spawn_charge_trail() -> void:
	if _sprite == null: return
	var steps := 4
	for i in range(steps):
		var delay := i * (CHARGE_DUR / steps)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if not is_instance_valid(self) or _sprite == null: return
			var ghost := Sprite3D.new()
			ghost.texture = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame) \
				if _sprite.sprite_frames != null else null
			if ghost.texture == null:
				ghost.queue_free(); return
			ghost.pixel_size = _sprite.pixel_size
			ghost.billboard = _sprite.billboard
			ghost.flip_h = _sprite.flip_h
			ghost.modulate = Color(0.6, 0.8, 1.0, 0.45)
			ghost.top_level = true
			var parent: Node3D = get_tree().current_scene as Node3D
			if parent == null: parent = get_parent() as Node3D
			if parent == null: ghost.queue_free(); return
			parent.add_child(ghost)
			ghost.global_position = _sprite.global_position
			var tw := ghost.create_tween()
			tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
			tw.tween_callback(ghost.queue_free))

func _on_use_action() -> void:
	# TODO: interact with world objects
	pass

# ---------------------------------------------------------------------------
# Damage / heal
# ---------------------------------------------------------------------------

func take_damage(amt: int, src := "") -> void:
	if dead or iframe > 0.0: return
	if _parry_t > 0.0 and blocking:
		_parry_t   = 0.0
		_riposte_t = 1.5
		_apply_camera_shake(0.015)
		_msg("Parried! Riposte ready.", Color("ffe050"))
		return
	var armor := tot_armor()
	var dr    := float(armor) / (float(armor) + 25.0)
	amt = max(1, int(round(float(amt) * (1.0 - dr))))
	if blocking:
		amt  = int(ceil(amt * 0.3))
		mana = maxf(0.0, mana - 5.0)
	hp     -= amt
	hurt_t  = 0.4
	_flash_hit()
	_apply_camera_shake(0.04 + clampf(float(amt) / 60.0, 0.0, 0.06))
	SignalBus.player_health_changed.emit(int(hp), int(maxhp))
	if hp <= 0.0:
		hp   = 0.0
		dead = true
		if _sprite != null:
			_sprite.play("death")
		_msg("You have fallen to %s." % src, Color("e03c2c"))
		SignalBus.player_died.emit()

func heal(amt: int) -> void:
	hp = minf(tot_maxhp(), hp + amt)
	SignalBus.player_health_changed.emit(int(hp), int(maxhp))

func add_gold(amt: int) -> void:
	gold += amt

func restore_mana(amt: float) -> void:
	mana = minf(mana + amt, 100.0)

func _flash_hit() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.14)

# ---------------------------------------------------------------------------
# Camera shake
# ---------------------------------------------------------------------------

func _apply_camera_shake(mag: float) -> void:
	SignalBus.screen_shake.emit(mag)

# ---------------------------------------------------------------------------
# Knockback
# ---------------------------------------------------------------------------

func _apply_knockback(impulse: Vector3) -> void:
	_kb_vel = impulse
	_kb_t   = 0.2

# ---------------------------------------------------------------------------
# Sprite animation
# ---------------------------------------------------------------------------

func _update_anim() -> void:
	if _sprite == null or dead:
		return
	var want: String
	# Fast weapons (e.g. dagger, cd 0.25s) have a shorter cooldown than the
	# attack animation's natural playback time (3 frames @ 8fps = 0.375s), so
	# atk_t can hit 0 before the sprite has reached its last frame. Gating
	# purely on atk_t > 0 would yank the animation back to idle/walk mid-swing
	# — the weapon overlay (and the baked sword) would visibly vanish right
	# when the strike should read. Once "attack" starts, stay on it until the
	# sprite itself reports done playing, not just until the cooldown timer
	# says so.
	var attack_finished := _sprite.animation == "attack" and not _sprite.is_playing()
	if hurt_t > 0.2:
		want = "hurt"
	elif atk_t > 0.0 or (_sprite.animation == "attack" and not attack_finished):
		want = "attack"
	elif Vector3(velocity.x, 0.0, velocity.z).length() > 0.1:
		want = "walk"
	else:
		want = "idle"
	if _sprite.animation != want:
		_sprite.play(want)
	# Flip sprite left/right from _facing_dir (last movement INTENT), not raw
	# velocity — velocity picks up knockback/lunge/collision components that
	# briefly point the wrong way and flipped the resting pose (and with it the
	# weapon overlay) to the right after walking left. _facing_dir persists
	# when input stops, so the resting pose keeps the last walk direction and
	# always agrees with where melee aims.
	# Camera is fixed at 45° yaw; its right vector in world space is (0.707, 0, -0.707).
	var screen_x := _facing_dir.dot(Vector3(0.707, 0.0, -0.707))
	var art_faces_left := ART_FACES_LEFT
	if want == "walk":
		art_faces_left = WALK_FACES_LEFT
	elif want == "attack":
		art_faces_left = ATTACK_FACES_LEFT
	if screen_x < -0.05:
		_sprite.flip_h = not art_faces_left   # facing screen-left: flip only if art natively faces right
	elif screen_x > 0.05:
		_sprite.flip_h = art_faces_left       # facing screen-right: flip only if art natively faces left

# ---------------------------------------------------------------------------
# HUD message helper
# ---------------------------------------------------------------------------

func _msg(text: String, _c: Color) -> void:
	SignalBus.hud_message.emit(text, 2.5)
