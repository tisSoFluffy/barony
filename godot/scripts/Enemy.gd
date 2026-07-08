extends CharacterBody3D

## Ranged archetypes: preferred stand-off range, projectile kind/speed/damage,
## and shot cooldown window. Any type NOT in this dict stays melee (unchanged).
const RANGED: Dictionary = {
	"troll": {"range": 6.0, "proj": "axe",  "speed": 10.0, "dmg": 10, "cd_min": 1.8, "cd_max": 2.2},
	"necro":  {"range": 7.0, "proj": "bolt", "speed": 8.0,  "dmg": 12, "cd_min": 1.8, "cd_max": 2.2},
}
const RANGED_RELEASE_FRAC := 0.55  # fraction of wind-up elapsed when the shot actually fires

## XP granted to the player on kill, per enemy type. Types not listed default to 10.
const XP_REWARD: Dictionary = {
	"kobold": 15, "murloc": 20, "skeleton": 25, "orc": 35, "troll": 45,
	"necro": 45, "gormaul": 300,
}

@export var enemy_id: int = 0
var type := "kobold"
var hp := 30.0
var maxhp := 30.0
var dmg := 8
var speed := 2.5
var sight_range := 10.0
var atk_range := 1.6
var atk_cd_dur := 1.2
var awake := false
var dead := false
var atk_t := 0.0
var _kb_t := 0.0
var _kb_vel := Vector3.ZERO
var _wind_t := 0.0
var _wind_dur := 0.0
var _winding_up := false
var _ranged_fired := false  # release already spawned this wind-up cycle
var _punish_t := 0.0
var _poise_cur := 20.0
var _stagger_t := 0.0
var _bleed_stacks := 0
var _bleed_t := 0.0
var _bleed_tick := 0.0
var _burn_per_tick := 0.0
var _burn_t := 0.0
var _burn_tick := 0.0
var player: CharacterBody3D = null
var _sprite: AnimatedSprite3D = null

func _ready() -> void:
	add_to_group("enemy")  # idempotent if Enemy.tscn already declares the group
	# Collision: Enemy.tscn instances already carry a CollisionShape3D child (scene
	# authors it); the `.new()` path (tests) has none yet, so build it in code.
	var collision_shape: CollisionShape3D = null
	for c in get_children():
		if c is CollisionShape3D:
			collision_shape = c
			break
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		var capsule_shape := CapsuleShape3D.new()
		capsule_shape.radius = 0.3
		capsule_shape.height = 1.6
		collision_shape.shape = capsule_shape
		collision_shape.position = Vector3(0, 0.8, 0)
		add_child(collision_shape)
	# Sprite + shadow are always code-built (per-type, data-driven — `type` is
	# assigned by the spawner before add_child either way) — guard against double-add.
	if _sprite == null and SpriteFactory.CHAR_CONFIG.has(type):
		_sprite = SpriteFactory.make_sprite(type)
		add_child(_sprite)
		var shadow_d := 0.9 if type == "gormaul" else 0.6
		add_child(ShadowFactory.make_shadow(shadow_d))

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D

func take_damage(amt: int, poise_mult: float = 1.0) -> void:
	if dead:
		return
	hp -= amt
	_poise_cur -= float(amt) * 0.8 * poise_mult
	if _poise_cur <= 0.0 and _stagger_t <= 0.0:
		_stagger_t = 0.8
		_poise_cur = 20.0
	_spawn_hit_sparks()
	_flash_hit()
	_spawn_damage_number(amt)
	SignalBus.screen_shake.emit(0.18)
	# Emit before potential queue_free so listeners receive the signal
	SignalBus.enemy_damaged.emit(enemy_id, amt)
	if hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	var cj := get_node_or_null("/root/CombatJuice")
	if cj != null:
		cj.hit_stop(0.10, 0.03)  # kill punctuation
	SignalBus.enemy_died.emit(enemy_id)
	_award_xp()
	_spawn_death_burst()
	SignalBus.screen_shake.emit(0.35)
	_drop_loot()
	_play_death_and_free()

