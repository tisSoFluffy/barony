extends CanvasLayer

var _overlay: ColorRect
var _current_scene_path: String = ""

func _ready() -> void:
	layer = 100
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color.BLACK
	_overlay.modulate.a = 0.0
	add_child(_overlay)

func go_to(scene_path: String) -> void:
	await _fade_out()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	_current_scene_path = scene_path
	await _fade_in()
	SignalBus.scene_changed.emit(scene_path.get_file().get_basename())

func reload_current() -> void:
	if _current_scene_path != "":
		await go_to(_current_scene_path)

func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.4)
	await tween.finished

func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0, 0.4)
	await tween.finished
