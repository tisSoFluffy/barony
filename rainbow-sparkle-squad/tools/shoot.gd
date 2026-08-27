extends SceneTree

## Headless-ish smoke test: load Main, let it simulate for a while, save a
## screenshot, and report what actually got built. Catches the errors that only
## appear at runtime (bad model paths, mis-scaled props, the player falling
## through the floor) without needing anyone to sit at the keyboard.
##
##   Godot_console.exe --path rainbow-sparkle-squad -s tools/shoot.gd -- [frames] [out.png]

var _frames := 0
var _limit := 150
var _out := "user://shot.png"
var _root: Node = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_limit = int(args[0])
	if args.size() > 1:
		_out = args[1]

	_root = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(_root)
	print("[shoot] Main.tscn instantiated")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _limit:
		return false

	_report()
	var image := get_root().get_texture().get_image()
	var err := image.save_png(_out)
	print("[shoot] saved %s (err=%d)" % [_out, err])
	return true


func _report() -> void:
	var player := _root.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		print("[shoot] ERROR no Player node")
	else:
		print("[shoot] player at %v  on_floor=%s  as %s" % [
			player.global_position, player.is_on_floor(),
			player.get("character")["name"],
		])

	var counts := {}
	for child in _root.get_children():
		var key := child.get_class()
		if child.get_script() != null:
			key = str(child.get_script().resource_path.get_file().get_basename())
		counts[key] = int(counts.get(key, 0)) + 1
	print("[shoot] children: %s" % [counts])

	# Every prop should have real geometry under it; an empty holder means a
	# GLB failed to load and we would otherwise ship an invisible level.
	var empty: Array = []
	for child in _root.get_children():
		if child is Node3D and _mesh_count(child) == 0 and child.name != "Player":
			empty.append(child.name)
	if empty.is_empty():
		print("[shoot] all props have meshes")
	else:
		print("[shoot] WARNING props with no mesh: %s" % [empty])


func _mesh_count(node: Node) -> int:
	var n := 0
	if node is MeshInstance3D:
		n += 1
	for child in node.get_children():
		n += _mesh_count(child)
	return n
