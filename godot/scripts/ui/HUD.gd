extends CanvasLayer
## HD 2D isometric HUD — health/stamina bars + floating message log.
## All data comes from SignalBus; no direct player reference needed.
## Octopath parchment/bronze styling — see UITheme.gd for the shared palette.

const UITheme = preload("res://scripts/ui/UITheme.gd")

# ── palette (delegates to UITheme) ─────────────────────────────────────────────
const _HP_COL   := UITheme.BLOOD
const _STM_COL  := UITheme.OLIVE
const _MANA_COL := UITheme.MANA
const _XP_COL   := UITheme.GOLD
const _TXT      := UITheme.IVORY
const _GOLD     := UITheme.GOLD

# ── layout ────────────────────────────────────────────────────────────────────
const _PANEL_MARGIN := 20.0   # 9-slice inset for the slim HUD strip (vs UITheme default 48)
const _PAD     := 22.0
const _BAR_W   := 190.0
const _BAR_H   := 14.0
const _XP_BAR_H := 9.0        # thin XP bar — ~60% of the other bars' height
const _ROW_H   := 28.0
const _XP_ROW_H := 22.0
const _ICON_W  := 20.0
const _LABEL_W := 62.0
const _LVL_W   := 44.0        # "Lv N" numeral width, left of the XP bar
const _P_W     := _PAD + _ICON_W + _BAR_W + _PAD + _LABEL_W + _PAD
const _P_H     := _PAD + _ROW_H * 3.0 + _XP_ROW_H + 30.0  # extra bottom room clears the corner filigree
const _ML      := 20.0   # left margin from screen edge
const _MB      := 84.0   # distance from screen bottom to panel top

# ── runtime state ─────────────────────────────────────────────────────────────
var _hp_ratio   := 1.0
var _stam_ratio := 1.0
var _mana_ratio := 1.0
var _xp_ratio   := 0.0

# ── node refs ─────────────────────────────────────────────────────────────────
var _flash      : ColorRect
var _panel      : Panel
var _hp_bg      : Panel
var _hp_fill    : ColorRect
var _hp_icon    : Label
var _hp_label   : Label
var _mana_bg    : Panel
var _mana_fill  : ColorRect
var _mana_icon  : Label
var _stam_bg    : Panel
var _stam_fill  : ColorRect
var _stam_icon  : Label
var _xp_bg      : Panel
var _xp_fill    : ColorRect
var _xp_label   : Label
var _lvl_label  : Label
var _msg_box    : VBoxContainer
var _death_scr  : ColorRect

# ── skill slots ───────────────────────────────────────────────────────────────
const _SLOT_SIZE := 48.0
const _SLOT_GAP  := 10.0
const _SLOT_MB   := 24.0   # distance from screen bottom
const _SLOT_MR   := 24.0   # distance from screen right
const _SKILLS := [
	{"id": "whirlwind", "key": "Q", "level": 2, "icon": "res://sprites/skill-whirlwind.png"},
	{"id": "charge",    "key": "B", "level": 4, "icon": "res://sprites/skill-charge.png"},
]
var _skill_slots: Array = []   # one Dictionary of node refs per entry in _SKILLS
var _player_level := 1


func _ready() -> void:
	layer = 10
	_build()
	_connect_signals()


# ── signal connections ────────────────────────────────────────────────────────

func _connect_signals() -> void:
	SignalBus.player_health_changed.connect(_on_health)
	SignalBus.player_stamina_changed.connect(_on_stamina)
	SignalBus.player_mana_changed.connect(_on_mana)
	SignalBus.player_xp_changed.connect(_on_xp)
	SignalBus.player_died.connect(_on_died)
	SignalBus.hud_message.connect(_post_message)
	SignalBus.player_level_up.connect(_on_level_up)
	SignalBus.player_skill_cooldown.connect(_on_skill_cooldown)

func _on_health(hp: int, mhp: int) -> void:
	_hp_ratio = clampf(float(hp) / float(max(1, mhp)), 0.0, 1.0)
	_hp_label.text = "%d/%d" % [hp, mhp]

func _on_stamina(s: float, ms: float) -> void:
	_stam_ratio = clampf(s / max(1.0, ms), 0.0, 1.0)

