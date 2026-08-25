extends SceneTree
## Headless sanity check for generated models: reports which logical assets are
## backed by a real file and what footprint they end up with after Forge._fit().
##   godot --headless --path fractured-orbit -s tools/check_models.gd

func _init() -> void:
	var forge = load("res://scripts/MeshFactory.gd").new()
	var names := [
		"cargo_crate", "magnet_ring", "vine_ribbon", "thorn_cluster",
		"spore_vent", "nexus", "silence_guard", "scrap_crawler", "drone_swarm",
		"turret_spider", "void_leaper", "memory_construct", "core_guardian",
		"health_cell",
	]
	for n in names:
		var real: bool = forge.has_model(n)
		var node: Node3D = forge.model(n)
		var box: AABB = forge._content_aabb(node, node.transform)
		print("%-14s %-12s size=(%.2f, %.2f, %.2f)  baseY=%.3f  centerXZ=(%.2f, %.2f)" % [
			n, "MODEL" if real else "placeholder",
			box.size.x, box.size.y, box.size.z,
			box.position.y, box.get_center().x, box.get_center().z])
		node.free()
	forge.free()
	quit()
