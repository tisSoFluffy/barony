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
	# small chance to drop a health cell
	if Util.chance(0.35):
		var cell := Forge.model("health_cell")
		cell.position = global_position + Vector3(0, 0.5, 0)
		cell.add_to_group("pickups")
		get_parent().add_child(cell)
	queue_free()