func _on_mana(m: float, mm: float) -> void:
	_mana_ratio = clampf(m / max(1.0, mm), 0.0, 1.0)

func _on_xp(xp: int, xp_needed: int, level: int) -> void:
	_xp_ratio = clampf(float(xp) / float(max(1, xp_needed)), 0.0, 1.0)
	_lvl_label.text = "Lv %d" % level
	_xp_label.text = "%d/%d" % [xp, xp_needed]
	_player_level = level

func _on_level_up(_level: int) -> void:
	for slot in _skill_slots:
		if slot["def"]["level"] == _level:
			_flash_slot(slot)

func _on_skill_cooldown(id: String, cur: float, mx: float) -> void:
	if cur >= mx:
		for slot in _skill_slots:
			if slot["def"]["id"] == id:
				_flash_slot(slot)

func _on_died() -> void:
	_death_scr.visible = true
	var tw := _death_scr.create_tween()
	tw.tween_property(_death_scr, "color:a", 0.88, 0.8)


# ── UI construction ───────────────────────────────────────────────────────────

func _build() -> void:
	# full-screen damage flash (topmost layer)
	_flash = ColorRect.new()
	_flash.color = Color.TRANSPARENT
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	# parchment panel behind bars — smaller 9-slice margin so the strip isn't swallowed
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", UITheme.panel_style(_PANEL_MARGIN))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# HP row
	_hp_bg    = _track()
	_hp_fill  = _fill(_HP_COL)
	_hp_icon  = _lbl("♥", 14, _HP_COL)
	_hp_label = _num_lbl("120/120", 13, _TXT)

	# Mana row
	_mana_bg   = _track()
	_mana_fill = _fill(_MANA_COL)
	_mana_icon = _lbl("✦", 14, _MANA_COL)

	# Stamina row
	_stam_bg   = _track()
	_stam_fill = _fill(_STM_COL)
	_stam_icon = _lbl("⚡", 14, _STM_COL)

	# XP row — "Lv N" left, thin bar center, xp numerals right
	_xp_bg    = _track()
	_xp_fill  = _fill(_XP_COL)
	_lvl_label = _num_lbl("Lv 1", 15, _GOLD)
	_xp_label  = _num_lbl("0/100", 12, _TXT)

	# message log — stacks vertically, most recent at bottom
	_msg_box = VBoxContainer.new()
	_msg_box.alignment = BoxContainer.ALIGNMENT_END
	_msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_msg_box)

	# death screen (starts invisible, fades in on player_died)
	_death_scr = ColorRect.new()
	_death_scr.color = Color(0.04, 0.02, 0.02, 0.0)
	_death_scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_scr.visible = false
	_death_scr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_death_content(_death_scr)
	add_child(_death_scr)

	_build_skill_slots()


func _build_death_content(parent: ColorRect) -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	cc.add_child(vb)

	var title := Label.new()
	title.text = "YOU HAVE FALLEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_header_font(title, 54)
	title.add_theme_color_override("font_color", _HP_COL)
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "press Escape to return"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", _GOLD)
	vb.add_child(sub)


# ── skill slots ───────────────────────────────────────────────────────────────

func _build_skill_slots() -> void:
	for def in _SKILLS:
		var root := Panel.new()
		root.add_theme_stylebox_override("panel", UITheme.slot_style(UITheme.PARCHMENT, UITheme.BRONZE))
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.custom_minimum_size = Vector2(_SLOT_SIZE, _SLOT_SIZE)
		root.clip_contents = true
		add_child(root)

		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.clip_contents = true
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(def["icon"]):
			icon.texture = load(def["icon"])
		root.add_child(icon)

		# cooldown sweep — dark overlay that shrinks from full height as cd elapses
		var cd_overlay := ColorRect.new()
		cd_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
		cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(cd_overlay)

		var cd_label := Label.new()
		cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_label.add_theme_color_override("font_color", _TXT)
		cd_label.add_theme_font_size_override("font_size", 16)
		cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(cd_label)

		var lock_label := Label.new()
		lock_label.text = "Lv %d" % def["level"]
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_label.add_theme_color_override("font_color", _GOLD)
		UITheme.apply_header_font(lock_label, 12)
		lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(lock_label)

		var key_label := Label.new()
		key_label.text = def["key"]
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		key_label.add_theme_color_override("font_color", _GOLD)
		key_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		key_label.add_theme_constant_override("shadow_offset_x", 1)
		key_label.add_theme_constant_override("shadow_offset_y", 1)
		UITheme.apply_header_font(key_label, 11)
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(key_label)

		_skill_slots.append({
			"def": def, "root": root, "icon": icon, "cd_overlay": cd_overlay,
			"cd_label": cd_label, "lock_label": lock_label, "key_label": key_label,
		})


