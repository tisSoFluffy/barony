extends CanvasLayer
## HD 2D Inventory panel — press I to open / close.
## Reads from and writes to the player node (fetched via "player" group).
## Built entirely in code — Octopath parchment/bronze styling via UITheme.gd.

const UITheme = preload("res://scripts/ui/UITheme.gd")

# ── palette (delegates to UITheme) ─────────────────────────────────────────────
const _GOLD    := UITheme.GOLD
const _PANEL   := UITheme.PARCHMENT
const _TXT     := UITheme.IVORY
const _DIM     := UITheme.MUTED
const _EMPTY   := Color(0.10, 0.07, 0.05, 1.0)
const _HOVER   := Color(0.18, 0.13, 0.08, 1.0)

const _SLOT_COL := {
	"weapon": Color(0.82, 0.48, 0.12),
	"armor":  Color(0.28, 0.48, 0.75),
	"helm":   Color(0.22, 0.64, 0.56),
	"ring":   Color(0.64, 0.28, 0.74),
}
const _SLOT_ICON := { "weapon": "S", "armor": "A", "helm": "H", "ring": "R" }

# ── layout ────────────────────────────────────────────────────────────────────
const _PW     := 640.0
const _PH     := 460.0
const _SLOT_H := 62.0
const _BORDER := 2.0

# ── runtime refs ──────────────────────────────────────────────────────────────
var _player                    = null
var _equip_btns: Dictionary    = {}
var _bag_btns:   Array[Button] = []
var _cons_lbl:   Label
var _gold_lbl:   Label
var _stat_lbl:   Label


func _ready() -> void:
	layer   = 15
	visible = false
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if visible:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()


# ── open / close ──────────────────────────────────────────────────────────────

func _open() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.set_physics_process(false)
		_player.velocity = Vector3.ZERO
	_refresh()
	visible = true


func _close() -> void:
	if _player:
		_player.set_physics_process(true)
	visible = false


# ── slot click handlers ───────────────────────────────────────────────────────

func _on_equip_click(slot: String) -> void:
	if _player == null: return
	_player.unequip_slot(slot)
	_refresh()


func _on_bag_click(i: int) -> void:
	if _player == null: return
	_player.equip_from_bag(i)
	_refresh()


# ── refresh ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _player == null: return

	for slot in ["weapon", "armor", "helm", "ring"]:
		var btn: Button = _equip_btns[slot]
		var g = _player.equip.get(slot)
		if g != null:
			_style_filled(btn, slot, g.get("name", "???"), _stat_line(g))
		else:
			_style_empty(btn, slot)

	for i in 6:
		var btn: Button = _bag_btns[i]
		if i < _player.bag.size():
			var g = _player.bag[i]
			_style_filled(btn, g.get("slot", "weapon"), g.get("name", "???"), _stat_line(g))
		else:
			_style_empty(btn, "")

	_cons_lbl.text = "HP Pot x%d     MP Pot x%d     Keys x%d" % [
		_player.hpots, _player.mpots, _player.keys]
	_gold_lbl.text = "Gold: %d gp" % _player.gold

	_stat_lbl.text = "ATK %d   HP %d / %d   ARMOR %d   MANA %d / %d" % [
		_player.tot_dmg(),
		int(_player.hp), _player.tot_maxhp(),
		_player.tot_armor(),
		int(_player.mana), _player.tot_maxmana(),
	]


func _stat_line(g: Dictionary) -> String:
	var b: Dictionary = g.get("b", {})
	var s := ""
	if b.get("dmg",   0): s += "+%d ATK  " % b["dmg"]
	if b.get("armor", 0): s += "+%d ARM  " % b["armor"]
	if b.get("hp",    0): s += "+%d HP  "  % b["hp"]
	if b.get("mana",  0): s += "+%d MP  "  % b["mana"]
	if b.get("spell", 0): s += "+%d SPL"   % b["spell"]
	return s.strip_edges() if s != "" else " "


# ── UI construction ───────────────────────────────────────────────────────────

