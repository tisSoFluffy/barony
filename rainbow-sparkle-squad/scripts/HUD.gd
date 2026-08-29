class_name HUD
extends CanvasLayer

## Sparkle counter, active-character readout, and the win banner.
## Built in code so there is no .tscn to keep in sync with the scripts.

var _counter: Label
var _stars: Label
var _who: Label
var _hint: Label
var _banner: Label
var _prompt: Label
var _fade: ColorRect


func _ready() -> void:
	layer = 10
	_counter = _make_label(24, Color(0.30, 0.20, 0.42))
	_counter.position = Vector2(28, 20)
	add_child(_counter)

	_stars = _make_label(24, Color(0.86, 0.55, 0.12))
	_stars.position = Vector2(28, 52)
	add_child(_stars)

	_who = _make_label(18, Color(0.36, 0.28, 0.46))
	_who.position = Vector2(28, 88)
	add_child(_who)

	_hint = _make_label(15, Color(0.42, 0.36, 0.50, 0.85))
	_hint.position = Vector2(28, 116)
	_hint.text = "Left stick move   A jump   X swap   RT dash   Right stick camera"
	add_child(_hint)

	_banner = _make_label(46, Color(0.98, 0.42, 0.62))
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	add_child(_banner)

	# Blockland's "what comes next" line, along the bottom where it does not
	# fight the meadow counters at the top.
	# Full-width so centre-aligned text lands in the middle on its own - the
	# text changes length constantly, and re-measuring it every time is a race
	# against the label's own layout pass.
	_prompt = _make_label(30, Color(0.24, 0.18, 0.36))
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_top = -104
	_prompt.offset_bottom = -56
	_prompt.visible = false
	add_child(_prompt)

	# Sits above everything for the doorway fade.
	_fade = ColorRect.new()
	_fade.color = Color(1, 1, 1, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


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


func set_stars(count: int, total: int) -> void:
	if count >= total:
		_stars.text = "Stars  %d / %d   -  all found!" % [count, total]
	else:
		_stars.text = "Stars  %d / %d" % [count, total]


func set_character(name: String) -> void:
	_who.text = "Playing as %s" % name


## The Blockland instruction line. Empty text hides it again.
func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = text != ""


## Only the meadow counters make sense in the meadow, so they are hidden while
## the player is in Blockland.
func set_meadow_visible(on: bool) -> void:
	_counter.visible = on
	_stars.visible = on


## Fade to white and back, with `midpoint` called while the screen is covered.
## Wrapping the teleport in this hides the camera snap, which is otherwise a
## jarring cut for a small player.
func wipe(midpoint: Callable, out_time := 0.28, in_time := 0.38) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, out_time)
	tween.tween_callback(midpoint)
	tween.tween_interval(0.05)
	tween.tween_property(_fade, "color:a", 0.0, in_time)


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
