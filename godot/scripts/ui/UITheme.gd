extends RefCounted
class_name UITheme
## Octopath-style shared UI styling — palette, fonts, panel stylebox factory.
## Single source of truth so HUD/InventoryUI/DeathScreen/ShopUI stay visually consistent.

# ── palette ───────────────────────────────────────────────────────────────────
const PARCHMENT   := Color(0.118, 0.090, 0.059, 0.92)   # #1E170F panel fill
const BRONZE      := Color(0.722, 0.549, 0.278, 1.0)    # #B88C47 edge / filigree
const IVORY       := Color(0.910, 0.863, 0.753, 1.0)    # #E8DCC0 warm text
const GOLD        := Color(0.831, 0.686, 0.216, 1.0)    # #D4AF37 accent / highlight
const BLOOD       := Color(0.627, 0.188, 0.157, 1.0)    # #A03028 hp
const OLIVE       := Color(0.612, 0.612, 0.227, 1.0)    # #9C9C3A stamina
const MANA        := Color(0.25, 0.45, 0.85, 1.0)       # #4073D9 mana
const MUTED       := Color(0.478, 0.447, 0.404, 1.0)    # #7A7265 dim labels

const TRACK_DARK  := Color(0.07, 0.05, 0.03, 1.0)        # bar "empty" track

# ── fonts ─────────────────────────────────────────────────────────────────────
const FONT_PATH := "res://fonts/Cinzel-Regular.ttf"
const PANEL_TEX_PATH := "res://sprites/ui-panel.png"
const PANEL_TEX_MARGIN := 48.0

static var _cinzel: FontFile = null
static var _cinzel_loaded := false


## Cinzel font resource, lazily loaded once. Returns null if missing (caller keeps default font).
static func cinzel() -> Font:
	if not _cinzel_loaded:
		_cinzel_loaded = true
		if ResourceLoader.exists(FONT_PATH):
			_cinzel = load(FONT_PATH)
	return _cinzel


## Applies Cinzel to a Label/Button/RichTextLabel's "font" override. No-op if font missing.
static func apply_header_font(ctrl: Control, size: int) -> void:
	var f := cinzel()
	if f:
		ctrl.add_theme_font_override("font", f)
	ctrl.add_theme_font_size_override("font_size", size)


## Ornate parchment panel StyleBox — StyleBoxTexture (9-slice) if the art has landed,
## otherwise a StyleBoxFlat fallback so the restyle works before/without the asset.
## margin overrides the 9-slice inset (use a smaller value for thin strips like the HUD
## bar frame, where the full ~48px corner filigree would swallow the whole panel).
static func panel_style(margin: float = PANEL_TEX_MARGIN) -> StyleBox:
	if ResourceLoader.exists(PANEL_TEX_PATH):
		var tex: Texture2D = load(PANEL_TEX_PATH)
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left   = margin
		sb.texture_margin_right  = margin
		sb.texture_margin_top    = margin
		sb.texture_margin_bottom = margin
		return sb
	var sf := StyleBoxFlat.new()
	sf.bg_color = Color(0.12, 0.09, 0.06, 0.92)
	sf.border_color = Color(0.72, 0.55, 0.28)
	sf.set_border_width_all(2)
	return sf


## Thin bronze frame + dark inset track — used behind bar fills (HP/stamina/etc).
static func bar_track_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = TRACK_DARK
	sb.border_color = BRONZE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	return sb


## Flat fill stylebox for a bar (HP/stamina/etc), given its fill color.
static func bar_fill_style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(1)
	return sb


## Slim bronze-bordered box for inventory/shop slot rects.
static func slot_style(base: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	return sb
