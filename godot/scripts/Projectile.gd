extends Node3D
class_name Projectile
## A flying bolt/arrow/fireball. team "player" hits enemies; "enemy" hits the
## player. Carries pierce + lifesteal (heals owner on hit).

var team := "player"
var kind := "fire"
var dir := Vector3.FORWARD
var speed := 9.0
var dmg := 10
var pierce := 0
var life := 0.0
var ttl := 2.4
var owner_player: Player = null
var _hit := {}

func _ready() -> void:
	var d: Dictionary = Classes.proj.get(kind, {})
	var c2: Color = Painter.hex(d.get("c2", "ffd040"))
	var c1: Color = Painter.hex(d.get("c1", "ff5810"))
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.26
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c2
	mat.emission_enabled = true
	mat.emission = c1
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	add_child(m)
	var light := OmniLight3D.new()
	light.light_color = c1
	light.omni_range = 3.0
	light.light_energy = 1.2
	add_child(light)

func _physics_process(dt: float) -> void:
	global_position += dir * speed * dt
	ttl -= dt
	if ttl <= 0.0 or Game.instance.is_wall(global_position):
		queue_free()
		return
	var grp := "enemy" if team == "player" else "player"
	for t in get_tree().get_nodes_in_group(grp):
		if _hit.has(t):
			continue
		var tc: Vector3 = t.body_center() if t.has_method("body_center") else t.global_position + Vector3(0, 0.7, 0)
		if global_position.distance_to(tc) < 0.85:
			if team == "player":
				t.take_damage(dmg, Painter.hex(Classes.proj.get(kind, {}).get("trail", "ff9020")))
				if life > 0.0 and owner_player and is_instance_valid(owner_player):
					owner_player.heal(int(round(dmg * life)))
			else:
				t.take_damage(dmg, kind)
				if t.has_method("_apply_knockback"):
					t._apply_knockback(dir * 2.5)
			_hit[t] = true
			if pierce <= 0:
				queue_free()
				return
