extends RefCounted
class_name WeaponArt
## Simple first-person weapon views (held bottom-centre of the screen), one per
## class. Drawn on a 180x200 canvas; the weapon rises from the bottom edge.

static func get_weapon(cls: String) -> ImageTexture:
	const PNG := {
		"war":     "res://sprites/weapon-war.png",
		"paladin": "res://sprites/weapon-paladin.png",
		"rogue":   "res://sprites/weapon-rogue.png",
		"hunter":  "res://sprites/weapon-hunter.png",
		"mage":    "res://sprites/staff-mage.png",
		"warlock": "res://sprites/staff-warlock.png",
	}
	if PNG.has(cls):
		return _load_staff(PNG[cls])
	var g := Painter.new(180, 200)
	_sword(g)
	return g.texture()

static func _load_staff(path: String) -> ImageTexture:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		var g := Painter.new(180, 200)
		_staff(g, "70d8ff", "e8fbff", "4a3a78")
		return g.texture()
	var img := Image.new()
	img.load_png_from_buffer(f.get_buffer(f.get_length()))
	f.close()
	return ImageTexture.create_from_image(img)

static func _arm(g: Painter, col: String, x: float) -> void:
	g.rrect(Painter.hex(col), x, 150, 40, 60, 8)

static func _sword(g: Painter) -> void:
	_arm(g, "7a8694", 96)
	g.rrect(Painter.hex("5a6674"), 92, 150, 48, 18, 5)        # gauntlet cuff
	g.line(Painter.hex("ccd6e0"), 118, 150, 150, 24, 9)        # blade
	g.line(Painter.hex("eef2f6"), 118, 150, 150, 24, 3)        # shine
	g.rrect(Painter.hex("d8b050"), 104, 142, 34, 9, 3)         # crossguard

static func _hammer(g: Painter) -> void:
	_arm(g, "9aa0ac", 96)
	g.rrect(Painter.hex("c9cdd6"), 92, 148, 48, 16, 5)
	g.line(Painter.hex("6a4a28"), 120, 152, 138, 60, 8)        # haft
	g.dot(Color(1.0, 0.93, 0.6, 0.35), 138, 50, 30)           # holy glow
	g.rrect(Painter.hex("e8c84a"), 116, 32, 44, 34, 6)        # head
	g.rect_fill(Painter.hex("f4e08a"), 122, 38, 14, 10)
	g.dot(Painter.hex("fff4c0"), 138, 49, 6)

static func _daggers(g: Painter) -> void:
	_arm(g, "3a3340", 30)
	_arm(g, "3a3340", 110)
	g.rrect(Painter.hex("9a2030"), 28, 150, 44, 10, 3)
	g.rrect(Painter.hex("9a2030"), 108, 150, 44, 10, 3)
	g.shp(Painter.hex("ccd6e0"), func(p): p.move_to(46, 150); p.quad_to(38, 90, 58, 56); p.quad_to(64, 96, 60, 150))
	g.shp(Painter.hex("ccd6e0"), func(p): p.move_to(126, 150); p.quad_to(118, 90, 138, 56); p.quad_to(144, 96, 140, 150))

static func _staff(g: Painter, orb_a: String, orb_b: String, sleeve: String) -> void:
	g.rrect(Painter.hex(sleeve), 100, 150, 44, 60, 10)         # sleeve
	g.dot(Painter.hex("d8b890"), 122, 150, 12)                 # hand
	g.line(Painter.hex("6a4c2c"), 122, 150, 122, 40, 9)        # staff
	g.dot(Color(Painter.hex(orb_a).r, Painter.hex(orb_a).g, Painter.hex(orb_a).b, 0.4), 122, 36, 26)
	g.dot(Painter.hex(orb_a), 122, 36, 14)
	g.dot(Painter.hex(orb_b), 119, 33, 6)

static func _bow(g: Painter) -> void:
	_arm(g, "6a4c2c", 96)
	g.ell(Painter.hex("caa070"), 118, 150, 6, 8)
	# bow limbs
	g.line(Painter.hex("5e4226"), 118, 30, 70, 120, 8)
	g.line(Painter.hex("5e4226"), 70, 120, 118, 200, 8)
	g.line(Painter.hex("e8e0c8"), 118, 30, 118, 200, 2)        # string
	g.line(Painter.hex("8a6a3a"), 96, 115, 150, 115, 4)        # nocked arrow
	g.tri(Painter.hex("b8c0c8"), 150, 110, 160, 115, 150, 120)
