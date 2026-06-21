extends CanvasLayer
class_name HUD
## Health/resource bars, crosshair, floating messages, damage flash, the
## first-person weapon view (with swing/cast bob), and the death screen.

var player: Player
var t := 0.0

var flash_rect: ColorRect
var crosshair: Label
var weapon: TextureRect
var hp_bg: ColorRect
var hp_fill: ColorRect
var hp_label: Label
var res_bg: ColorRect
var res_fill: ColorRect
var res_label: Label
var info: Label
var msg_box: VBoxContainer
var death_panel: Control

const RES_COL := {"RAGE": "c85820", "MANA": "2858c8", "FOCUS": "2a9a4a", "FAITH": "c8a828", "ENERGY": "c8b028"}

func _ready() -> void:
	layer = 10
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 0, 0, 0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

	weapon = TextureRect.new()
	weapon.texture = WeaponArt.get_weapon(player.cls)
	weapon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon.custom_minimum_size = Vector2(360, 400)
	add_child(weapon)

	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 22)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	add_child(crosshair)

	hp_bg = _bar(Color("180808")); hp_fill = _bar(Color("c82818"))
	res_bg = _bar(Color("0a0a18")); res_fill = _bar(Color("2858c8"))
	hp_label = _bar_label(); res_label = _bar_label()
	info = Label.new(); info.add_theme_color_override("font_color", Color("ffce42"))
	info.add_theme_font_size_override("font_size", 16); add_child(info)

	msg_box = VBoxContainer.new()
	msg_box.alignment = BoxContainer.ALIGNMENT_END
	add_child(msg_box)

	death_panel = _make_death()
	add_child(death_panel)

func _bar(c: Color) -> ColorRect:
	var r := ColorRect.new(); r.color = c; r.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(r); return r

func _bar_label() -> Label:
	var l := Label.new(); l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color.WHITE); add_child(l); return l

func _make_death() -> Control:
	var p := ColorRect.new()
	p.color = Color(0.1, 0.0, 0.0, 0.78)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(c)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	var title := Label.new(); title.text = "YOU HAVE FALLEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("e03c2c"))
	v.add_child(title)
	var sub := Label.new(); sub.name = "Sub"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color("c9b37e")); v.add_child(sub)
	var b := Button.new(); b.text = "Return to the Title"
	b.pressed.connect(func(): get_tree().reload_current_scene())
	v.add_child(b)
	return p

func flash(c: Color) -> void:
	flash_rect.color = c
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.4)

func message(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 15)
	msg_box.add_child(l)
	while msg_box.get_child_count() > 5:
		msg_box.get_child(0).free()
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.5)
	tw.tween_callback(func(): if is_instance_valid(l): l.queue_free())

func show_death(src: String) -> void:
	var sub := death_panel.find_child("Sub", true, false)
	if sub: sub.text = "Slain by %s at level %d." % [src, player.level]
	death_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(dt: float) -> void:
	t += dt
	if player == null or not is_instance_valid(player):
		return
	var vs := get_viewport().get_visible_rect().size

	# crosshair
	crosshair.position = vs * 0.5 - Vector2(7, 14)

	# weapon view bob + swing
	var bob := Vector2(sin(t * 2.0) * 6.0, abs(cos(t * 2.0)) * 5.0)
	var swing := 0.0
	if player.atk_t > 0.0: swing = player.atk_t / 0.42
	elif player.cast_t > 0.0: swing = player.cast_t / 0.45
	weapon.size = weapon.custom_minimum_size
	weapon.position = Vector2(vs.x * 0.5 - 120 + bob.x, vs.y - 300 + bob.y - swing * 26.0)
	weapon.rotation = swing * 0.25

	# bars (bottom-left)
	var bw := 200.0
	var bx := 20.0
	var by := vs.y - 56.0
	hp_bg.position = Vector2(bx, by); hp_bg.size = Vector2(bw, 16)
	hp_fill.position = Vector2(bx, by); hp_fill.size = Vector2(bw * clampf(player.hp / player.maxhp, 0, 1), 16)
	hp_label.position = Vector2(bx + 6, by - 1); hp_label.text = "%d / %d" % [ceili(player.hp), int(player.maxhp)]
	var rc: String = RES_COL.get(player.def.res, "2858c8")
	res_fill.color = Painter.hex(rc)
	res_bg.position = Vector2(bx, by + 20); res_bg.size = Vector2(bw, 12)
	res_fill.position = Vector2(bx, by + 20); res_fill.size = Vector2(bw * clampf(player.mana / player.maxmana, 0, 1), 12)
	res_label.position = Vector2(bx + 6, by + 19); res_label.text = "%s %d / %d" % [player.def.res, int(player.mana), int(player.maxmana)]

	# info top-right
	info.text = "%s  LV %d   DEPTH %d" % [player.def.name, player.level, Game.instance.depth]
	info.position = Vector2(vs.x - 320, 16)

	# message box bottom-left above bars
	msg_box.position = Vector2(bx, by - 130)
	msg_box.size = Vector2(400, 120)
