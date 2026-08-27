class_name HUD
extends CanvasLayer

## Sparkle counter, active-character readout, and the win banner.
## Built in code so there is no .tscn to keep in sync with the scripts.

var _counter: Label
var _who: Label
var _hint: Label
var _banner: Label


func _ready() -> void:
	layer = 10
	_counter = _make_label(24, Color(0.30, 0.20, 0.42))
	_counter.position = Vector2(28, 20)
	add_child(_counter)

	_who = _make_label(18, Color(0.36, 0.28, 0.46))
	_who.position = Vector2(28, 58)
	add_child(_who)

	_hint = _make_label(15, Color(0.42, 0.36, 0.50, 0.85))
	_hint.position = Vector2(28, 86)
	_hint.text = "Left stick move   A jump   X swap   RT dash   Right stick camera"
	add_child(_hint)

	_banner = _make_label(46, Color(0.98, 0.42, 0.62))
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	add_child(_banner)


func _make_label(size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	return label


func set_sparkles(count: int, needed: int) -> void:
	if needed > 0:
		_counter.text = "Sparkles  %d / %d" % [count, count + needed]
	else:
		_counter.text = "Sparkles  %d   -  the gate is open!" % count


func set_character(name: String) -> void:
	_who.text = "Playing as %s" % name


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
	# Re-centre now that the text (and therefore the label) has a real width.
	await get_tree().process_frame
	_banner.pivot_offset = _banner.size * 0.5
	var tween := create_tween()
	_banner.scale = Vector2.ONE * 0.6
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