func _flash_slot(slot: Dictionary) -> void:
	var root: Panel = slot["root"]
	root.modulate = Color(1.6, 1.5, 1.0, 1.0)
	var tw := create_tween()
	tw.tween_property(root, "modulate", Color(1, 1, 1, 1), 0.4)


func _layout_skill_slots(vs: Vector2) -> void:
	var n := _skill_slots.size()
	for i in range(n):
		var slot: Dictionary = _skill_slots[i]
		var root: Panel = slot["root"]
		var rx := vs.x - _SLOT_MR - (n - i) * _SLOT_SIZE - (n - i - 1) * _SLOT_GAP
		var ry := vs.y - _SLOT_MB - _SLOT_SIZE
		root.position = Vector2(rx, ry)
		root.size     = Vector2(_SLOT_SIZE, _SLOT_SIZE)

		# icon/overlay/labels are children of root (a Panel) — their position is
		# LOCAL to root's top-left corner, not canvas space. Do not add root.position.
		var icon: TextureRect = slot["icon"]
		var inset := 4.0
		icon.position = Vector2(inset, inset)
		icon.size     = Vector2(_SLOT_SIZE - inset * 2.0, _SLOT_SIZE - inset * 2.0)

		var cd_overlay: ColorRect = slot["cd_overlay"]
		cd_overlay.position = Vector2.ZERO  # height set per-frame in _update_skill_slots

		var lock_label: Label = slot["lock_label"]
		lock_label.position = Vector2.ZERO
		lock_label.size     = Vector2(_SLOT_SIZE, _SLOT_SIZE)

		var key_label: Label = slot["key_label"]
		key_label.position = Vector2.ZERO
		key_label.size     = Vector2(_SLOT_SIZE - 3.0, _SLOT_SIZE - 2.0)


const _SKILL_CD_MAX := {"whirlwind": 6.0, "charge": 8.0}
const _SKILL_CD_FIELD := {"whirlwind": "_ww_cd", "charge": "_charge_cd"}

func _update_skill_slots() -> void:
	# Cooldown floats live on Player, not SignalBus — polling one group lookup
	# per frame is the cheapest way to read them (matches InventoryUI's pattern).
	var player := get_tree().get_first_node_in_group("player")
	for slot in _skill_slots:
		var def: Dictionary = slot["def"]
		var icon: TextureRect = slot["icon"]
		var cd_overlay: ColorRect = slot["cd_overlay"]
		var cd_label: Label = slot["cd_label"]
		var lock_label: Label = slot["lock_label"]

		var locked := _player_level < int(def["level"])
		var cd: float = 0.0
		if player != null:
			cd = float(player.get(_SKILL_CD_FIELD[def["id"]]))
		var cd_max: float = _SKILL_CD_MAX[def["id"]]

		icon.modulate = Color(0.25, 0.25, 0.25, 1.0) if locked else Color(1, 1, 1, 1)
		lock_label.visible = locked
		cd_overlay.visible = not locked and cd > 0.0
		cd_label.visible = not locked and cd > 1.0
		if cd_overlay.visible:
			# Local to root — sweeps down from the top as cooldown elapses.
			var frac := clampf(cd / cd_max, 0.0, 1.0)
			cd_overlay.position = Vector2.ZERO
			cd_overlay.size     = Vector2(_SLOT_SIZE, _SLOT_SIZE * frac)
		if cd_label.visible:
			cd_label.text = str(int(ceil(cd)))


# ── per-frame layout ──────────────────────────────────────────────────────────

