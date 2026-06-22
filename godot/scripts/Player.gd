extends CharacterBody3D
class_name Player
## First-person controller + combat. WASD move, mouse-look, click/Space to
## attack, F secondary, Q ability, B mobility — dispatched per class, ported
## from the web build's primaryFire/secondaryFire/abilityQ/abilityB.

@export var look_sens := 0.0032

var cls := "war"
var def: Dictionary = {}
var yaw := 0.0
var pitch := 0.0
var cam: Camera3D

var maxhp := 100.0
var hp := 100.0
var maxmana := 50.0
var mana := 50.0
var base_dmg := 16
var base_spell := 0
var regen := 1.5
var level := 1
var xp := 0
var dead := false
var blocking := false

var gold := 0
var keys := 0
var hpots := 1
var mpots := 1
var meat := 1
var food := 100.0
var kills := 0
var equip := {"weapon": null, "armor": null, "helm": null, "ring": null}
var bag: Array = []
var _hunger_acc := 0.0

var atk_t := 0.0
var cast_t := 0.0
var atk_cd := 0.0   # cooldown duration set when melee fires — lets HUD normalize swing time
var cast_cd := 0.0  # cooldown duration set when cast fires
var abil_t := 0.0
var ab2_t := 0.0
var iframe := 0.0
var hurt_t := 0.0
var shake_t := 0.0
var _shake_mag := 0.0
var _shake_x := 0.0
var _shake_y := 0.0
var _kb_t := 0.0
var _kb_vel := Vector3.ZERO
var _atk_hit_t := -1.0
var _pending_dmg := 0
var _pending_crit := false

# stamina
var stamina    := 100.0
var max_stamina := 100.0

# dodge roll (T2)
var _dodge_t   := 0.0
var _dodge_dir := Vector3.ZERO

# heavy attack hold (T7)
var _hold_t      := 0.0
var _hold_armed  := false

# parry / riposte (T6)
var _parry_t    := 0.0
var _riposte_t  := 0.0
var _block_prev := false

const SPEED := 4.2
const CRIT_CHANCE := {"war": 0.10, "paladin": 0.08, "rogue": 0.30}
const CRIT_MULT   := {"war": 1.8,  "paladin": 1.6,  "rogue": 2.5}

const STAM_REGEN  := 18.0   # per second (idle)
const STAM_ATK    := 22.0   # normal melee swing
const STAM_DODGE  := 30.0   # dodge roll
const STAM_HEAVY  := 42.0   # heavy attack
const DODGE_DUR   := 0.28   # active i-frame window
const DODGE_CD    := 0.55   # total lockout after roll ends
const DODGE_SPD   := 9.0
const HEAVY_HOLD  := 0.50   # seconds of hold to arm heavy