func _award_xp() -> void:
	if player == null or not is_instance_valid(player):
		return
	var amt: int = XP_REWARD.get(type, 10)
	player.call("gain_xp", amt)
	_spawn_floating_text("+%d XP" % amt, Color(1.0, 0.84, 0.25))

const _WEAPON_DROP_CHANCE := 0.04  # rare — rolled before the regular loot table
const _WEAPON_DROP_POOL := ["spear", "mace", "flail", "greatsword", "dagger"]

func _drop_loot() -> void:
	var item_script := load("res://scripts/GroundItem.gd")
	if randf() < _WEAPON_DROP_CHANCE:
		var wid: String = _WEAPON_DROP_POOL[randi() % _WEAPON_DROP_POOL.size()]
		var witem: Area3D = item_script.new()
		witem.item_type = "weapon"
		witem.weapon_id = wid
		get_parent().add_child(witem)
		witem.global_position = global_position + Vector3(
			randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
		return

	var roll := randf()
	var ltype := ""
	if roll < 0.45:
		ltype = "gold"
	elif roll < 0.62:
		ltype = "hpot"
	elif roll < 0.72:
		ltype = "meat"
	# 28% chance: nothing drops
	if ltype.is_empty():
		return
	var item: Area3D = item_script.new()
	item.item_type = ltype
	item.item_amt  = randi_range(4, 12)
	get_parent().add_child(item)
	item.global_position = global_position + Vector3(
		randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))

func _play_death_and_free() -> void:
	if _sprite != null:
		_sprite.play("death")
		await _sprite.animation_finished
	queue_free()

func _spawn_hit_sparks() -> void:
	var p := ParticleFactory.hit_sparks()
	add_child(p)
	p.global_position = global_position + Vector3(0.0, 1.0, 0.0)
	p.emitting = true
	p.finished.connect(func() -> void:
		if is_instance_valid(p): p.queue_free())

func _spawn_death_burst() -> void:
	var p := ParticleFactory.death_burst()
	add_child(p)
	p.global_position = global_position + Vector3(0.0, 0.9, 0.0)
	p.emitting = true
	p.finished.connect(func() -> void:
		if is_instance_valid(p): p.queue_free())

func _flash_hit() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.14)

func _spawn_damage_number(amt: int) -> void:
	_spawn_floating_text(str(amt), Color(1.0, 0.92, 0.15))

## Shared floating Label3D — damage numbers and XP gains both ride this.
func _spawn_floating_text(text: String, col: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = col
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.outline_size = 8
	label.font_size = 52
	label.pixel_size = 0.005
	label.no_depth_test = true
	label.top_level = true
	add_child(label)
	label.global_position = global_position + Vector3(
		randf_range(-0.25, 0.25), 1.6, randf_range(-0.25, 0.25))
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 1.4, 0.75)
	tw.tween_property(label, "modulate:a", 0.0, 0.65).set_delay(0.10)
	tw.chain().tween_callback(label.queue_free)

func _force_stagger() -> void:
	_stagger_t = 1.2
	_poise_cur = 20.0

func apply_burn(fire_dmg: int) -> void:
	_burn_per_tick = maxf(_burn_per_tick, fire_dmg * 0.075)
	_burn_t = 4.0
	_burn_tick = 0.0  # reset accumulator so refresh doesn't cause immediate tick

func _apply_knockback(impulse: Vector3) -> void:
	_kb_vel = impulse
	_kb_t = 0.25

