extends SceneTree

## Close-up turntable QA: load a GLB, light it, orbit the camera, save a
## horizontal contact strip. Windowed (no --headless) so the framebuffer is real.
##
##   Godot_console.exe --path rainbow-sparkle-squad -s tools/turntable.gd -- <model> <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var model: String = args[0] if args.size() > 0 else "bouncy_blue"
	var out: String = args[1] if args.size() > 1 else "user://turntable.png"

	var root := get_root()
	root.set_size(Vector2i(360 * 4, 420))

	var world := Node3D.new()
	root.add_child(world)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.93, 0.93, 0.95)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.55
	env.environment = e
	world.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_energy = 1.4
	world.add_child(key)

	var scene: PackedScene = load("res://assets/models/%s.glb" % model)
	var inst := scene.instantiate()
	world.add_child(inst)

	# --unshaded : strip lighting, show raw albedo, to tell a texture problem
	# from a shading/normals one.
	if OS.get_cmdline_user_args().has("--unshaded"):
		for mi in _all_mesh(inst):
			var m := mi.mesh as ArrayMesh
			for s in m.get_surface_count():
				var base := m.surface_get_material(s)
				var ov := StandardMaterial3D.new()
				if base is StandardMaterial3D:
					ov.albedo_texture = base.albedo_texture
				ov.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mi.set_surface_override_material(s, ov)

	var cam := Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	cam.make_current()

	# Nodes are only "inside tree" on the next frame.
	await process_frame
	await process_frame

	# GLBs are pre-normalised (longest axis ~1, sitting on y=0, centred on XZ).
	var aabb := _aabb(inst)
	var centre := aabb.position + aabb.size * 0.5
	var radius: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)) * 1.5

	var tex := root.get_texture()
	var tiles: Array[Image] = []
	var yaws := [0.0, 90.0, 200.0, 315.0]
	# Let one frame render per angle.
	for i in yaws.size():
		var a: float = deg_to_rad(yaws[i])
		var eye := centre + Vector3(sin(a) * radius, aabb.size.y * 0.35, cos(a) * radius)
		cam.global_position = eye
		cam.look_at(centre, Vector3.UP)
		await process_frame
		await process_frame
		await process_frame
		tiles.append(tex.get_image())

	var w := tiles[0].get_width()
	var h := tiles[0].get_height()
	var strip := Image.create(w * tiles.size(), h, false, tiles[0].get_format())
	for i in tiles.size():
		strip.blit_rect(tiles[i], Rect2i(0, 0, w, h), Vector2i(w * i, 0))
	var err := strip.save_png(out)
	print("[turntable] %s -> %s err=%d  aabb=%s" % [model, out, err, aabb])
	quit()


func _aabb(node: Node) -> AABB:
	var box := AABB()
	var got := false
	for mi in _all_mesh(node):
		var b: AABB = mi.global_transform * mi.get_aabb()
		if not got:
			box = b
			got = true
		else:
			box = box.merge(b)
	return box


func _all_mesh(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_mesh(c))
	return out