func _ready() -> void:
	def = Classes.get_def(cls)
	maxhp = float(def.hp); hp = maxhp
	maxmana = float(def.mp); mana = maxmana
	base_dmg = int(def.dmg); base_spell = int(def.spell)
	regen = float(def.regen)
	hpots = int(def.hpots); mpots = int(def.mpots); meat = 1
	add_to_group("player")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.4
	col.shape = cap
	add_child(col)
	cam = Camera3D.new()
	cam.position = Vector3(0, 0.55, 0)
	cam.fov = 90
	add_child(cam)
	if not OS.has_feature("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func gear_sum(stat: String) -> int:
	var s := 0
	for k in equip:
		var g = equip[k]
		if g != null:
			s += int(g["b"].get(stat, 0))
	return s
func tot_dmg() -> int: return base_dmg + gear_sum("dmg")
func tot_spell() -> int: return base_spell + gear_sum("spell")
func tot_maxhp() -> int: return int(maxhp) + gear_sum("hp")
func tot_maxmana() -> int: return int(maxmana) + gear_sum("mana")
func tot_armor() -> int: return gear_sum("armor")

func add_gear(g: Dictionary) -> bool:
	if bag.size() >= 6: return false
	bag.append(g); return true
func equip_from_bag(i: int) -> void:
	if i < 0 or i >= bag.size(): return
	var g = bag[i]
	var slot = g["slot"]
	var cur = equip[slot]
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

func use_hpot() -> void:
	if dead: return
	if hpots <= 0: _msg("No health potions left!", Color("ff7050")); return
	hpots -= 1; hp = minf(tot_maxhp(), hp + 45)
	if Game.instance.hud: Game.instance.hud.flash(Color(0.3, 0.8, 0.35, 0.25))
	_msg("You quaff a health potion. (+45)", Color("ff9a8a"))
func use_mpot() -> void:
	if dead: return
	if mpots <= 0: _msg("No mana potions left!", Color("ff7050")); return
	mpots -= 1; mana = minf(tot_maxmana(), mana + 40)
	_msg("You quaff a mana potion. (+40)", Color("8ab8ff"))
func eat() -> void:
	if dead: return
	if meat <= 0: _msg("You have nothing to eat!", Color("ff7050")); return
	meat -= 1; food = minf(100.0, food + 38.0)
	_msg("You devour a haunch of boar. Mm.", Color("d8a868"))
func grant(kind: String, amt: int, gear) -> void:
	match kind:
		"gold": gold += amt; _msg("+%d gold" % amt, Color("ffd84a"))
		"hpot": hpots += 1; _msg("Picked up a health potion. (H)", Color("ff9a8a"))
		"mpot": mpots += 1; _msg("Picked up a mana potion. (M)", Color("8ab8ff"))
		"meat": meat += 1; _msg("Picked up a haunch of meat. (G)", Color("d8a868"))
		"key": keys += 1; _msg("You found a vault key!", Color("ffce42"))
		"gear":
			if gear and add_gear(gear):
				_msg("You found %s. (I)" % gear["name"], GearDB.tier_color(int(gear["tier"])))

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * look_sens
		pitch = clampf(pitch - e.relative.y * look_sens, -1.35, 1.35)
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(dt: float) -> void:
	atk_t   = maxf(0.0, atk_t - dt)
	cast_t  = maxf(0.0, cast_t - dt)
	abil_t  = maxf(0.0, abil_t - dt)
	ab2_t   = maxf(0.0, ab2_t - dt)
	iframe  = maxf(0.0, iframe - dt)
	hurt_t  = maxf(0.0, hurt_t - dt)
	_kb_t   = maxf(0.0, _kb_t - dt)
	shake_t = maxf(0.0, shake_t - dt)
	_dodge_t = maxf(0.0, _dodge_t - dt)
	_parry_t = maxf(0.0, _parry_t - dt)
	_riposte_t = maxf(0.0, _riposte_t - dt)
	mana = minf(tot_maxmana(), mana + regen * dt)
	stamina = minf(max_stamina, stamina + STAM_REGEN * dt)

	# fire deferred melee impact when animation reaches the downstroke
	if _atk_hit_t > 0.0 and not dead and atk_cd > 0.0 and atk_t / atk_cd <= _atk_hit_t:
		_atk_hit_t = -1.0
		_resolve_melee_hit()

	if Input.is_action_pressed("turn_left"): yaw += 2.4 * dt
	if Input.is_action_pressed("turn_right"): yaw -= 2.4 * dt
	rotation.y = yaw
	if cam:
		if shake_t > 0.0:
			var s := (shake_t / 0.35) * _shake_mag
			_shake_x = lerpf(_shake_x, randf_range(-s, s), 0.5)
			_shake_y = lerpf(_shake_y, randf_range(-s * 0.6, s * 0.6), 0.5)
		else:
			_shake_mag = 0.0
			_shake_x = lerpf(_shake_x, 0.0, 15.0 * dt)
			_shake_y = lerpf(_shake_y, 0.0, 15.0 * dt)
		cam.rotation.x = pitch + _shake_x
		cam.rotation.y = _shake_y

	var ui_open: bool = Game.instance and ((Game.instance.inv_ui and Game.instance.inv_ui.is_open) or (Game.instance.shop_ui and Game.instance.shop_ui.is_open))
	var wants_block := cls == "war" and Input.is_action_pressed("secondary") and not dead and not ui_open
	# parry window opens on the leading edge of block
	if wants_block and not _block_prev and not dead:
		_parry_t = 0.22
	_block_prev = wants_block
	if wants_block and mana >= 2.0:
		blocking = true
		mana = maxf(0.0, mana - 10.0 * dt)
	else:
		if blocking and mana < 2.0: _msg("Your shield arm gives out!", Color("ff8050"))
		blocking = false

	if not dead and not ui_open:
		var ix := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		var iz := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
		var dir := transform.basis * Vector3(ix, 0, iz)
		dir.y = 0
		if dir.length() > 0.001: dir = dir.normalized()

		# dodge roll: T2 + T3 (locked during first 55% of attack arc)
		if Input.is_action_just_pressed("dodge") and _dodge_t <= 0.0 and stamina >= STAM_DODGE:
			var atk_committed := atk_cd > 0.0 and atk_t > atk_cd * 0.45
			if not atk_committed:
				_dodge_dir = dir if dir.length_squared() > 0.001 else -transform.basis.z
				_dodge_dir.y = 0
				_dodge_dir = _dodge_dir.normalized()
				_dodge_t = DODGE_DUR + DODGE_CD
				iframe = DODGE_DUR * 0.7
				stamina = maxf(0.0, stamina - STAM_DODGE)

		# heavy attack hold tracking (melee classes only)
		var is_melee_cls := cls == "war" or cls == "paladin" or cls == "rogue"
		if is_melee_cls and atk_t <= 0.0:
			if Input.is_action_pressed("attack"):
				_hold_t += dt
				if _hold_t >= HEAVY_HOLD and not _hold_armed:
					_hold_armed = true
					_msg("Heavy!", Color("ffce42"))
			if Input.is_action_just_released("attack"):
				if _hold_armed and stamina >= STAM_HEAVY:
					_heavy_melee()
				elif _hold_t < HEAVY_HOLD:
					_primary()
				_hold_t = 0.0; _hold_armed = false
		elif not is_melee_cls:
			if Input.is_action_pressed("attack"): _primary()

		var spd := SPEED * (0.55 if blocking else 1.0)
		# during dodge: override velocity with dodge direction
		if _dodge_t > DODGE_CD:
			velocity.x = _dodge_dir.x * DODGE_SPD
			velocity.z = _dodge_dir.z * DODGE_SPD
		else:
			velocity.x = dir.x * spd
			velocity.z = dir.z * spd
		if _kb_t > 0.0:
			var kf := _kb_t / 0.2
			velocity.x += _kb_vel.x * kf
			velocity.z += _kb_vel.z * kf
		velocity.y = 0
		move_and_slide()

		if Input.is_action_pressed("secondary") and cls != "war": _secondary()
		if Input.is_action_just_pressed("ability_q"): _ability_q()
		if Input.is_action_just_pressed("ability_b"): _ability_b()
		if Input.is_action_just_pressed("heal_potion"): use_hpot()
		if Input.is_action_just_pressed("mana_potion"): use_mpot()
		if Input.is_action_just_pressed("eat"): eat()
		_hunger_acc += dt
		if _hunger_acc > 3.0:
			_hunger_acc -= 3.0
			food = maxf(0.0, food - 1.0)
			if food == 30.0: _msg("Your stomach growls. (G to eat)", Color("d8a868"))
			elif food == 10.0: _msg("You are famished!", Color("ff7050"))
			elif food <= 0.0: take_damage(3, "starvation")

func _aim() -> Vector3:
	return (-cam.global_transform.basis.z).normalized()

func _shoot(kind: String, dmg: int) -> void:
	var from := global_position + cam.position + _aim() * 0.4
	Game.instance.spawn_projectile("player", from, _aim(), kind, dmg, self)

func _proj_dmg(kind: String) -> int:
	var d: Dictionary = Classes.proj.get(kind, {})
	match d.get("dmg_kind", "dmg"):
		"spell": return tot_spell()
		"dmg2": return tot_dmg() * 2 + int(d.get("dmg_add", 0))
		_: return tot_dmg() + int(d.get("dmg_add", 0))

func _cast(kind: String) -> void:
	var d: Dictionary = Classes.proj.get(kind, {})
	var cost := int(d.get("cost", 0))
	if mana < cost:
		_msg("Not enough %s!" % def.res.to_lower(), Color("8ab8ff")); return
	mana -= cost
	cast_t = float(d.get("cd", 0.4)); cast_cd = cast_t
	_shoot(kind, _proj_dmg(kind))

func _melee() -> void:
	if stamina < STAM_ATK:
		_msg("Too exhausted!", Color("ffb050")); return
	stamina = maxf(0.0, stamina - STAM_ATK)
	var cd: float = Classes.melee_cd.get(cls, 0.45)
	atk_t = cd; atk_cd = cd
	var dmg := tot_dmg()
	var crit_ch: float = CRIT_CHANCE.get(cls, 0.0)
	_pending_crit = crit_ch > 0.0 and randf() < crit_ch
	if _pending_crit: dmg = int(round(float(dmg) * CRIT_MULT.get(cls, 1.5)))
	_pending_dmg = dmg
	# defer impact to the downstroke: 0.55 = slash peak, 0.35 = rogue undercut peak
	_atk_hit_t = 0.35 if cls == "rogue" else 0.55

func _heavy_melee() -> void:
	stamina = maxf(0.0, stamina - STAM_HEAVY)
	var cd: float = Classes.melee_cd.get(cls, 0.45) * 1.5
	atk_t = cd; atk_cd = cd
	var dmg := int(round(float(tot_dmg()) * 1.8))
	_pending_crit = false
	_pending_dmg = dmg
	_atk_hit_t = 0.35 if cls == "rogue" else 0.55

func _resolve_melee_hit() -> void:
	var fwd := _aim()
	var hit_any := false
	var is_heavy: bool = atk_cd > float(Classes.melee_cd.get(cls, 0.45)) * 1.2
	var is_riposte := _riposte_t > 0.0
	for en in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = en.global_position - global_position
		to.y = 0
		if to.length() < 1.9 and fwd.dot(to.normalized()) > 0.55:
			var dmg := _pending_dmg + Util.li(0, 4)
			if is_riposte: dmg = int(round(float(dmg) * 3.0))
			en.take_damage(dmg)
			en._apply_knockback(to.normalized() * (5.5 if is_heavy else 3.5))
			if cls == "war" or cls == "rogue":
				en._bleed_stacks = mini(en._bleed_stacks + 1, 3)
				en._bleed_t = 3.0; en._bleed_tick = 0.0
			if is_heavy and en.has_method("_force_stagger"):
				en._force_stagger()
			hit_any = true
	if is_riposte: _riposte_t = 0.0
	if hit_any:
		if is_riposte: _msg("RIPOSTE!", Color("ff9a20"))
		elif _pending_crit: _msg("Critical Strike!", Color("ffce42"))
		elif is_heavy: _msg("Heavy Strike!", Color("e08020"))
		_apply_camera_shake(0.035 + (0.04 if _pending_crit or is_riposte else 0.0))

func _primary() -> void:
	match cls:
		"war", "paladin", "rogue":
			if atk_t <= 0.0: _melee()
		"mage":
			if cast_t <= 0.0: _cast("fire")
		"hunter":
			if cast_t <= 0.0: _cast("arrow")
		"warlock":
			if cast_t <= 0.0: _cast("shadow")

func _secondary() -> void:
	match cls:
		"mage":
			if cast_t <= 0.0: _cast("fire")
		"hunter":
			if cast_t <= 0.0: _cast("power")
		"warlock":
			if cast_t <= 0.0: _cast("shadow")
		"rogue":
			if cast_t <= 0.0: _cast("dagger")
		"paladin":
			_holy_light()

func _aoe_dmg(key: String) -> int:
	var a: Dictionary = Classes.aoe[key]
	match a.dmg_kind:
		"spell_half": return int(a.dmg_add) + int(tot_spell() / 2.0)
		"spell_56": return int(a.dmg_add) + int(tot_spell() * 5.0 / 6.0)
		_: return int(round(tot_dmg() * float(a.get("dmg_mul", 1.0)))) + int(a.get("dmg_add", 0))

func _cast_aoe(key: String) -> void:
	if abil_t > 0.0: return
	var a: Dictionary = Classes.aoe[key]
	if mana < int(a.res):
		_msg("Not enough %s!" % def.res.to_lower(), Color("8ab8ff")); return
	mana -= int(a.res)
	abil_t = float(a.cd)
	Game.instance.do_aoe(global_position, float(a.r) + 0.5, _aoe_dmg(key), float(a.slow), Painter.hex(a.col))
	_msg(a.name, Painter.hex(a.col))

func _multishot() -> void:
	if cast_t > 0.0: return
	if mana < 14:
		_msg("Not enough focus!", Color("8ab8ff")); return
	mana -= 14; cast_t = 0.4
	var dmg := int(round((tot_dmg() + 4) * 0.8))
	for off in [-0.34, -0.17, 0.0, 0.17, 0.34]:
		var dir := _aim().rotated(Vector3.UP, off)
		var from := global_position + cam.position + dir * 0.4
		Game.instance.spawn_projectile("player", from, dir, "arrow", dmg, self)
	_msg("Multishot!", Color("caa070"))

func _ability_q() -> void:
	match cls:
		"war": _cast_aoe("whirl")
		"mage": _cast_aoe("nova")
		"paladin": _cast_aoe("conse")
		"rogue": _cast_aoe("fan")
		"warlock": _cast_aoe("hellf")
		"hunter": _multishot()

func _ability_b() -> void:
	match cls:
		"paladin":
			if ab2_t <= 0.0:
				ab2_t = 12.0; iframe = 2.4; _msg("Divine Shield!", Color("ffe48a"))
		"war": _dash(4.2, 14, 2.0, 0.25, "Charge!")
		"mage": _dash(3.4, 10, 0.4, 0.0, "Blink")
		"hunter": _dash(2.6, 12, 1.2, 0.35, "Roll!")
		"rogue": _dash(4.5, 12, 1.4, 0.25, "Shadowstep!")
		"warlock": _dash(3.6, 14, 1.6, 0.2, "Shadowstep!")

func _dash(reach: float, cost: int, cd: float, ifr: float, label: String) -> void:
	if ab2_t > 0.0: return
	if mana < cost:
		_msg("Not enough %s!" % def.res.to_lower(), Color("8ab8ff")); return
	var step := _aim() * 0.2
	var dest := global_position
	for i in range(int(reach / 0.2)):
		if Game.instance.is_wall(dest + step * 1.6):
			break
		dest += step
	if dest.distance_to(global_position) < 0.3: return
	mana -= cost; ab2_t = cd
	if ifr > 0.0: iframe = ifr
	global_position = dest
	_msg(label, Color("9adfff"))

func _holy_light() -> void:
	if cast_t > 0.0: return
	if mana < 16:
		_msg("Not enough faith!", Color("8ab8ff")); return
	mana -= 16; cast_t = 0.5
	hp = minf(tot_maxhp(), hp + 42)
	if Game.instance.hud: Game.instance.hud.flash(Color(0.3, 0.8, 0.35, 0.25))
	_msg("Holy Light mends you. (+42)", Color("ffe48a"))

func take_damage(amt: int, src := "") -> void:
	if dead or iframe > 0.0: return
	# parry: block raised within the last 0.22s deflects the hit entirely
	if _parry_t > 0.0 and blocking:
		_parry_t = 0.0
		_riposte_t = 1.5
		_apply_camera_shake(0.015)
		if Game.instance and Game.instance.hud:
			Game.instance.hud.flash(Color(1.0, 0.85, 0.1, 0.45))
		_msg("Parried! Riposte ready.", Color("ffe050"))
		return
	var armor := tot_armor()
	var dr := float(armor) / (float(armor) + 25.0)
	amt = max(1, int(round(float(amt) * (1.0 - dr))))
	if blocking:
		amt = int(ceil(amt * 0.3))
		mana = maxf(0.0, mana - 5.0)
	hp -= amt
	hurt_t = 0.4
	_apply_camera_shake(0.04 + clampf(float(amt) / 60.0, 0.0, 0.06))
	if Game.instance.hud: Game.instance.hud.flash(Color(0.75, 0.05, 0.05, 0.4))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		_msg("You have fallen to %s." % src, Color("e03c2c"))
		if Game.instance: Game.instance.on_player_death(src)
		if Game.instance.hud: Game.instance.hud.show_death(src)

func heal(amt: int) -> void:
	hp = minf(tot_maxhp(), hp + amt)

func gain_xp(amt: int) -> void:
	xp += amt
	while xp >= level * 100:
		xp -= level * 100
		level += 1
		maxhp += int(def.hp_lv); maxmana += int(def.mp_lv)
		base_dmg += int(def.dmg_lv); base_spell += int(def.spell_lv)
		hp = tot_maxhp(); mana = tot_maxmana()
		_msg("You reach level %d!" % level, Color("ffce42"))

func _msg(t: String, c: Color) -> void:
	if Game.instance and Game.instance.hud:
		Game.instance.hud.message(t, c)

func _apply_camera_shake(mag: float) -> void:
	shake_t = 0.35
	_shake_mag = maxf(_shake_mag, mag)

func _apply_knockback(impulse: Vector3) -> void:
	_kb_vel = impulse
	_kb_t = 0.2
