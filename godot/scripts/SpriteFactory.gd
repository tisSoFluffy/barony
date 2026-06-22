extends Node
## Builds every texture in code (no external image assets), mirroring the web
## build: themed brick/floor wall textures + chunky billboard sprites. Cached.
## Autoload name: Art

# Per-depth themes: wall rgb, floor rgb, ceiling gradient (top,bottom), accent.
const THEMES := {
	1: { "wall": [110, 90, 64], "floor": [96, 78, 56], "ceil_top": "221810", "ceil_bot": "090604", "name": "the Old Mines" },
	2: { "wall": [88, 98, 92], "floor": [62, 84, 74], "ceil_top": "0c1814", "ceil_bot": "030705", "name": "the Flooded Halls" },
	3: { "wall": [96, 94, 104], "floor": [84, 82, 90], "ceil_top": "1a1410", "ceil_bot": "060404", "name": "the Crypt of the Barons" },
	4: { "wall": [112, 72, 56], "floor": [92, 62, 48], "ceil_top": "200c08", "ceil_bot": "080302", "name": "the Horde Warcamp" },
	5: { "wall": [72, 68, 88], "floor": [60, 56, 72], "ceil_top": "120e26", "ceil_bot": "050308", "name": "Gor'maul's Throne" },
}

var _wall := {}
var _floor := {}
var _door: Array = [null, null]   # [regular, locked]
var _actor := {}
var _draw_fns := {}

func _ready() -> void:
	_register_actors()

# ---------------- wall + floor textures ----------------
func wall_texture(theme: int) -> ImageTexture:
	if _wall.has(theme):
		return _wall[theme]
	var th: Dictionary = THEMES.get(theme, THEMES[1])
	var base: Array = th.wall
	var pt := Painter.new(64, 64)
	pt.rect_fill(_rgb(base, -20), 0, 0, 64, 64)
	var bh := 16
	for row in range(4):
		var off := (row % 2) * 16
		for bx in range(-1, 3):
			var x := bx * 32 + off
			var y := row * bh
			var sh := Util.li(-12, 12)
			pt.rect_fill(_rgb(base, sh), x + 1, y + 1, 30, bh - 2)
			pt.rect_fill(Color(1, 1, 1, 0.07), x + 1, y + 1, 30, 3)
			pt.rect_fill(Color(0, 0, 0, 0.28), x + 1, y + bh - 3, 30, 2)
	for i in range(80):
		var c := Color(0, 0, 0, 0.18) if Util.lf(0, 1) < 0.5 else Color(1, 1, 1, 0.07)
		pt.rect_fill(c, Util.li(0, 62), Util.li(0, 62), 2, 2)
	var tex := pt.texture()
	_wall[theme] = tex
	return tex

func floor_texture(theme: int) -> ImageTexture:
	if _floor.has(theme):
		return _floor[theme]
	var th: Dictionary = THEMES.get(theme, THEMES[1])
	var base: Array = th.floor
	var pt := Painter.new(64, 64)
	pt.rect_fill(_rgb(base, -26), 0, 0, 64, 64)
	for ty in range(2):
		for tx in range(2):
			pt.rect_fill(_rgb(base, Util.li(-9, 9)), tx * 32 + 1, ty * 32 + 1, 30, 30)
	for i in range(70):
		var c := Color(0, 0, 0, 0.16) if Util.lf(0, 1) < 0.5 else Color(1, 1, 1, 0.05)
		pt.rect_fill(c, Util.li(0, 62), Util.li(0, 62), 2, 2)
	var tex := pt.texture()
	_floor[theme] = tex
	return tex

func door_texture(locked: bool) -> ImageTexture:
	var idx := 1 if locked else 0
	if _door[idx] != null:
		return _door[idx]
	var pt := Painter.new(64, 64)
	# wood tones — locked door is darker/more weathered
	var bg    := Painter.hex("3c2008") if locked else Painter.hex("4a2c0c")
	var plk_a := Painter.hex("5c3a14") if locked else Painter.hex("6e4a1c")
	var plk_b := Painter.hex("523210") if locked else Painter.hex("624018")
	pt.rect_fill(bg, 0, 0, 64, 64)
	# 4 horizontal plank bands — 16px each in texture, stretched 3× in world
	for row in range(4):
		var y := row * 16
		pt.rect_fill(plk_a if row % 2 == 0 else plk_b, 3, y + 2, 58, 12)
		pt.rect_fill(Color(1, 1, 1, 0.10), 3, y + 2, 58, 2)   # top highlight
		pt.rect_fill(Color(0, 0, 0, 0.28), 3, y + 12, 58, 2)  # bottom shadow
	# subtle vertical grain marks
	for gx in [14, 26, 40, 52]:
		for row in range(4):
			pt.rect_fill(Color(0, 0, 0, 0.09), gx, row * 16 + 2, 1, 12)
	# iron hinges — left edge, top (~10%) and bottom (~85%) of face
	var hm := Painter.hex("6e6458")
	pt.rrect(hm, 1,  4, 9, 8)
	pt.rrect(hm, 1, 53, 9, 8)
	pt.rect_fill(Color(1, 1, 1, 0.18), 2,  5, 7, 2)
	pt.rect_fill(Color(1, 1, 1, 0.18), 2, 54, 7, 2)
	# door handle — right side, vertical center
	pt.ell(Painter.hex("8a7050"), 57, 31, 4, 5)
	pt.dot(Painter.hex("b89860"), 56, 29, 2.0)
	if locked:
		# gold keyhole escutcheon at face center
		pt.rrect(Painter.hex("9c7c10"), 26, 22, 12, 18)
		pt.rect_fill(Painter.hex("b89018"), 27, 23, 10, 16)
		pt.ell(Painter.hex("1a0e04"), 32, 28, 3, 3)      # keyhole circle
		pt.rect_fill(Painter.hex("1a0e04"), 30, 31, 4, 7) # keyhole slot
	var tex := pt.texture()
	_door[idx] = tex
	return tex

