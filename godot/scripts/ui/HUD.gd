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
var cons_label: Label
var food_bg: ColorRect
var food_fill: ColorRect
var msg_box: VBoxContainer
var death_panel: Control
var win_panel: Control
var minimap: Minimap

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
	cons_label = Label.new(); cons_label.add_theme_color_override("font_color", Color("ffce42"))
	cons_label.add_theme_font_size_override("font_size", 13); add_child(cons_label)
	food_bg = _bar(Color("1a1208")); food_fill = _bar(Color("c8862a"))

	msg_box = VBoxContainer.new()
	msg_box.alignment = BoxContainer.ALIGNMENT_END
	add_child(msg_box)

	minimap = Minimap.new()
	add_child(minimap)

	death_panel = _make_end("YOU HAVE FALLEN", Color("e03c2c"))
	add_child(death_panel)
	win_panel = _make_end("THE BARONY IS YOURS", Color("62d8ff"))
	add_child(win_panel)

func _bar(c: Color) -> ColorRect:
	var r := ColorRect.new(); r.color = c; r.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(r); return r

func _bar_label() -> Label:
	var l := Label.new(); l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color.WHITE); add_child(l); return l

func _make_end(title_text: String, color: Color) -> Control:
	var p := ColorRect.new()
	p.color = Color(0.06, 0.03, 0.03, 0.82)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(c)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	var title := Label.new(); title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", color)
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
	if sub: sub.text = "Slain by %s on depth %d, at level %d." % [src, Game.instance.depth, player.level]
	death_panel.visible = true
	if not OS.has_feature("headless"): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_win(text: String) -> void:
	var sub := win_panel.find_child("Sub", true, false)
	if sub: sub.text = text
	win_panel.visible = true
	if not OS.has_feature("headless"): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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
	hp_fill.position = Vector2(bx, by); hp_fill.size = Vector2(bw * clampf(player.hp / player.tot_maxhp(), 0, 1), 16)
	hp_label.position = Vector2(bx + 6, by - 1); hp_label.text = "%d / %d" % [ceili(player.hp), player.tot_maxhp()]
	var rc: String = RES_COL.get(player.def.res, "2858c8")
	res_fill.color = Painter.hex(rc)
	res_bg.position = Vector2(bx, by + 20); res_bg.size = Vector2(bw, 12)
	res_fill.position = Vector2(bx, by + 20); res_fill.size = Vector2(bw * clampf(player.mana / player.tot_maxmana(), 0, 1), 12)
	res_label.position = Vector2(bx + 6, by + 19); res_label.text = "%s %d / %d" % [player.def.res, int(player.mana), player.tot_maxmana()]
	food_bg.position = Vector2(bx, by + 36); food_bg.size = Vector2(bw, 6)
	food_fill.color = Painter.hex("c8862a") if player.food > 30.0 else Painter.hex("e03c2c")
	food_fill.position = Vector2(bx, by + 36); food_fill.size = Vector2(bw * clampf(player.food / 100.0, 0, 1), 6)
	cons_label.text = "H:%d  M:%d  G:%d    pack %d/6" % [player.hpots, player.mpots, player.meat, player.bag.size()]
	cons_label.position = Vector2(bx + bw + 16, by + 8)

	# minimap — top-right corner; info label sits just below it
	var mm_w := Minimap.MS * Minimap.CELL + Minimap.PAD * 2
	minimap.position = Vector2(vs.x - mm_w - 12, 8)
	info.text = "%s  LV %d   DEPTH %d" % [player.def.name, player.level, Game.instance.depth]
	info.position = Vector2(vs.x - mm_w - 12, mm_w + 14)

	# message box bottom-left above bars
	msg_box.position = Vector2(bx, by - 130)
	msg_box.size = Vector2(400, 120)