func _build() -> void:
	# Full-screen dimmer
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Center the panel
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)

	# Ornate parchment panel (texture 9-slice or flat fallback)
	var inner := PanelContainer.new()
	inner.custom_minimum_size = Vector2(_PW, _PH)
	inner.add_theme_stylebox_override("panel", UITheme.panel_style())
	cc.add_child(inner)

	var pad := MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		pad.add_theme_constant_override(s, 20)
	inner.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	pad.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "INVENTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_header_font(title, 22)
	title.add_theme_color_override("font_color", _GOLD)
	vbox.add_child(title)

	var sep := ColorRect.new()
	sep.color = UITheme.BRONZE
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	# Content row
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 0)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(cols)

	# ── Left: equipped ────────────────────────────────────────────────────────
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(290, 0)
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)

	left.add_child(_header_lbl("EQUIPPED"))

	_equip_btns.clear()
	for slot in ["weapon", "armor", "helm", "ring"]:
		var btn := _make_slot_btn()
		btn.pressed.connect(_on_equip_click.bind(slot))
		_equip_btns[slot] = btn
		left.add_child(btn)

	# ── Divider ───────────────────────────────────────────────────────────────
	var div := ColorRect.new()
	div.color = UITheme.BRONZE
	div.custom_minimum_size = Vector2(1, 0)
	div.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(div)

	# ── Right: bag + info ─────────────────────────────────────────────────────
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)

	var right_pad := MarginContainer.new()
	right_pad.add_theme_constant_override("margin_left", 10)
	right_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_pad.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right.add_child(right_pad)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right_pad.add_child(right_vbox)

	right_vbox.add_child(_header_lbl("PACK"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(grid)

	_bag_btns.clear()
	for i in 6:
		var btn := _make_slot_btn()
		btn.pressed.connect(_on_bag_click.bind(i))
		_bag_btns.append(btn)
		grid.add_child(btn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(spacer)

	_cons_lbl = _info_lbl("")
	right_vbox.add_child(_cons_lbl)

	_gold_lbl = _info_lbl("")
	right_vbox.add_child(_gold_lbl)

	# ── Stat bar ──────────────────────────────────────────────────────────────
	var stat_sep := ColorRect.new()
	stat_sep.color = UITheme.BRONZE
	stat_sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(stat_sep)

	var stat_bg := ColorRect.new()
	stat_bg.color = Color(0.09, 0.065, 0.04, 1.0)
	stat_bg.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(stat_bg)

	var stat_m := MarginContainer.new()
	stat_m.add_theme_constant_override("margin_left",  10)
	stat_m.add_theme_constant_override("margin_right", 10)
	stat_m.add_theme_constant_override("margin_top",    5)
	stat_m.add_theme_constant_override("margin_bottom", 5)
	stat_bg.add_child(stat_m)

	_stat_lbl = Label.new()
	_stat_lbl.add_theme_font_size_override("font_size", 13)
	_stat_lbl.add_theme_color_override("font_color", _TXT)
	_stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_m.add_child(_stat_lbl)


# ── slot styling ──────────────────────────────────────────────────────────────

func _style_filled(btn: Button, slot: String, item_name: String, stats: String) -> void:
	var col: Color = _SLOT_COL.get(slot, _GOLD)
	var icon: String = _SLOT_ICON.get(slot, "?")
	btn.text = " [%s]  %s\n      %s" % [icon, item_name.to_upper(), stats]
	# filled slot border reads gold (selected/equipped highlight); fill tints toward item color
	btn.add_theme_stylebox_override("normal", UITheme.slot_style(col.darkened(0.55), _GOLD))
	btn.add_theme_stylebox_override("hover", UITheme.slot_style(col.darkened(0.35), _GOLD))
	btn.add_theme_stylebox_override("pressed", UITheme.slot_style(col.darkened(0.35), _GOLD))


func _style_empty(btn: Button, slot: String) -> void:
	var col: Color = _SLOT_COL.get(slot, _DIM)
	var icon: String = _SLOT_ICON.get(slot, " ")
	btn.text = " [%s]  ─ empty ─\n" % icon
	btn.add_theme_stylebox_override("normal", UITheme.slot_style(_EMPTY, col.darkened(0.3)))
	btn.add_theme_stylebox_override("hover", UITheme.slot_style(_HOVER, _GOLD))
	btn.add_theme_stylebox_override("pressed", UITheme.slot_style(_HOVER, _GOLD))


# ── widget factories ──────────────────────────────────────────────────────────

func _make_slot_btn() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, _SLOT_H)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color",       _TXT)
	btn.add_theme_color_override("font_hover_color", _GOLD)
	btn.add_theme_color_override("font_pressed_color", _GOLD)
	return btn


func _header_lbl(text: String) -> Label:
	var l := Label.new()
	l.text = text
	UITheme.apply_header_font(l, 13)
	l.add_theme_color_override("font_color", _DIM)
	return l


func _info_lbl(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", _TXT)
	return l
