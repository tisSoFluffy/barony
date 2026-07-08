extends CanvasLayer
## "YOU DIED" screen — fades in on player death, restarts the run on confirm.
## Octopath styling: Cinzel title (kept blood red), parchment strip backdrop.

const UITheme = preload("res://scripts/ui/UITheme.gd")

const _FADE_IN  := 1.8
const _HOLD     := 1.2
const _FADE_OUT := 0.5

func _ready() -> void:
	layer   = 30   # above everything
	visible = false
	SignalBus.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	visible = true

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# parchment strip backdrop behind the title block
	var strip := Panel.new()
	strip.add_theme_stylebox_override("panel", UITheme.panel_style())
	strip.set_anchors_preset(Control.PRESET_CENTER)
	strip.size = Vector2(780, 260)
	strip.position = Vector2(-390, -130)
	strip.modulate.a = 0.0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)

	var label       := Label.new()
	label.text      = "YOU DIED"
	UITheme.apply_header_font(label, 82)
	label.add_theme_color_override("font_color", Color(0.75, 0.08, 0.08, 0.0))
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(700, 120)
	label.position = Vector2(-350, -60)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var sub_label       := Label.new()
	sub_label.text      = "Press any key to try again"
	sub_label.add_theme_font_size_override("font_size", 28)
	sub_label.add_theme_color_override("font_color", Color(0.65, 0.55, 0.55, 0.0))
	sub_label.set_anchors_preset(Control.PRESET_CENTER)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.size     = Vector2(600, 60)
	sub_label.position = Vector2(-300, 65)
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub_label)

	# Fade in background, then parchment strip + title
	var tw := create_tween().set_parallel(false)
	tw.tween_property(bg,    "color:a",                    0.80,       _FADE_IN)
	tw.tween_property(strip, "modulate:a", 1.0, _FADE_IN * 0.5)
	tw.parallel().tween_property(label, "theme_override_colors/font_color:a", 1.0, _FADE_IN * 0.5)
	tw.parallel().tween_property(sub_label, "theme_override_colors/font_color:a", 0.85, _FADE_IN * 0.5)
	tw.tween_interval(_HOLD)

	await tw.finished

	# Wait for any keypress
	await _wait_for_input()

	# Fade to black then reload
	var tw2 := create_tween()
	tw2.tween_property(bg, "color:a", 1.0, _FADE_OUT)
	await tw2.finished

	get_tree().reload_current_scene()


func _wait_for_input() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_anything_pressed():
			return
