# CombatJuice.gd — hit-stop, attack lunge, and impact effects.
# Autoload; process_mode ALWAYS so hit_stop can restore time_scale while slowed.

extends Node

var _hs_token := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# Brief time freeze on impact. Token guard: a newer hit_stop invalidates the
# older timer's restore so overlapping hits don't cut the freeze short.
func hit_stop(duration: float = 0.07, scale: float = 0.05) -> void:
	_hs_token += 1
	var token := _hs_token
	Engine.time_scale = scale
	# 4th arg: ignore_time_scale — timer runs on real time
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _hs_token:
		Engine.time_scale = 1.0


# Horizontal impulse toward dir; caller adds to velocity during the swing.
func lunge(dir: Vector3, strength: float = 6.0) -> Vector3:
	dir.y = 0.0
	if dir.length() < 0.01:
		return Vector3.ZERO
	return dir.normalized() * strength


# Expanding ground shockwave ring at the impact point.
func impact_ring(parent: Node3D, pos: Vector3, color: Color = Color(1.0, 0.85, 0.4)) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.28
	mesh.outer_radius = 0.34

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.05, 0)
	mi.scale = Vector3(0.3, 0.3, 0.3)

	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(2.2, 1.0, 2.2), 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(mi.queue_free)
