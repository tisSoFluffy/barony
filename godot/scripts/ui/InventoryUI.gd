extends CanvasLayer
class_name InventoryUI

var player
var is_open := false

var _panel: ColorRect
var _equip_buttons: Dictionary = {}
var _bag_buttons: Array = []
var _stats_label: Label

func _ready() -> void:
	layer = 12
	visible = false
	_build_ui()

func _build_ui() -> void:
	_panel = ColorRect.new()
	_panel.color = Color(0.05, 0.04, 0.06, 0.92)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.custom_minimum_size = Vector2(500, 0)
	outer_vbox.add_theme_constant_override("separation", 12)
	center.add_child(outer_vbox)

	var title := Label.new()
	title.text = "INVENTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	title.add_theme_font_size_override("font_size", 22)
	outer_vbox.add_child(title)

	var equip_label := Label.new()
	equip_label.text = "Equipment"
	equip_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	outer_vbox.add_child(equip_label)

	var equip_grid := GridContainer.new()
	equip_grid.columns = 4
	equip_grid.add_theme_constant_override("h_separation", 8)
	outer_vbox.add_child(equip_grid)

	for slot in ["weapon", "armor", "helm", "ring"]:
		var vbox := VBoxContainer.new()
		equip_grid.add_child(vbox)
		var slot_label := Label.new()
		slot_label.text = slot.capitalize()
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		slot_label.add_theme_font_size_override("font_size", 11)
		vbox.add_child(slot_label)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(108, 84)
		btn.expand_icon = true
		vbox.add_child(btn)
		_equip_buttons[slot] = btn
		btn.pressed.connect(_on_equip_pressed.bind(slot))

	var bag_label := Label.new()
	bag_label.text = "Bag  (left-click: equip · right-click: drop)"
	bag_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	outer_vbox.add_child(bag_label)

	var bag_grid := GridContainer.new()
	bag_grid.columns = 6
	bag_grid.add_theme_constant_override("h_separation", 8)
	outer_vbox.add_child(bag_grid)

	_bag_buttons.clear()
	for i in range(6):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(76, 76)
		btn.expand_icon = true
		bag_grid.add_child(btn)
		_bag_buttons.append(btn)
		btn.pressed.connect(_on_bag_pressed.bind(i))
		btn.gui_input.connect(_on_bag_gui_input.bind(i))

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	outer_vbox.add_child(_stats_label)

	var close_hbox := HBoxContainer.new()
	close_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	outer_vbox.add_child(close_hbox)
	var close_btn := Button.new()
	close_btn.text = "Close  [I]"
	close_btn.pressed.connect(close)
	close_hbox.add_child(close_btn)

func open(p) -> void:
	player = p
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()

func close() -> void:
	is_open = false
	visible = false
	if not OS.has_feature("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle(p) -> void:
	if is_open: close()
	else: open(p)

func _refresh() -> void:
	if player == null:
		return
	for slot in ["weapon", "armor", "helm", "ring"]:
		var btn: Button = _equip_buttons[slot]
		var g = player.equip[slot]
		if g != null:
			btn.icon = Art.actor_texture(GearDB.sprite_id(g))
			btn.text = ""
			btn.tooltip_text = g["name"] + " — " + GearDB.describe(g)
			btn.modulate = GearDB.tier_color(g["tier"])
		else:
			btn.icon = null
			btn.text = "—"
			btn.tooltip_text = slot.capitalize() + " (empty)"
			btn.modulate = Color(0.45, 0.45, 0.45)

	for i in range(6):
		var btn: Button = _bag_buttons[i]
		if i < player.bag.size():
			var g = player.bag[i]
			btn.icon = Art.actor_texture(GearDB.sprite_id(g))
			btn.text = ""
			btn.tooltip_text = g["name"] + " — " + GearDB.describe(g)
			btn.modulate = GearDB.tier_color(g["tier"])
			btn.disabled = false
		else:
			btn.icon = null
			btn.text = ""
			btn.modulate = Color(0.3, 0.3, 0.3)
			btn.disabled = true

	_stats_label.text = "Melee %d   Spell %d   Armor %d      HP %d/%d   Mana %d/%d      Gold %d" % [
		player.tot_dmg(), player.tot_spell(), player.tot_armor(),
		int(player.hp), player.tot_maxhp(), int(player.mana), player.tot_maxmana(), player.gold]

func _on_equip_pressed(slot: String) -> void:
	if player and player.equip[slot] != null:
		player.unequip_slot(slot)
		_refresh()

func _on_bag_pressed(i: int) -> void:
	if player and i < player.bag.size():
		player.equip_from_bag(i)
		_refresh()

func _on_bag_gui_input(event: InputEvent, i: int) -> void:
	if player == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and i < player.bag.size():
			player.drop_from_bag(i)
			_refresh()
