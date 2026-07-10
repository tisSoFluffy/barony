extends StaticBody3D
## Destructible 3D stone rubble pile. Plugs into melee/skill hit detection by
## joining group "enemy" — same trick as BreakableBarrel and BreakablePots.
## Does NOT emit SignalBus.enemy_damaged/enemy_died or award XP.

const _MODEL_PATH := "res://Assets/Stones/Meshes/stones.glb"
# Cluster dimensions from Blender export: ~0.67m wide, ~0.44m tall
const _RADIUS := 0.28
const _HEIGHT := 0.44

@export var hp := 50.0
var _broken := false

const _LOOT_POOL: Array    = ["gold", "hpot", "gem"]
const _LOOT_WEIGHTS: Array = [0.25,   0.06,   0.08]  # remaining 61% = nothing


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("breakable")

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
		var shadow: Node3D = sf.make_shadow(0.40)
		shadow.position = Vector3(0, 0.02, 0)
		add_child(shadow)


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
	var p: GPUParticles3D = pf.hit_sparks(Color(0.55, 0.52, 0.48))  # stone grey
	add_child(p)
	p.global_position = global_position + Vector3(0.0, 0.3, 0.0)
	p.emitting = true
	p.finished.connect(func() -> void:
		if is_instance_valid(p): p.queue_free())


func _break() -> void:
	_broken = true
	collision_layer = 0
	collision_mask = 0
	for c in get_children():
		if c is CollisionShape3D:
			continue
		if c.has_method("set_visible"):
			c.visible = false

	var pf := get_node_or_null("/root/ParticleFactory")
	if pf != null and pf.has_method("hit_sparks"):
		var burst: GPUParticles3D = pf.hit_sparks(Color(0.55, 0.52, 0.48))
		burst.amount = 25
		burst.lifetime = 0.7
		burst.top_level = true
		add_child(burst)
		burst.global_position = global_position + Vector3(0.0, 0.3, 0.0)
		burst.emitting = true

	_drop_loot()
	await get_tree().create_timer(0.8).timeout
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
	item.item_amt = randi_range(3, 10)
	var parent_node := get_parent()
	if parent_node == null:
		return
	parent_node.add_child(item)
	item.global_position = global_position + Vector3(0.0, 0.2, 0.0)
