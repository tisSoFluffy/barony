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
	position = ground_pos

func take_damage(amt: int, col: Color = Color("a01818")) -> void:
	hp -= amt
	hit_flash = 0.12
	awake = true
	if Game.instance and Game.instance.world:
		Game.instance.world.spawn_spark(global_position + Vector3(0, float(def.scale), 0), col)
	if hp <= 0:
		_die()

func _die() -> void:
	if Game.instance:
		Game.instance.on_enemy_killed(int(def.xp), def.name)
	queue_free()

func _physics_process(dt: float) -> void:
	if hit_flash > 0.0:
		hit_flash -= dt
		spr.modulate = Color(2, 2, 2) if hit_flash > 0.0 else Color.WHITE
	if slow_t > 0.0:
		slow_t -= dt
	if player == null or not is_instance_valid(player):
		player = Game.instance.player if Game.instance else null
		return
	if player.dead:
		velocity = Vector3.ZERO
		return
	atk_t -= dt
	var to := player.global_position - global_position
	to.y = 0
	var d := to.length()
	if not awake:
		if d < float(def.sight) and Game.instance.has_los(global_position, player.global_position):
			awake = true
		else:
			return
	var spd: float = float(def.speed) * (0.45 if slow_t > 0.0 else 1.0)
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
			if atk_t <= 0.0:
				atk_t = float(def.atk_cd)
				player.take_damage(dmg + Util.li(0, 3), def.name)
