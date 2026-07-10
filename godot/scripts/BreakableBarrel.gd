extends StaticBody3D
## A destructible 3D barrel prop. Plugs into the existing melee/skill hit
## detection by joining group "enemy" — Player._resolve_melee_hit,
## _ability_q (whirlwind), and _resolve_charge_hit all scan
## get_tree().get_nodes_in_group("enemy") and call target.take_damage(amt,
## poise_mult) directly (there's no separate hurtbox/hitbox system in this
## codebase to hook into instead — see Enemy.gd). We deliberately do NOT emit
## SignalBus.enemy_damaged/enemy_died or award XP: those are Enemy-specific,
## the group membership is only borrowed for its hit-scanning side effect.

const _MODEL_PATH := "res://Assets/Barrel/Meshes/barrel.glb"
const _RADIUS := 0.3
const _HEIGHT := 0.9

@export var hp := 35.0
var _broken := false

# Loot table on break — deliberately smaller/rarer than a real enemy kill
# (this is scenery, not a fight). Mirrors Enemy._drop_loot's pattern of
# spawning a GroundItem as a sibling at our position.
const _LOOT_POOL: Array = ["gold", "hpot", "mpot"]
const _LOOT_WEIGHTS: Array = [0.30, 0.10, 0.05]  # remaining 55% = nothing


func _ready() -> void:
	add_to_group("enemy")       # so Player melee/skill hit-scans find us
	add_to_group("breakable")   # future-proof: filterable without touching group "enemy"

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = _RADIUS
	shape.height = _HEIGHT
	col.shape = shape
	col.position = Vector3(0, _HEIGHT * 0.5, 0)
	add_child(col)

	if ResourceLoader.exists(_MODEL_PATH):
		var mesh_inst := (load(_MODEL_PATH) as PackedScene).instantiate()
		add_child(mesh_inst)

	var sf := get_node_or_null("/root/ShadowFactory")
	if sf != null and sf.has_method("make_shadow"):
		var shadow: Node3D = sf.make_shadow(0.45)
		shadow.position = Vector3(0, 0.02, 0)
		add_child(shadow)


## Same call signature Enemy.take_damage() uses, so every existing melee/skill
## call site (`target.take_damage(dmg, stagger_mult)` / `en.take_damage(dmg)`)
## works unmodified against a barrel with no special-casing.
func take_damage(amt: int, _poise_mult: float = 1.0) -> void:
	if _broken:
		return
	hp -= amt
	_spawn_hit_sparks()
	if hp <= 0.0:
		_break()


func _spawn_hit_sparks() -> void:
	var pf := get_node_or_null("/root/ParticleFactory")
	if pf == null or not pf.has_method("hit_sparks"):
		return
	var p: GPUParticles3D = pf.hit_sparks(Color(0.55, 0.35, 0.15))
	add_child(p)
	p.global_position = global_position + Vector3(0.0, 0.5, 0.0)
	p.emitting = true
	p.finished.connect(func() -> void:
		if is_instance_valid(p): p.queue_free())


func _break() -> void:
	_broken = true
	collision_layer = 0
	collision_mask = 0
	# Hide everything but keep the node alive briefly so the burst can play.
	for c in get_children():
		if c is CollisionShape3D:
			continue
		if c.has_method("set_visible"):
			c.visible = false

	var pf := get_node_or_null("/root/ParticleFactory")
	if pf != null and pf.has_method("hit_sparks"):
		var burst: GPUParticles3D = pf.hit_sparks(Color(0.55, 0.35, 0.15))
		burst.amount = 20
		burst.lifetime = 0.6
		burst.top_level = true
		add_child(burst)
		burst.global_position = global_position + Vector3(0.0, 0.4, 0.0)
		burst.emitting = true

	_drop_loot()
	await get_tree().create_timer(0.7).timeout
	queue_free()


func _drop_loot() -> void:
	var roll := randf()
	var acc := 0.0
	var ltype := ""
	for i in _LOOT_POOL.size():
		acc += float(_LOOT_WEIGHTS[i])
		if roll < acc:
			ltype = _LOOT_POOL[i]
			break
	if ltype.is_empty():
		return

	var item_script := load("res://scripts/GroundItem.gd")
	var item: Area3D = item_script.new()
	item.item_type = ltype
	item.item_amt = randi_range(4, 12)
	var parent_node := get_parent()
	if parent_node == null:
		return
	parent_node.add_child(item)
	item.global_position = global_position + Vector3(0.0, 0.2, 0.0)
