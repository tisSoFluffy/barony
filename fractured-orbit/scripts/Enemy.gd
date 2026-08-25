class_name Enemy
extends CharacterBody3D
## Compact enemy AI: idle until the player is within aggro range, then chase on
## the ground plane and deal contact damage on an interval. Ranged/exploding
## variants tweak the same loop. Visual comes from Forge (generated model or
## primitive placeholder). Stats are keyed off the enemy type from SectorDB.

const GRAVITY := 24.0

var type := ""
var pal := {}
var hp := 20.0
var max_hp := 20.0
var speed := 3.0
var touch_dmg := 10.0
var aggro := 12.0
var explodes := false
var ranged := false

var _player                        # untyped: resolved from the "player" group
var _atk_cd := 0.0
var _flash := 0.0
var _visual: Node3D
var _anim_t := 0.0
var _yaw := 0.0

func setup(t: String, p: Dictionary) -> void:
	type = t
	pal = p
	match t:
		"scrap_crawler":
			hp = 14.0; speed = 5.0; touch_dmg = 8.0; aggro = 14.0
		"silence_guard":
			hp = 34.0; speed = 2.2; touch_dmg = 14.0; aggro = 10.0
		"drone_swarm":
			hp = 8.0; speed = 6.5; touch_dmg = 16.0; explodes = true; aggro = 16.0
		"turret_spider":
			hp = 40.0; speed = 1.0; touch_dmg = 12.0; ranged = true; aggro = 18.0
		"void_leaper":
			hp = 22.0; speed = 5.5; touch_dmg = 15.0; aggro = 15.0
		"memory_construct":
			hp = 30.0; speed = 3.5; touch_dmg = 13.0; aggro = 16.0
		"core_guardian":
			hp = 120.0; speed = 1.8; touch_dmg = 22.0; aggro = 24.0
		"nexus":
			hp = 300.0; speed = 2.0; touch_dmg = 26.0; aggro = 40.0
		_:
			hp = 20.0
	max_hp = hp

func _ready() -> void:
	add_to_group("enemies")
	_visual = Forge.model(type)
	add_child(_visual)
	var col := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.4
	caps.height = 1.6
	col.shape = caps
	col.position = Vector3(0, 0.8, 0)
	add_child(col)

func _physics_process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	_player = get_tree().get_first_node_in_group("player")
	if _player and is_instance_valid(_player):
		var to: Vector3 = _player.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist < aggro and dist > 0.05:
			var dir := to / dist
			if not ranged or dist > 4.0:
				velocity.x = dir.x * speed
				velocity.z = dir.z * speed
			else:
				velocity.x = 0.0
				velocity.z = 0.0
			if dist < 1.6:
				_atk_cd -= delta
				if _atk_cd <= 0.0:
					_atk_cd = 0.8
					if _player.has_method("take_damage"):
						_player.take_damage(touch_dmg, type)
					if explodes:
						die()
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed * delta * 4.0)
			velocity.z = move_toward(velocity.z, 0.0, speed * delta * 4.0)
	move_and_slide()
	_animate(delta)

## ---- Procedural animation ---------------------------------------------------

## Generated models are one rigid mesh with no skeleton, so all motion has to
## come from the visual node's own transform: a step bob for things that walk, a
## hover for the drone, a turret track for the spider. The body's physics
## transform is untouched. `_visual` starts at identity (see Forge.model), so
## these are absolute values rather than accumulations, and stay stable however
## long the enemy lives.
func _animate(delta: float) -> void:
	if _visual == null:
		return
	var planar := Vector2(velocity.x, velocity.z)
	var moving := planar.length()
	# Gait advances with distance covered, so a fast enemy takes faster steps and
	# a stationary one idles instead of moonwalking on the spot.
	_anim_t += delta * (1.0 + moving * 1.6)
	_face(delta, planar)

	var stride := _anim_t * 3.2
	match type:
		"drone_swarm":
			# never lands: holds a hover and noses down into its suicide run
			_visual.position.y = 0.30 + sin(_anim_t * 5.0) * 0.07
			_visual.rotation.x = -clampf(moving * 0.05, 0.0, 0.35)
			_visual.rotation.z = sin(_anim_t * 11.0) * 0.06
		"turret_spider":
			# stays planted; _face() does the aiming, the body only breathes
			_visual.position.y = sin(_anim_t * 1.6) * 0.025
			_visual.rotation.z = sin(stride * 0.5) * 0.03
		"scrap_crawler":
			# skitters: quicker, shallower and busier than the bipeds
			_visual.position.y = absf(sin(stride * 1.8)) * 0.06
			_visual.rotation.z = sin(stride * 0.9) * 0.10
			_visual.rotation.x = -clampf(moving * 0.03, 0.0, 0.20)
		_:
			# bipeds: two bobs per stride, a roll onto each foot, a forward lean
			_visual.position.y = absf(sin(stride)) * (0.04 + moving * 0.012)
			_visual.rotation.z = sin(stride) * 0.05
			_visual.rotation.x = -clampf(moving * 0.035, 0.0, 0.25)

	# Hit flinch: a recoil that reads even on a near-black silhouette, where the
	# emissive flash does not.
	if _flash > 0.0:
		var punch := _flash / 0.15
		_visual.position.y += punch * 0.10
		_visual.rotation.x += punch * 0.25

## Turns the model toward its heading, or for ranged types keeps it tracking the
## player while planted. Models are authored facing -Z, so pointing that face
## down a direction means a yaw of atan2(-x, -z).
func _face(delta: float, planar: Vector2) -> void:
	var aim := planar
	if ranged and _player and is_instance_valid(_player):
		var to: Vector3 = _player.global_position - global_position
		aim = Vector2(to.x, to.z)
	if aim.length() < 0.05:
		return
	_yaw = lerp_angle(_yaw, atan2(-aim.x, -aim.y),
			clampf(delta * (8.0 if ranged else 5.0), 0.0, 1.0))
	_visual.rotation.y = _yaw

func take_damage(amount: float, _source: String = "") -> void:
	hp -= amount
	_flash = 0.15
	if _visual and _visual.get_child_count() > 0:
		var first := _visual.get_child(0)
		if first is MeshInstance3D:
			var mi := first as MeshInstance3D
			if mi.material_override is StandardMaterial3D:
				(mi.material_override as StandardMaterial3D).emission_enabled = true
	if hp <= 0.0:
		die()

func die() -> void:
	Audio.play("explosion", Util.lf(0.9, 1.2), -10.0)
	# small chance to drop a health cell
	if Util.chance(0.35):
		var cell := Forge.model("health_cell")
		cell.position = global_position + Vector3(0, 0.5, 0)
		cell.add_to_group("pickups")
		get_parent().add_child(cell)
	queue_free()