func _physics_process(delta: float) -> void:
	atk_t -= delta

	# Bleed tick
	if _bleed_t > 0:
		_bleed_t -= delta
		_bleed_tick += delta
		if _bleed_tick >= 1.0:
			_bleed_tick -= 1.0
			take_damage(_bleed_stacks * 4)
		if _bleed_t <= 0:
			_bleed_stacks = 0
			_bleed_tick = 0.0

	# Burn tick
	if _burn_t > 0:
		_burn_t -= delta
		_burn_tick += delta
		if _burn_tick >= 1.0:
			_burn_tick -= 1.0
			take_damage(maxi(1, int(_burn_per_tick)))
		if _burn_t <= 0:
			_burn_per_tick = 0.0
			_burn_tick = 0.0

	if player == null:
		_find_player()
		return

	if dead or player.dead:
		velocity = Vector3.ZERO
		return

	var to_player := player.global_position - global_position
	to_player.y = 0
	var dist := to_player.length()

	if not awake:
		if dist < sight_range:
			awake = true
		else:
			return

	# Knockback — suspend AI while being launched
	if _kb_t > 0:
		_kb_t -= delta
		velocity = _kb_vel * clampf(_kb_t / 0.25, 0.0, 1.0)
		velocity.y = 0
		move_and_slide()
		return

	# Stagger — frozen after poise break
	if _stagger_t > 0:
		_stagger_t -= delta
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Punish window — stumble after striking
	if _punish_t > 0:
		_punish_t -= delta
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var ranged_cfg: Dictionary = RANGED.get(type, {})
	var is_ranged := not ranged_cfg.is_empty()

	# Wind-up telegraph — freeze then strike on completion
	if _winding_up:
		rotation.y = atan2(to_player.x, to_player.z)  # keep facing target while winding up
		velocity = Vector3.ZERO
		_wind_t -= delta
		# Ranged release fires partway through the wind-up (mirrors the player's
		# deferred melee-hit timing) rather than at anim start.
		if is_ranged and not _ranged_fired and _wind_dur > 0.0 and (_wind_dur - _wind_t) / _wind_dur >= RANGED_RELEASE_FRAC:
			_ranged_fired = true
			_fire_projectile(ranged_cfg)
		if _wind_t <= 0:
			_winding_up = false
			if is_ranged:
				atk_t = randf_range(ranged_cfg["cd_min"], ranged_cfg["cd_max"])
			elif dist < atk_range * 1.5:
				player.call("take_damage", dmg)
				var kb := to_player.normalized() * 4.5
				kb.y = 0
				player._apply_knockback(kb)
				_punish_t = 0.65
				atk_t = atk_cd_dur
		move_and_slide()
		return

	# Chase + attack
	if is_ranged:
		var pref: float = ranged_cfg["range"]
		rotation.y = atan2(to_player.x, to_player.z)
		if dist < pref * 0.6:
			# Too close — back away while still facing the player.
			velocity = -to_player.normalized() * speed
			velocity.y = 0
			move_and_slide()
		elif dist <= pref:
			velocity = Vector3.ZERO
			if atk_t <= 0 and not _winding_up:
				_winding_up = true
				_ranged_fired = false
				_wind_dur = 0.35
				_wind_t = _wind_dur
		else:
			# Player far beyond preferred range — chase like a melee enemy.
			velocity = to_player.normalized() * speed
			velocity.y = 0
			move_and_slide()
	elif dist > atk_range:
		velocity = to_player.normalized() * speed
		velocity.y = 0
		rotation.y = atan2(to_player.x, to_player.z)
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		if atk_t <= 0 and not _winding_up:
			_winding_up = true
			_wind_dur = 0.25
			_wind_t = _wind_dur

	_update_anim()

func _fire_projectile(cfg: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	var from := global_position + Vector3(0, 0.8, 0)
	var to := player.global_position + Vector3(0, 0.8, 0)
	var d := to - from
	if d.length_squared() < 0.0001:
		return
	var pr := Projectile.new()
	pr.team = "enemy"
	pr.kind = cfg["proj"]
	pr.speed = cfg["speed"]
	pr.dmg = cfg["dmg"]
	pr.dir = d.normalized()
	pr.shooter = self
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(pr)
	pr.global_position = from

func _update_anim() -> void:
	if _sprite == null or dead:
		return
	var want: String
	if _stagger_t > 0.0 or _kb_t > 0.0:
		want = "hurt"
	elif _winding_up:
		want = "attack"
	elif Vector3(velocity.x, 0.0, velocity.z).length() > 0.1:
		want = "walk"
	else:
		want = "idle"
	if _sprite.animation != want:
		_sprite.play(want)
