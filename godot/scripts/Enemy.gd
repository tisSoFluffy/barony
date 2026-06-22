extends CharacterBody3D
class_name Enemy
## Billboard enemy with chase/attack AI, ported in spirit from the web build:
## wakes on sight+LOS, chases the player and melees in range; ranged types
## (troll/necro) keep their distance and fire projectiles.

var type := "kobold"
var def: Dictionary = {}
var hp := 10.0
var maxhp := 10.0
var dmg := 5
var awake := false
var atk_t := 0.0
var slow_t := 0.0
var hit_flash := 0.0
var has_key := false
var enraged := false
var _wind_t := 0.0
var _winding_up := false
var _kb_t := 0.0
var _kb_vel := Vector3.ZERO
var _bleed_stacks := 0
var _bleed_t := 0.0
var _bleed_tick := 0.0
var _burn_per_tick := 0.0
var _burn_t := 0.0
var _burn_tick := 0.0
var _t := 0.0
var _punish_t := 0.0   # post-strike recovery stumble (T4)
var _poise_cur := 0.0  # poise pool; breaks → stagger (T5)
var _stagger_t := 0.0

var spr: Sprite3D
var player: Player

func setup(t: String, ground_pos: Vector3) -> void:
	type = t
	def = Bestiary.get_def(t)
	hp = def.hp
	maxhp = def.hp
	dmg = int(def.dmg)
	add_to_group("enemy")
	var scale_h: float = float(def.scale) * 1.9
	# collision capsule, sitting on the floor
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = clampf(float(def.scale) * 0.35, 0.22, 0.6)
	cap.height = scale_h
	col.shape = cap
	col.position = Vector3(0, scale_h / 2.0, 0)
	add_child(col)
	# billboard
	spr = Sprite3D.new()
	var tx: Texture2D = Art.actor_texture(def.spr)
	spr.texture = tx
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.shaded = false
	spr.pixel_size = scale_h / float(tx.get_height())
	spr.position = Vector3(0, scale_h / 2.0, 0)
	add_child(spr)
	_t = randf() * TAU
	_poise_cur = float(def.get("poise", 20))
	position = ground_pos

func body_center() -> Vector3:
	return global_position + Vector3(0, float(def.scale) * 0.95, 0)

func _apply_knockback(impulse: Vector3) -> void:
	_kb_vel = impulse
	_kb_t = 0.25

func _force_stagger() -> void:
	_poise_cur = -1.0
	_trigger_stagger()

func _trigger_stagger() -> void:
	if _stagger_t > 0.0: return
	_stagger_t = 0.8
	_poise_cur = float(def.get("poise", 20))
	_winding_up = false
	var tw := create_tween()
	tw.tween_property(spr, "position:x",  0.14, 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "position:x", -0.12, 0.08).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(spr, "position:x",  0.0,  0.06).set_ease(Tween.EASE_IN)

func apply_burn(fire_dmg: int) -> void:
	_burn_per_tick = maxf(_burn_per_tick, float(fire_dmg) * 0.075)
	_burn_t = 4.0
	_burn_tick = 0.0

func take_damage(amt: int, col: Color = Color("a01818")) -> void:
	hp -= amt
	hit_flash = 0.12
	awake = true
	# poise damage — break → stagger
	_poise_cur -= float(amt) * 0.8
	if _poise_cur <= 0.0 and _stagger_t <= 0.0:
		_trigger_stagger()
	if amt >= 12:
		_winding_up = false
		atk_t = maxf(atk_t, float(def.atk_cd) * 0.4)
	var sq := create_tween()
	sq.tween_property(spr, "scale", Vector3(1.35, 0.70, 1.35), 0.07).set_ease(Tween.EASE_OUT)
	sq.tween_property(spr, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_IN_OUT)
	if Game.instance and Game.instance.world:
		Game.instance.world.spawn_spark(global_position + Vector3(0, float(def.scale), 0), col)
	if def.get("boss", false) and not enraged and hp > 0 and hp < maxhp * 0.5:
		enraged = true
		if Game.instance.hud:
			Game.instance.hud.message("\"GRUNTS! TO ME!\" Gor'maul bellows!", Color("ff5040"))
		for off in [Vector3(1.4, 0, 0), Vector3(-1.4, 0, 0), Vector3(0, 0, 1.4)]:
			if get_tree().get_nodes_in_group("enemy").size() < 26:
				var ne := Enemy.new()
				Game.instance.floor_root.add_child(ne)
				ne.setup("orc", global_position + off)
				ne.awake = true
	if hp <= 0:
		_die()

func _die() -> void:
	if Game.instance:
		Game.instance.on_enemy_killed(int(def.xp), def.name)
		if has_key:
			Game.instance.spawn_drop("key", global_position)
		if def.get("boss", false):
			Game.instance.spawn_portal(global_position)
	queue_free()

