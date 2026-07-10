extends Node3D
## Pure atmospheric floor-scatter decoration — skull-and-crossbones prop.
## No collision, no HP, no loot, no groups. Visual-only.

const _MODEL_PATH := "res://Assets/Bones/Meshes/bones.glb"
# Exported at 0.60× Blender scale → skull cranium ~0.252m wide, total height ~0.21m.


func _ready() -> void:
	# Random facing so repeated placements don't look copy-pasted.
	rotation_degrees.y = randf_range(0.0, 360.0)

	if ResourceLoader.exists(_MODEL_PATH):
		var mesh_inst := (load(_MODEL_PATH) as PackedScene).instantiate()
		add_child(mesh_inst)

	var sf := get_node_or_null("/root/ShadowFactory")
	if sf != null and sf.has_method("make_shadow"):
		var shadow: Node3D = sf.make_shadow(0.28)
		shadow.position = Vector3(0.0, 0.02, 0.0)
		add_child(shadow)
