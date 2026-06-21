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

var atk_t := 0.0
var cast_t := 0.0
var abil_t := 0.0
var ab2_t := 0.0
var iframe := 0.0
var hurt_t := 0.0

const SPEED := 4.2

func _ready() -> void:
	def = Classes.get_def(cls)
	maxhp = float(def.hp); hp = maxhp
	maxmana = float(def.mp); mana = maxmana
	base_dmg = int(def.dmg); base_spell = int(def.spell)
	regen = float(def.regen)
	add_to_group("player")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.4
	col.shape = cap
	add_child(col)
	cam = Camera3D.new()
	cam.position = Vector3(0, 0.55, 0)
	cam.fov = 78
	add_child(cam)
	if not OS.has_feature("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func tot_dmg() -> int: return base_dmg
func tot_spell() -> int: return base_spell

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * look_sens
		pitch = clampf(pitch - e.relative.y * look_sens, -1.35, 1.35)
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(dt: float) -> void:
	atk_t = maxf(0.0, atk_t - dt)
	cast_t = maxf(0.0, cast_t - dt)
	abil_t = maxf(0.0, abil_t - dt)
	ab2_t = maxf(0.0, ab2_t - dt)
	iframe = maxf(0.0, iframe - dt)
	hurt_t = maxf(0.0, hurt_t - dt)
	mana = minf(maxmana, mana + regen * dt)

	if Input.is_action_pressed("turn_left"): yaw += 2.4 * dt
	if Input.is_action_pressed("turn_right"): yaw -= 2.4 * dt
	rotation.y = yaw
	if cam: cam.rotation.x = pitch

	blocking = cls == "war" and Input.is_action_pressed("secondary") and not dead

	if not dead:
		var ix := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		var iz := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
		var dir := transform.basis * Vector3(ix, 0, iz)
		dir.y = 0
		if dir.length() > 0.001: dir = dir.normalized()
		var spd := SPEED * (0.55 if blocking else 1.0)
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		velocity.y = 0
		move_and_slide()

		if Input.is_action_pressed("attack"): _primary()
		if Input.is_action_pressed("secondary") and cls != "war": _secondary()
		if Input.is_action_just_pressed("ability_q"): _ability_q()
		if Input.is_action_just_pressed("ability_b"): _ability_b()

func _aim() -> Vector3:
	return (-global_transform.basis.z).normalized()

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
	cast_t = float(d.get("cd", 0.4))
	_shoot(kind, _proj_dmg(kind))

func _melee() -> void:
	var cd: float = {"war": 0.42, "paladin": 0.52, "rogue": 0.3}.get(cls, 0.45)
	atk_t = cd
	var dmg := tot_dmg()
	if cls == "rogue" and randf() < 0.25: dmg *= 2
	var fwd := _aim()
	for en in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = en.global_position - global_position
		to.y = 0
		if to.length() < 1.9 and fwd.dot(to.normalized()) > 0.55:
			en.take_damage(dmg + Util.li(0, 4))

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
	hp = minf(maxhp, hp + 42)
	if Game.instance.hud: Game.instance.hud.flash(Color(0.3, 0.8, 0.35, 0.25))
	_msg("Holy Light mends you. (+42)", Color("ffe48a"))

func take_damage(amt: int, src := "") -> void:
	if dead or iframe > 0.0: return
	if blocking: amt = int(ceil(amt * 0.3))
	hp -= amt
	hurt_t = 0.4
	if Game.instance.hud: Game.instance.hud.flash(Color(0.75, 0.05, 0.05, 0.4))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		_msg("You have fallen to %s." % src, Color("e03c2c"))
		if Game.instance.hud: Game.instance.hud.show_death(src)

func heal(amt: int) -> void:
	hp = minf(maxhp, hp + amt)

func gain_xp(amt: int) -> void:
	xp += amt
	while xp >= level * 100:
		xp -= level * 100
		level += 1
		maxhp += int(def.hp_lv); maxmana += int(def.mp_lv)
		base_dmg += int(def.dmg_lv); base_spell += int(def.spell_lv)
		hp = maxhp; mana = maxmana
		_msg("You reach level %d!" % level, Color("ffce42"))

func _msg(t: String, c: Color) -> void:
	if Game.instance and Game.instance.hud:
		Game.instance.hud.message(t, c)
