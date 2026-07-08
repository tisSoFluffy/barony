extends CanvasLayer
class_name ShopUI

const UITheme = preload("res://scripts/ui/UITheme.gd")

var player = null
var is_open := false
var featured: Dictionary = {}

var _gold_label: Label
var _buy_buttons: Array = []
const KINDS := ["hpot", "mpot", "meat", "gear"]

func _ready() -> void:
	layer = 12
	visible = false
	_build_ui()

func _build_ui() -> void:
	var back := ColorRect.new()
	back.color = Color(0.0, 0.0, 0.0, 0.55)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# ornate parchment panel (texture 9-slice or flat fallback)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	center.add_child(panel)

	var pad := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(s, 22)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	pad.add_child(vbox)

	var title := Label.new()
	title.text = "GAZLOWE'S WARES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_header_font(title, 24)
	title.add_theme_color_override("font_color", UITheme.GOLD)
	vbox.add_child(title)

	var sep := ColorRect.new()
	sep.color = UITheme.BRONZE
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_color_override("font_color", UITheme.GOLD)
	vbox.add_child(_gold_label)

	_buy_buttons.clear()
	for kind in KINDS:
		var btn := _make_shop_btn()
		var k: String = kind
		btn.pressed.connect(func(): _buy(k))
		vbox.add_child(btn)
		_buy_buttons.append(btn)

	var close_btn := _make_shop_btn()
	close_btn.text = "Leave Shop  [E]"
	close_btn.pressed.connect(close)
	vbox.add_child(close_btn)

func _make_shop_btn() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.expand_icon = true
	btn.add_theme_stylebox_override("normal", UITheme.slot_style(Color(0.10, 0.07, 0.05, 1.0), UITheme.BRONZE))
	btn.add_theme_stylebox_override("hover", UITheme.slot_style(Color(0.18, 0.13, 0.08, 1.0), UITheme.GOLD))
	btn.add_theme_stylebox_override("pressed", UITheme.slot_style(Color(0.18, 0.13, 0.08, 1.0), UITheme.GOLD))
	btn.add_theme_color_override("font_hover_color", UITheme.GOLD)
	btn.add_theme_color_override("font_pressed_color", UITheme.GOLD)
	return btn

func open(p) -> void:
	player = p
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if featured.is_empty():
		featured = GearDB.roll_gear(min(Game.instance.depth + 1, 5))
	_refresh()

func close() -> void:
	is_open = false
	visible = false
	if not OS.has_feature("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _price(kind: String) -> int:
	var d: int = Game.instance.depth
	if kind == "meat":
		return 8 + d * 5
	if kind == "gear":
		var t: int = int(featured.get("tier", 0))
		return int(round((40.0 + float(d) * 28.0) * (1.0 + float(t) * 0.8)))
	return 14 + d * 8

func _buy(kind: String) -> void:
	if player == null:
		return
	var price: int = _price(kind)
	if player.gold < price:
		Game.instance.hud.message("Not enough gold!", Color(1.0, 0.45, 0.3))
		return
	if kind == "gear":
		if featured.is_empty():
			return
		if not player.add_gear(featured):
			Game.instance.hud.message("Your pack is full!", Color(1.0, 0.45, 0.2))
			return
		player.gold -= price
		Game.instance.hud.message("Bought " + str(featured.get("name", "gear")) + ".", GearDB.tier_color(int(featured.get("tier", 0))))
		featured = GearDB.roll_gear(min(Game.instance.depth + 1, 5))
	else:
		player.gold -= price
		if kind == "hpot": player.hpots += 1
		elif kind == "mpot": player.mpots += 1
		else: player.meat += 1
		Game.instance.hud.message("Bought a %s." % _name(kind), Color(1.0, 0.85, 0.3))
	_refresh()

func _name(kind: String) -> String:
	match kind:
		"hpot": return "Health Potion"
		"mpot": return "Mana Potion"
		"meat": return "Haunch of Meat"
		"gear": return str(featured.get("name", "Mystery Gear"))
		_: return kind

func _icon(kind: String) -> Texture2D:
	if kind == "gear" and not featured.is_empty():
		return Art.actor_texture(GearDB.sprite_id(featured))
	return Art.actor_texture(kind)

func _refresh() -> void:
	if player == null:
		return
	_gold_label.text = "your gold: %d" % player.gold
	for i in range(_buy_buttons.size()):
		var btn: Button = _buy_buttons[i]
		var kind: String = KINDS[i]
		var price: int = _price(kind)
		btn.icon = _icon(kind)
		var desc := ""
		if kind == "gear" and not featured.is_empty():
			desc = "  —  " + GearDB.describe(featured)
		btn.text = "%s%s    [%dg]" % [_name(kind), desc, price]
		var afford: bool = player.gold >= price
		btn.add_theme_color_override("font_color", UITheme.IVORY if afford else UITheme.BLOOD)