func ceil_color(theme: int) -> Color:
	var th: Dictionary = THEMES.get(theme, THEMES[1])
	return Painter.hex(th.ceil_bot)

func _rgb(base: Array, sh: int) -> Color:
	return Color(
		clampf((base[0] + sh) / 255.0, 0, 1),
		clampf((base[1] + sh) / 255.0, 0, 1),
		clampf((base[2] + sh) / 255.0, 0, 1), 1.0)

# ---------------- actor / item billboards ----------------
# id -> [width, height, Callable(Painter)]
func _register_actors() -> void:
	# Enemy + hero art comes from EnemyArt/HeroArt once present; guarded so the
	# project still runs (placeholder silhouettes) before those land.
	_try_register("orc", 64, 84, "EnemyArt", "draw_orc")
	_try_register("kobold", 48, 58, "EnemyArt", "draw_kobold")
	_try_register("murloc", 52, 62, "EnemyArt", "draw_murloc")
	_try_register("skeleton", 56, 78, "EnemyArt", "draw_skeleton")
	_try_register("troll", 56, 86, "EnemyArt", "draw_troll")
	_try_register("necro", 56, 84, "EnemyArt", "draw_necro")
	_try_register("ogre", 96, 112, "EnemyArt", "draw_ogre")
	_try_register("pfoot", 64, 84, "HeroArt", "draw_footman")
	_try_register("pmage", 64, 84, "HeroArt", "draw_mage_hero")
	_try_register("phunt", 64, 84, "HeroArt", "draw_hunter_hero")
	_try_register("ppala", 64, 84, "HeroArt", "draw_paladin_hero")
	_try_register("prog", 64, 84, "HeroArt", "draw_rogue_hero")
	_try_register("pwarl", 64, 84, "HeroArt", "draw_warlock_hero")

	# items & props
	_try_register("meat", 26, 22, "HeroArt", "draw_meat")
	_try_register("gold", 26, 18, "HeroArt", "draw_gold")
	_try_register("sword", 24, 30, "HeroArt", "draw_sword_item")
	_try_register("staff", 24, 32, "HeroArt", "draw_staff_item")
	_try_register("stairs", 52, 44, "HeroArt", "draw_stairs")
	_try_register("portal", 56, 70, "HeroArt", "draw_portal")
	_try_register("torch", 36, 52, "HeroArt", "draw_brazier")
	_try_register("trap", 40, 26, "HeroArt", "draw_trap")
	_try_register("shrine", 44, 54, "HeroArt", "draw_shrine")
	_try_register("key", 24, 26, "HeroArt", "draw_key_item")
	_try_register("armorI", 26, 26, "HeroArt", "draw_armor_item")
	_try_register("helmI", 26, 24, "HeroArt", "draw_helm_item")
	_try_register("ringI", 22, 22, "HeroArt", "draw_ring_item")
	_try_register("shop", 60, 74, "HeroArt", "draw_goblin")
	# potions take colour args (body, glow)
	_try_register("hpot", 22, 26, "HeroArt", "draw_potion", [Painter.hex("d83030"), Painter.hex("ff9a8a")])
	_try_register("mpot", 22, 26, "HeroArt", "draw_potion", [Painter.hex("3060d8"), Painter.hex("8ab8ff")])

func _try_register(id: String, w: int, h: int, cls: String, fn: String, extra: Array = []) -> void:
	var script: Variant = _global_class(cls)
	if script != null and (script as Object).has_method(fn):
		_draw_fns[id] = [w, h, Callable(script, fn), extra]

func _global_class(cls_name: String) -> Variant:
	for c in ProjectSettings.get_global_class_list():
		if c.get("class") == cls_name:
			return load(c.get("path"))
	return null

const PALETTE := {
	"orc": "4e8f3a", "kobold": "7a5a38", "murloc": "2fa48f", "skeleton": "d8d2c0",
	"troll": "2f8c88", "necro": "2e2440", "ogre": "b08a5a",
	"pfoot": "8a96a4", "pmage": "4a3a78", "phunt": "3a6a3a", "ppala": "c9cdd6",
	"prog": "2a2630", "pwarl": "2e2440",
}

func actor_texture(spr: String) -> ImageTexture:
	if _actor.has(spr):
		return _actor[spr]
	var tex: ImageTexture
	if _draw_fns.has(spr):
		var rec: Array = _draw_fns[spr]
		var pt := Painter.new(rec[0], rec[1])
		var args: Array = [pt]
		args.append_array(rec[3])
		(rec[2] as Callable).callv(args)
		tex = pt.texture()
	else:
		tex = _placeholder(spr)
	_actor[spr] = tex
	return tex

func _placeholder(spr: String) -> ImageTexture:
	var pt := Painter.new(48, 72)
	var col := Painter.hex(PALETTE.get(spr, "8a96a4"))
	pt.rrect(col, 14, 24, 20, 34, 4)
	pt.ell(col, 24, 16, 11, 11)
	pt.dot(Painter.hex("ff3020"), 20, 14, 1.8)
	pt.dot(Painter.hex("ff3020"), 28, 14, 1.8)
	return pt.texture()
