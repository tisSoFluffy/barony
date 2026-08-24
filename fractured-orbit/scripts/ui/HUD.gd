class_name HUD
extends CanvasLayer
## Minimal diegetic-ish HUD: integrity (health) bar, the 10-minute loop timer,
## the current sector + loop counter, the owned/locked gate roster (the
## metroidvania checklist), a rolling notice feed, and death/victory overlays.

var _hp_bar: ProgressBar
var _hp_label: Label
var _sector_label: Label
var _timer_label: Label
var _gates_label: Label
var _notice: Label
var _crosshair: Label
var _overlay: Control
var _notices: Array = []

func _ready() -> void:
	layer = 10
	_build()

func _build() -> void:
	# crosshair
	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.add_theme_font_size_override("font_size", 22)
	_crosshair.add_theme_color_override("font_color", Color("cfe0ff"))
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-6, -14)
	add_child(_crosshair)

	# top-left: sector + loop
	_sector_label = _mk_label(Vector2(16, 12), 20, Color("ffe08a"))
	_timer_label = _mk_label(Vector2(16, 40), 16, Color("cfe0ff"))

	# bottom-left: integrity bar
	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(260, 22)
	_hp_bar.position = Vector2(16, 640)
	_hp_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hp_bar.position = Vector2(16, -40)
	add_child(_hp_bar)
	_hp_label = _mk_label(Vector2(20, -62), 14, Color("ffffff"))
	_hp_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hp_label.position = Vector2(20, -64)

	# top-right: gates roster
	_gates_label = Label.new()
	_gates_label.add_theme_font_size_override("font_size", 14)
	_gates_label.add_theme_color_override("font_color", Color("bfe0ff"))
	_gates_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_gates_label.position = Vector2(-240, 12)
	_gates_label.custom_minimum_size = Vector2(224, 0)
	add_child(_gates_label)

	# center-bottom: notice feed
	_notice = Label.new()
	_notice.add_theme_font_size_override("font_size", 16)
	_notice.add_theme_color_override("font_color", Color("ffd98a"))
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_notice.position = Vector2(-300, -140)
	_notice.custom_minimum_size = Vector2(600, 0)
	add_child(_notice)

	refresh_gates()

func _mk_label(pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.position = pos
	add_child(l)
	return l

func set_health(hp: float, maxhp: float) -> void:
	_hp_bar.max_value = maxhp
	_hp_bar.value = clampf(hp, 0, maxhp)
	_hp_label.text = "INTEGRITY  %d / %d" % [int(hp), int(maxhp)]

func set_sector(name: String, loop: int) -> void:
	_sector_label.text = name
	_timer_label.text = "LOOP %d" % (loop + 1)

func set_timer(seconds: float) -> void:
	var s := maxi(0, int(seconds))
	_timer_label.text = "LOOP RESET IN  %d:%02d" % [s / 60, s % 60]

func refresh_gates() -> void:
	var lines := ["— TRAVERSAL —"]
	for id in Abilities.gate_ids():
		var g := Abilities.get_gate(id)
		var mark := "[x]" if Meta.has_gate(id) else "[ ]"
		lines.append("%s %s" % [mark, g["name"]])
	_gates_label.text = "\n".join(lines)

func show_notice(text: String) -> void:
	_notices.append(text)
	if _notices.size() > 3:
		_notices = _notices.slice(_notices.size() - 3)
	_notice.text = "\n".join(_notices)
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_callback(func():
		if _notices.size() > 0:
			_notices.pop_front()
		_notice.text = "\n".join(_notices))

func show_end(title: String, subtitle: String, color: Color) -> void:
	if _overlay:
		_overlay.queue_free()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-200, -60)
	box.custom_minimum_size = Vector2(400, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay.add_child(box)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", color)
	box.add_child(t)
	var s := Label.new()
	s.text = subtitle
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(400, 0)
	s.add_theme_color_override("font_color", Color("cfd8e6"))
	box.add_child(s)
	add_child(_overlay)

func clear_end() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
