class_name Guardian
extends CharacterBody3D
## The Core Guardian (Engineering mini-boss): a giant slow cube that SPLITS into
## two smaller, faster cubes each time one is destroyed, down to the smallest
## tier. The arena stays sealed until every fragment is gone (Game checks the
## "boss" group). Low-poly by nature — it literally is a cube.

const GRAVITY := 24.0
const TIERS := 2                 # 2 = big -> 1 -> 0 = smallest

var pal := {}
var tier := TIERS
var hp := 90.0
var max_hp := 90.0
var speed := 1.8
var touch_dmg := 20.0
var _player
var _atk_cd := 0.0
var _mesh: MeshInstance3D

func setup(p: Dictionary, p_tier: int = TIERS) -> void:
	pal = p
	tier = p_tier
	# smaller fragments: less hp, faster, lighter hits
	hp = 90.0 * pow(0.55, float(TIERS - tier))
	max_hp = hp
	speed = 1.8 + float(TIERS - tier) * 1.6
	touch_dmg = 20.0 - float(TIERS - tier) * 5.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	var size := _size()
	_mesh = Forge.slab(Vector3(size, size, size), pal.get("trim", Color("5a5560")), 0.2)
	_mesh.position = Vector3(0, size * 0.5, 0)
	add_child(_mesh)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, size, size)
	col.shape = box
	col.position = Vector3(0, size * 0.5, 0)
	add_child(col)

func _size() -> float:
	return 2.6 * pow(0.62, float(TIERS - tier))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	_player = get_tree().get_first_node_in_group("player")
	if _player and is_instance_valid(_player):
		var to: Vector3 = _player.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 0.05:
			var dir := to / dist
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			if dist < _size() * 0.8 + 1.0:
				_atk_cd -= delta
				if _atk_cd <= 0.0:
					_atk_cd = 1.0
					if _player.has_method("take_damage"):
						_player.take_damage(touch_dmg, "core_guardian")
	move_and_slide()

func take_damage(amount: float, _source: String = "") -> void:
	hp -= amount
	if _mesh and _mesh.material_override is StandardMaterial3D:
		(_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 1.2
	if hp <= 0.0:
		_split_and_die()

func _split_and_die() -> void:
	Audio.play("explosion", 1.0 + float(TIERS - tier) * 0.2, -6.0)
	if tier > 0:
		for s in [-1.0, 1.0]:
			var frag := Guardian.new()
			frag.setup(pal, tier - 1)
			get_parent().add_child(frag)
			frag.global_position = global_position + Vector3(s * 1.2, 0.2, 0.0)
	else:
		if Util.chance(0.5):
			var cell := Forge.model("health_cell")
			cell.position = global_position + Vector3(0, 0.5, 0)
			cell.add_to_group("pickups")
			get_parent().add_child(cell)
	queue_free()
