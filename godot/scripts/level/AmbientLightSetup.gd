extends Node3D

# Octopath-style lighting: shadows are dim COOL blue, torch pools are warm
# orange. Ambient must stay high enough that wall/floor texture reads
# everywhere — darkness comes from color temperature, not black.
@export var ambient_energy: float = 1.0

func _ready() -> void:
	# Try a relative path first; fall back to group lookup
	var world_env: WorldEnvironment = get_node_or_null("../WorldEnvironment")
	if world_env == null:
		var nodes: Array = get_tree().get_nodes_in_group("world_environment")
		if nodes.size() > 0:
			world_env = nodes[0] as WorldEnvironment

	if world_env and world_env.environment:
		# ambient_light_energy and ambient_light_color live on the Environment resource
		world_env.environment.ambient_light_energy = ambient_energy
		world_env.environment.ambient_light_color = Color(0.16, 0.18, 0.26)
	else:
		push_warning("AmbientLightSetup: WorldEnvironment not found — ambient config skipped.")

	# Cool directional fill from behind the camera so camera-facing wall
	# faces are never fully unlit; keeps depth without flattening torches.
	var dir_light := DirectionalLight3D.new()
	dir_light.light_energy = 0.5
	dir_light.light_color = Color(0.45, 0.50, 0.65)
	dir_light.rotation_degrees = Vector3(-55.0, 40.0, 0.0)
	add_child(dir_light)
