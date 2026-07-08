# DevShot.gd — dev-only screenshot helper.
# Run the game with:  godot --path godot -- --shot=/tmp/out.png [--shot-delay=3]
# Captures the viewport after the delay, saves the PNG, and quits.
# No-op in normal play (no --shot arg).

extends Node

var _path := ""
var _delay := 3.0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-delay="):
			_delay = float(arg.trim_prefix("--shot-delay="))
	if _path.is_empty():
		return
	var timer := get_tree().create_timer(_delay)
	timer.timeout.connect(_capture)

func _capture() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_path)
	print("DevShot: saved ", _path)
	get_tree().quit()