func _process(_dt: float) -> void:
	var vs  := get_viewport().get_visible_rect().size
	var px  := _ML
	var py  := vs.y - _MB - _P_H

	# panel background
	_panel.position = Vector2(px, py)
	_panel.size     = Vector2(_P_W, _P_H)

	# HP row
	_layout_row(_hp_icon, _hp_bg, _hp_fill, px, py + _PAD, _hp_ratio)
	_hp_label.position = Vector2(px + _PAD + _ICON_W + _BAR_W + 4.0, py + _PAD - 2.0)

	# Mana row
	_layout_row(_mana_icon, _mana_bg, _mana_fill, px, py + _PAD + _ROW_H, _mana_ratio)

	# Stamina row — colour shifts orange when low
	_layout_row(_stam_icon, _stam_bg, _stam_fill, px, py + _PAD + _ROW_H * 2.0, _stam_ratio)
	var low_t := 1.0 - clampf(_stam_ratio / 0.25, 0.0, 1.0)
	_stam_fill.color = _STM_COL.lerp(Color(0.87, 0.35, 0.08), low_t)

	# XP row — "Lv N" (gold, prominent) left, bar center, "xp/needed" right.
	# All three share the row's vertical center so nothing clips the border art.
	var xp_row_y := py + _PAD + _ROW_H * 3.0
	var bar_x := px + _PAD + _LVL_W + 4.0
	var bar_w := _ICON_W + _BAR_W - _LVL_W - 4.0
	_lvl_label.position = Vector2(px + _PAD, xp_row_y)
	_lvl_label.size     = Vector2(_LVL_W, _XP_ROW_H)
	_lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_lvl_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_xp_bg.position   = Vector2(bar_x, xp_row_y + (_XP_ROW_H - _XP_BAR_H) * 0.5)
	_xp_bg.size       = Vector2(bar_w, _XP_BAR_H)
	_xp_fill.position = _xp_bg.position + Vector2(1.5, 1.5)
	_xp_fill.size     = Vector2((bar_w - 3.0) * _xp_ratio, _XP_BAR_H - 3.0)
	_xp_label.position = Vector2(px + _PAD + _ICON_W + _BAR_W + 4.0, xp_row_y)
	_xp_label.size     = Vector2(_LABEL_W, _XP_ROW_H)
	_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# message log above the panel
	_msg_box.position = Vector2(px, py - 118.0)
	_msg_box.size     = Vector2(380.0, 110.0)

	_layout_skill_slots(vs)
	_update_skill_slots()


func _layout_row(icon: Label, bg: Panel, fill: ColorRect,
		px: float, row_y: float, ratio: float) -> void:
	icon.position = Vector2(px + _PAD, row_y)
	var bx        := px + _PAD + _ICON_W
	bg.position   = Vector2(bx, row_y + 2.0)
	bg.size       = Vector2(_BAR_W, _BAR_H)
	fill.position = bg.position + Vector2(1.5, 1.5)
	fill.size     = Vector2((_BAR_W - 3.0) * ratio, _BAR_H - 3.0)


# ── messages ──────────────────────────────────────────────────────────────────

func _post_message(text: String, duration: float) -> void:
	var strip := Panel.new()
	# small strip — thin 9-slice inset so the border doesn't swallow a one-line toast
	strip.add_theme_stylebox_override("panel", UITheme.panel_style(10.0))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.custom_minimum_size = Vector2(0, 26)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", _TXT)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pad := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(s, 4)
	pad.add_child(lbl)
	strip.add_child(pad)
	_msg_box.add_child(strip)

	while _msg_box.get_child_count() > 6:
		_msg_box.get_child(0).queue_free()

	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(strip, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func() -> void:
		if is_instance_valid(strip): strip.queue_free())


func flash_damage() -> void:
	_flash.color = Color(0.8, 0.1, 0.05, 0.30)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.4)


# ── helpers ───────────────────────────────────────────────────────────────────

func _track() -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UITheme.bar_track_style())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _fill(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _lbl(text: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _num_lbl(text: String, size: int, c: Color) -> Label:
	var l := _lbl(text, size, c)
	UITheme.apply_header_font(l, size)
	return l
