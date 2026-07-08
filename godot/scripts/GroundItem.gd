extends Area3D
## A loot item lying on the dungeon floor.
## Player walks over it to pick it up automatically.

var item_type: String = "gold"
var item_amt:  int    = 10
var weapon_id: String = ""  # only used when item_type == "weapon"

const _PICKUP_RADIUS := 0.7
const _BOB_HEIGHT    := 0.18
const _BOB_SPEED     := 2.2

var _base_y: float = 0.3
var _t: float      = 0.0
var _collected: bool = false

# Colors per item type
const _COLORS: Dictionary = {
	"gold":   Color(1.0, 0.82, 0.12),
	"hpot":   Color(0.9, 0.15, 0.15),
	"mpot":   Color(0.25, 0.35, 1.0),
	"gear":   Color(0.7, 0.85, 1.0),
	"meat":   Color(0.85, 0.45, 0.3),
	"weapon": Color(1.0, 0.65, 0.2),
}

const _ICONS: Dictionary = {
	"gold":   "◆",
	"hpot":   "♥",
	"mpot":   "✦",
	"gear":   "⚔",
	"meat":   "●",
	"weapon": "⚔",
}


func _ready() -> void:
	add_to_group("ground_item")
	monitoring   = true
	monitorable  = false
	collision_layer = 0
	collision_mask  = 1   # player layer

	_base_y = position.y + 0.3
	position.y = _base_y

	_build_visuals()
	body_entered.connect(_on_body_entered)


func _build_visuals() -> void:
	var col: Color = _COLORS.get(item_type, Color(1, 1, 1))
	var icon: String = _ICONS.get(item_type, "?")

	# Glow sphere
	var mi   := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission         = col
	mat.emission_energy_multiplier = 1.2
	mi.material_override = mat
	add_child(mi)

	# Billboard label
	var label           := Label3D.new()
	label.text          = icon
	label.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size     = 44
	label.modulate      = col
	label.no_depth_test = true
	label.position      = Vector3(0, 0.32, 0)
	add_child(label)

	# Collision
	var cshape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = _PICKUP_RADIUS
	cshape.shape  = sphere
	add_child(cshape)

	# Small particle glow
	var p := ParticleFactory.hit_sparks(col)
	p.amount        = 4
	p.lifetime      = 1.2
	p.one_shot      = false
	p.explosiveness = 0.0
	p.emitting      = true
	(p.process_material as ParticleProcessMaterial).initial_velocity_min = 0.05
	(p.process_material as ParticleProcessMaterial).initial_velocity_max = 0.2
	(p.process_material as ParticleProcessMaterial).gravity = Vector3.ZERO
	p.top_level = false
	add_child(p)


func _process(delta: float) -> void:
	if _collected:
		return
	_t += delta * _BOB_SPEED
	position.y = _base_y + sin(_t) * _BOB_HEIGHT * 0.5


func _on_body_entered(body: Node3D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	set_deferred("monitoring", false)
	_apply_to_player(body)
	_pop_collect()


func _apply_to_player(player: Node) -> void:
	match item_type:
		"gold":
			if player.has_method("add_gold"):
				player.add_gold(item_amt)
			SignalBus.hud_message.emit("+%d gold" % item_amt, 1.6)
		"hpot":
			if player.has_method("heal"):
				player.heal(25)
			SignalBus.hud_message.emit("Healed 25 HP", 1.6)
		"mpot":
			if player.has_method("restore_mana"):
				player.restore_mana(20)
			SignalBus.hud_message.emit("Restored 20 MP", 1.6)
		"meat":
			if player.has_method("heal"):
				player.heal(10)
			SignalBus.hud_message.emit("Healed 10 HP", 1.6)
		"gear":
			SignalBus.hud_message.emit("Found equipment!", 2.0)
		"weapon":
			# Equips immediately on walk-over — no inventory step, mirrors how
			# potions/gold auto-apply. HUD toast comes from Player.equip_weapon.
			if player.has_method("equip_weapon"):
				player.equip_weapon(weapon_id)
	SignalBus.item_picked_up.emit(item_type)


func _pop_collect() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3(1.6, 1.6, 1.6), 0.08)
	tw.chain().tween_property(self, "scale", Vector3.ZERO, 0.18)
	tw.chain().tween_callback(queue_free)
