extends Area3D
## Descend trigger placed at the dungeon's stair tile.
## When the player overlaps it, fades out and loads the next floor.

signal descended(next_depth: int)

var depth: int = 1

const _FADE_DUR := 0.55

func _ready() -> void:
	add_to_group("stair")
	monitoring  = true
	monitorable = false
	collision_layer = 0
	collision_mask  = 1   # player's layer

	_build_visuals()

	body_entered.connect(_on_body_entered)


func _build_visuals() -> void:
	# Collision cylinder
	var cshape := CollisionShape3D.new()
	var cyl    := CylinderShape3D.new()
	cyl.radius = 0.8
	cyl.height = 0.3
	cshape.shape  = cyl
	cshape.position = Vector3(0, 0.15, 0)
	add_child(cshape)

	# Glowing floor disc
	var mesh_inst := MeshInstance3D.new()
	var disc      := CylinderMesh.new()
	disc.top_radius    = 0.75
	disc.bottom_radius = 0.75
	disc.height        = 0.05
	disc.radial_segments = 16
	mesh_inst.mesh = disc
	mesh_inst.position = Vector3(0, 0.02, 0)

	var mat           := StandardMaterial3D.new()
	mat.albedo_color  = Color(0.15, 0.55, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission       = Color(0.1, 0.4, 0.9)
	mat.emission_energy_multiplier = 1.4
	mat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.flags_unshaded = true
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	# Label
	var label        := Label3D.new()
	label.text       = "▼ Descend"
	label.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size  = 38
	label.modulate   = Color(0.6, 0.85, 1.0)
	label.position   = Vector3(0, 0.9, 0)
	label.no_depth_test = true
	add_child(label)

	# Gentle bob animation on the label
	var tw := label.create_tween().set_loops()
	tw.tween_property(label, "position:y", 1.1, 1.0).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(label, "position:y", 0.9, 1.0).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	set_deferred("monitoring", false)
	SignalBus.screen_shake.emit(0.12)
	_fade_and_descend()


func _fade_and_descend() -> void:
	# Post-process overlay already exists; just flash to black via a CanvasLayer
	var fade := CanvasLayer.new()
	fade.layer = 25
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.add_child(rect)
	get_tree().root.add_child(fade)

	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 1.0, _FADE_DUR)
	await tw.finished

	descended.emit(depth + 1)
	fade.queue_free()