func _physics_process(dt: float) -> void:
	if hit_flash > 0.0:
		hit_flash -= dt
		if hit_flash > 0.0:
			spr.modulate = Color(2, 2, 2)
		elif _winding_up:
			spr.modulate = Color(1.8, 1.6, 0.2)
		else:
			spr.modulate = Color.WHITE
	if slow_t > 0.0:
		slow_t -= dt
	if player == null or not is_instance_valid(player):
		player = Game.instance.player if Game.instance else null
		return
	if player.dead:
		velocity = Vector3.ZERO
		return
	atk_t -= dt
	_t += dt
	var to := player.global_position - global_position
	to.y = 0
	var d := to.length()
	if not awake:
		if d < float(def.sight) and Game.instance.has_los(global_position, player.global_position):
			awake = true
		else:
			return
	# status effect ticks
	if _bleed_t > 0.0:
		_bleed_t -= dt
		_bleed_tick += dt
		if _bleed_tick >= 1.0:
			_bleed_tick -= 1.0
			take_damage(_bleed_stacks * 4, Color("c83030"))
		if _bleed_t <= 0.0:
			_bleed_stacks = 0; _bleed_tick = 0.0
	if _burn_t > 0.0:
		_burn_t -= dt
		_burn_tick += dt
		if _burn_tick >= 1.0:
			_burn_tick -= 1.0
			take_damage(maxi(1, int(_burn_per_tick)), Painter.hex("ff6030"))
		if _burn_t <= 0.0:
			_burn_per_tick = 0.0; _burn_tick = 0.0
	# knockback phase — suspend AI while being launched
	if _kb_t > 0.0:
		_kb_t -= dt
		velocity = _kb_vel * (maxf(0.0, _kb_t) / 0.25)
		velocity.y = 0
		move_and_slide()
		return
	# wind-up telegraph (melee enemies only)
	if _winding_up:
		_wind_t -= dt
		if hit_flash <= 0.0:
			var wp := smoothstep(0.0, 1.0, 1.0 - _wind_t / 0.25)
			spr.modulate = Color(1.8, 1.6, 0.2).lerp(Color(2.2, 0.4, 0.05), wp)
			spr.scale = Vector3.ONE * lerpf(1.0, 1.18, wp)
		velocity = Vector3.ZERO
		if _wind_t <= 0.0:
			_winding_up = false
			spr.scale = Vector3.ONE
			if hit_flash <= 0.0:
				spr.modulate = Color.WHITE
			if d < float(def.range) * 1.5:
				player.take_damage(dmg + Util.li(0, 3), def.name)
				_punish_t = 0.65
				var kb := to.normalized() * 4.5; kb.y = 0
				player._apply_knockback(kb)
				# strike burst: scale spike then spring back
				spr.scale = Vector3(1.3, 1.3, 1.3)
				var tw := create_tween()
				tw.tween_property(spr, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT)
				# impact sparks at player
				if Game.instance and Game.instance.world:
					var hp := player.global_position + Vector3(0, 0.9, 0)
					for i in range(6):
						var off := Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.5), randf_range(-0.3, 0.3))
						Game.instance.world.spawn_spark(hp + off, Color("e05028"))
			atk_t = float(def.atk_cd)
		return
	# stagger: frozen + wobble tween already fired in _trigger_stagger
	if _stagger_t > 0.0:
		_stagger_t -= dt
		velocity = Vector3.ZERO
		move_and_slide()
		return
	# punish window: stumble after striking
	if _punish_t > 0.0:
		_punish_t -= dt
		velocity = Vector3.ZERO
		spr.position.x = sin(_punish_t * 28.0) * 0.07 * (_punish_t / 0.65)
		if _punish_t <= 0.0:
			spr.position.x = 0.0
		move_and_slide()
		return
	var spd: float = float(def.speed) * (0.45 if slow_t > 0.0 else 1.0) * (1.3 if enraged else 1.0)
	var rng: float = float(def.range)
	if def.has("keep_dist"):
		var keep: float = float(def.keep_dist)
		if d > keep:
			velocity = to.normalized() * spd
		elif d < keep - 1.0:
			velocity = -to.normalized() * spd
		else:
			velocity = Vector3.ZERO
		velocity.y = 0
		move_and_slide()
		if atk_t <= 0.0 and d < rng and Game.instance.has_los(global_position, player.global_position):
			atk_t = float(def.atk_cd)
			var kind: String = "arrow" if def.ranged == "axe" else "shadow"
			var from := global_position + Vector3(0, 0.8, 0)
			Game.instance.spawn_projectile("enemy", from, (player.global_position - from), kind, dmg, null)
	else:
		if d > rng:
			velocity = to.normalized() * spd
			velocity.y = 0
			move_and_slide()
		else:
			velocity = Vector3.ZERO
			if atk_t <= 0.0 and not _winding_up:
				_winding_up = true
				_wind_t = 0.25
	# awake bob — gentle float when alive and not mid-action
	if hit_flash <= 0.0 and not _winding_up and _kb_t <= 0.0:
		spr.position.y = float(def.scale) * 0.95 + sin(_t * 2.8) * 0.05 * float(def.scale)
