extends SceneTree
## Renders a generated model from four angles so you can eyeball scale, facing
## and texture in Godot's own renderer before trusting it in a sector.
##   godot --path fractured-orbit --resolution 520x520 -s tools/shot_model.gd -- silence_guard
## Writes shot_0..3.png (front, 3/4, side, back) to the project's user:// dir.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var name: String = args[0] if args.size() > 0 else "silence_guard"

	var forge = load("res://scripts/MeshFactory.gd").new()
	var model: Node3D = forge.model(name)
	root.add_child(model)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 145, 0)
	light.light_energy = 1.4
	root.add_child(light)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("14161f")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("6a7080")
	e.ambient_light_energy = 0.6
	env.environment = e
	root.add_child(env)

	# Frame whatever size the model came out at, from slightly above its middle.
	var box: AABB = forge._content_aabb(model, model.transform)
	var tall: float = maxf(box.size.y, 1.0)
	var cam := Camera3D.new()
	root.add_child(cam)
	# look_at() needs the node inside the tree, which the root window is not yet
	# during _init(); the from_position variant works without it.
	cam.look_at_from_position(
		Vector3(0, box.position.y + tall * 0.55, tall * 1.9), box.get_center(), Vector3.UP)
	cam.make_current()

	# Models are authored facing -Z, so yaw 180 turns the front toward the camera.
	var angles := [180, 135, 90, 0]
	for i in angles.size():
		model.rotation_degrees = Vector3(0, angles[i], 0)
		for f in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("user://shot_%d.png" % i)
	print("saved ", ProjectSettings.globalize_path("user://shot_0.png"), " (and shot_1..3)")
	forge.free()
	quit()
