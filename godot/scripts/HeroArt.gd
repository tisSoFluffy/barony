extends RefCounted
class_name HeroArt
## Procedural hero/item/prop billboards, ported from the web build.
## Avatar sizes 64x84. Item sizes per the web S(w,h) — see comments.

static func draw_footman(g: Painter) -> void:
	g.line(Painter.hex("9aa6b4"), 55, 10, 55, 40, 3.4)
	g.tri(Painter.hex("ccd6e0"), 52, 12, 55, 2, 58, 12)
	g.rrect(Painter.hex("5a6674"), 23, 58, 9, 16, 3); g.rrect(Painter.hex("5a6674"), 33, 58, 9, 16, 3)
	g.rrect(Painter.hex("2c3038"), 21, 71, 12, 9, 3); g.rrect(Painter.hex("2c3038"), 32, 71, 12, 9, 3)
	g.rrect(Painter.hex("8a96a4"), 18, 32, 29, 29, 6)
	g.rrect(Painter.hex("2858c8"), 25, 34, 15, 26, 3)
	g.ell(Painter.hex("d8b050"), 32, 45, 4, 5)
	g.rrect(Painter.hex("7a8694"), 10, 34, 10, 22, 4); g.rrect(Painter.hex("7a8694"), 45, 34, 10, 22, 4)
	g.ell(Painter.hex("6a7684"), 14, 57, 5, 5); g.ell(Painter.hex("6a7684"), 50, 57, 5, 5)
	g.shp(Painter.hex("3a66c8"), func(p): p.move_to(2, 36); p.line_to(22, 36); p.line_to(20, 56); p.line_to(12, 64); p.line_to(4, 56))
	g.ell(Painter.hex("d8b050"), 12, 46, 4, 5)
	g.ell(Painter.hex("9aa6b4"), 15, 31, 10, 7); g.ell(Painter.hex("9aa6b4"), 50, 31, 10, 7)
	g.ell(Painter.hex("d8b890"), 32, 18, 9, 9)
	g.rect_fill(Painter.hex("170f06"), 28, 17, 3, 3); g.rect_fill(Painter.hex("170f06"), 35, 17, 3, 3)
	g.rect_fill(Painter.hex("a86838"), 28, 23, 9, 2.5)
	g.shp(Painter.hex("9aa6b4"), func(p): p.move_to(22, 16); p.quad_to(22, 5, 32, 4); p.quad_to(42, 5, 42, 16); p.line_to(38, 16); p.quad_to(38, 9, 32, 9); p.quad_to(26, 9, 26, 16))
	g.tri(Painter.hex("d8b050"), 30, 5, 32, 0, 34, 5)

static func draw_mage_hero(g: Painter) -> void:
	g.line(Painter.hex("6a4c2c"), 52, 14, 52, 72, 3.4)
	g.dot(Painter.hex("70d8ff"), 52, 10, 5); g.dot(Painter.hex("e8fbff"), 52, 10, 2)
	g.shp(Painter.hex("4a3a78"), func(p): p.move_to(20, 32); p.line_to(44, 32); p.line_to(50, 76); p.line_to(14, 76))
	g.rrect(Painter.hex("3a2c60"), 14, 70, 36, 7, 3)
	g.rrect(Painter.hex("d8b050"), 22, 48, 20, 5, 2)
	g.rrect(Painter.hex("3a2c60"), 10, 34, 10, 22, 4); g.rrect(Painter.hex("3a2c60"), 44, 34, 10, 22, 4)
	g.ell(Painter.hex("d8b890"), 14, 57, 4, 4); g.ell(Painter.hex("d8b890"), 49, 57, 4, 4)
	g.ell(Painter.hex("e0c0a0"), 32, 20, 8, 9)
	g.rect_fill(Painter.hex("e8e8e8"), 26, 24, 12, 7)
	g.ell(Painter.hex("e8e8e8"), 32, 30, 7, 6)
	g.dot(Painter.hex("40c8ff"), 29, 18, 1.6); g.dot(Painter.hex("40c8ff"), 36, 18, 1.6)
	g.shp(Painter.hex("4a3a78"), func(p): p.move_to(20, 22); p.quad_to(20, 4, 32, 3); p.quad_to(44, 4, 44, 22); p.quad_to(38, 14, 32, 14); p.quad_to(26, 14, 20, 22))
	g.tri(Painter.hex("4a3a78"), 40, 8, 52, 2, 44, 14)

static func draw_hunter_hero(g: Painter) -> void:
	g.rrect(Painter.hex("5e4226"), 38, 16, 9, 34, 4)
	for i in range(3):
		g.line(Painter.hex("170f06"), 40 + i * 3, 18, 40 + i * 3, 8, 2.2)
	g.tri(Painter.hex("c8d8c0"), 39, 10, 42, 4, 45, 10); g.tri(Painter.hex("c8d8c0"), 42, 9, 45, 3, 48, 9); g.tri(Painter.hex("c8d8c0"), 45, 10, 48, 4, 51, 10)
	g.rrect(Painter.hex("5e4226"), 24, 60, 8, 15, 3); g.rrect(Painter.hex("5e4226"), 33, 60, 8, 15, 3)
	g.rrect(Painter.hex("3a2a16"), 22, 72, 11, 9, 3); g.rrect(Painter.hex("3a2a16"), 32, 72, 11, 9, 3)
	g.shp(Painter.hex("3a6a3a"), func(p): p.move_to(16, 36); p.line_to(49, 36); p.line_to(46, 64); p.line_to(32, 70); p.line_to(18, 64))
	g.rrect(Painter.hex("6a4c2c"), 20, 34, 25, 28, 6)
	g.rrect(Painter.hex("4e8a4a"), 26, 36, 13, 22, 3)
	g.rrect(Painter.hex("3a2a16"), 20, 52, 25, 5, 2); g.dot(Painter.hex("d8b050"), 32, 54.5, 2)
	g.rrect(Painter.hex("5e4226"), 12, 36, 9, 20, 4); g.rrect(Painter.hex("5e4226"), 44, 36, 9, 20, 4)
	g.ell(Painter.hex("caa070"), 16, 57, 4.5, 4.5); g.ell(Painter.hex("caa070"), 48, 57, 4.5, 4.5)
	g.ell(Painter.hex("3a6a3a"), 18, 34, 9, 6); g.ell(Painter.hex("3a6a3a"), 47, 34, 9, 6)
	g.shp(Painter.hex("6a4c2c"), func(p): p.move_to(10, 18); p.quad_to(0, 46, 10, 72); p.quad_to(2, 46, 10, 18))
	g.line(Painter.hex("e8e0c8"), 10, 18, 10, 72, 1.4)
	g.ell(Painter.hex("d8b890"), 32, 20, 9, 9)
	g.rect_fill(Painter.hex("170f06"), 28, 19, 3, 3); g.rect_fill(Painter.hex("170f06"), 35, 19, 3, 3)
	g.dot(Painter.hex("e8b840"), 29.5, 20.5, 0.9); g.dot(Painter.hex("e8b840"), 36.5, 20.5, 0.9)
	g.rect_fill(Painter.hex("a86838"), 29, 25, 7, 2)
	g.shp(Painter.hex("3a6a3a"), func(p): p.move_to(22, 18); p.quad_to(22, 5, 32, 4); p.quad_to(42, 5, 42, 18); p.line_to(38, 18); p.quad_to(38, 9, 32, 9); p.quad_to(26, 9, 26, 18))
	g.tri(Painter.hex("4e8a4a"), 30, 5, 32, -1, 34, 5)

static func draw_paladin_hero(g: Painter) -> void:
	g.line(Painter.hex("caa84a"), 55, 14, 55, 42, 3.4)
	g.rrect(Painter.hex("e8c84a"), 49, 4, 13, 14, 3)
	g.dot(Color(1.0, 0.925, 0.588, 0.35), 55, 11, 11)
	g.rrect(Painter.hex("d8b050"), 51, 6, 3, 10, 1)
	g.rrect(Painter.hex("5a6674"), 23, 58, 9, 16, 3); g.rrect(Painter.hex("5a6674"), 33, 58, 9, 16, 3)
	g.rrect(Painter.hex("2c3038"), 21, 71, 12, 9, 3); g.rrect(Painter.hex("2c3038"), 32, 71, 12, 9, 3)
	g.ell(Painter.hex("e8c84a"), 27, 73, 4, 3); g.ell(Painter.hex("e8c84a"), 38, 73, 4, 3)
	g.rrect(Painter.hex("c9cdd6"), 18, 32, 29, 29, 6)
	g.rrect(Painter.hex("e8e4d4"), 25, 34, 15, 26, 3)
	g.dot(Painter.hex("e8c84a"), 32, 45, 4); g.tri(Painter.hex("d8b050"), 32, 40, 28, 47, 36, 47)
	g.rrect(Painter.hex("9aa0ac"), 10, 34, 10, 22, 4); g.rrect(Painter.hex("9aa0ac"), 45, 34, 10, 22, 4)
	g.ell(Painter.hex("c9cdd6"), 14, 57, 5, 5); g.ell(Painter.hex("c9cdd6"), 50, 57, 5, 5)
	g.ell(Painter.hex("e8c84a"), 15, 31, 11, 7); g.ell(Painter.hex("e8c84a"), 50, 31, 11, 7)
	g.ell(Painter.hex("9aa0ac"), 15, 31, 7, 4); g.ell(Painter.hex("9aa0ac"), 50, 31, 7, 4)
	g.shp(Painter.hex("e8c84a"), func(p): p.move_to(22, 15); p.quad_to(20, 9, 32, 5); p.quad_to(44, 9, 42, 15); p.line_to(38, 16); p.quad_to(36, 11, 32, 11); p.quad_to(28, 11, 26, 16))
	g.ell(Painter.hex("d8b890"), 32, 18, 9, 9)
	g.rect_fill(Painter.hex("170f06"), 28, 17, 3, 3); g.rect_fill(Painter.hex("170f06"), 35, 17, 3, 3)
	g.shp(Painter.hex("c9cdd6"), func(p): p.move_to(22, 16); p.quad_to(22, 4, 32, 3); p.quad_to(42, 4, 42, 16); p.line_to(38, 16); p.quad_to(38, 8, 32, 8); p.quad_to(26, 8, 26, 16))
	g.tri(Painter.hex("e8e4d4"), 20, 12, 12, 4, 21, 7); g.tri(Painter.hex("e8e4d4"), 44, 12, 52, 4, 43, 7)
	g.rrect(Painter.hex("e8c84a"), 30, 4, 4, 5, 1)

static func draw_rogue_hero(g: Painter) -> void:
	g.rrect(Painter.hex("2a2630"), 24, 58, 8, 16, 3); g.rrect(Painter.hex("2a2630"), 33, 58, 8, 16, 3)
	g.rrect(Painter.hex("1e1c24"), 22, 71, 11, 9, 3); g.rrect(Painter.hex("1e1c24"), 32, 71, 11, 9, 3)
	g.tri(Painter.hex("1e1c24"), 18, 33, 46, 33, 40, 72); g.tri(Painter.hex("1e1c24"), 46, 33, 18, 33, 24, 72)
	g.rrect(Painter.hex("3a3340"), 21, 32, 22, 28, 6)
	g.shp(Painter.hex("9a2030"), func(p): p.move_to(21, 40); p.line_to(43, 34); p.line_to(43, 42); p.line_to(21, 48))
	g.rrect(Painter.hex("b8303c"), 20, 49, 24, 5, 2)
	g.rrect(Painter.hex("2a2630"), 12, 34, 9, 21, 4); g.rrect(Painter.hex("2a2630"), 43, 34, 9, 21, 4)
	g.ell(Painter.hex("3a2c22"), 15, 56, 5, 5); g.ell(Painter.hex("3a2c22"), 49, 56, 5, 5)
	g.shp(Painter.hex("ccd6e0"), func(p): p.move_to(13, 58); p.quad_to(8, 68, 12, 77); p.quad_to(15, 69, 16, 60))
	g.shp(Painter.hex("ccd6e0"), func(p): p.move_to(51, 58); p.quad_to(56, 68, 52, 77); p.quad_to(49, 69, 48, 60))
	g.rrect(Painter.hex("1e1c24"), 11, 55, 8, 4, 2); g.rrect(Painter.hex("1e1c24"), 45, 55, 8, 4, 2)
	g.shp(Painter.hex("2a2630"), func(p): p.move_to(20, 24); p.quad_to(32, 6, 44, 24); p.line_to(44, 30); p.quad_to(32, 22, 20, 30))
	g.ell(Painter.hex("d8b890"), 32, 22, 8, 8)
	g.rrect(Painter.hex("1e1c24"), 24, 23, 16, 8, 3)
	g.shp(Painter.hex("2a2630"), func(p): p.move_to(20, 24); p.quad_to(32, 8, 44, 24); p.line_to(40, 20); p.quad_to(32, 12, 24, 20))
	g.dot(Painter.hex("c8d8e0"), 28, 19, 1.6); g.dot(Painter.hex("c8d8e0"), 36, 19, 1.6)

static func draw_warlock_hero(g: Painter) -> void:
	g.shp(Painter.hex("2e2440"), func(p): p.move_to(20, 32); p.line_to(44, 32); p.line_to(50, 76); p.line_to(14, 76))
	g.shp(Painter.hex("1e1830"), func(p): p.move_to(32, 32); p.line_to(44, 32); p.line_to(50, 76); p.line_to(32, 76))
	g.rrect(Painter.hex("241a38"), 14, 70, 36, 7, 3)
	g.dot(Painter.hex("7aff50"), 20, 73, 1.4); g.dot(Painter.hex("7aff50"), 27, 73, 1.4); g.dot(Painter.hex("7aff50"), 34, 73, 1.4); g.dot(Painter.hex("7aff50"), 41, 73, 1.4)
	g.rrect(Painter.hex("241a38"), 22, 48, 20, 5, 2)
	g.dot(Painter.hex("d8b050"), 32, 50.5, 2.2)
	g.dot(Painter.hex("7aff50"), 32, 50.5, 1.1)
	g.rrect(Painter.hex("2e2440"), 10, 34, 10, 22, 4)
	g.rrect(Painter.hex("2e2440"), 44, 34, 10, 22, 4)
	g.line(Painter.hex("7aff50"), 15, 36, 15, 54, 1.6)
	g.line(Painter.hex("7aff50"), 49, 36, 49, 54, 1.6)
	g.ell(Painter.hex("c8c0b0"), 14, 57, 4, 4)
	g.ell(Painter.hex("c8c0b0"), 49, 52, 4, 4)
	g.dot(Color(0.471, 1.0, 0.314, 0.30), 49, 40, 9)
	g.dot(Painter.hex("5ad838"), 49, 40, 5)
	g.dot(Painter.hex("bcff8a"), 47.5, 38.5, 2)
	g.line(Painter.hex("9aff6a"), 49, 35, 51, 31, 1.4); g.line(Painter.hex("9aff6a"), 51, 31, 49.5, 33, 1.4)
	g.line(Painter.hex("9aff6a"), 45, 40, 41, 38, 1.4)
	g.ell(Painter.hex("c8c0b0"), 32, 20, 8, 9)
	g.rect_fill(Painter.hex("a89a86"), 28, 24, 8, 4)
	g.dot(Painter.hex("7aff50"), 29, 18, 1.8); g.dot(Painter.hex("7aff50"), 36, 18, 1.8)
	g.dot(Painter.hex("d6ffb8"), 29, 18, 0.7); g.dot(Painter.hex("d6ffb8"), 36, 18, 0.7)
	g.shp(Painter.hex("2e2440"), func(p): p.move_to(20, 22); p.quad_to(20, 4, 32, 3); p.quad_to(44, 4, 44, 22); p.quad_to(38, 14, 32, 14); p.quad_to(26, 14, 20, 22))
	g.line(Painter.hex("7aff50"), 21, 20, 32, 8, 1.6)
	g.line(Painter.hex("7aff50"), 32, 8, 43, 20, 1.6)
	g.shp(Painter.hex("1e1830"), func(p): p.move_to(21, 9); p.quad_to(16, 4, 15, 8); p.quad_to(18, 8, 21, 12))
	g.shp(Painter.hex("1e1830"), func(p): p.move_to(43, 9); p.quad_to(48, 4, 49, 8); p.quad_to(46, 8, 43, 12))

# ---------- items & props ----------
static func draw_potion(g: Painter, col: Color, glow: Color) -> void:
	g.ell(col, 11, 16, 8, 8)
	g.rrect(Color(0.722, 0.769, 0.800, 0.533), 8, 3, 6, 8, 2)
	g.rrect(Painter.hex("8a6a42"), 7.5, 1, 7, 4, 1.5)
	g.dot(glow, 8, 13, 2.4)

static func draw_meat(g: Painter) -> void:
	g.ell(Painter.hex("9a5430"), 10, 11, 9, 8)
	g.ell(Painter.hex("b8683a"), 9, 9, 6, 5)
	g.rrect(Painter.hex("e8e0d0"), 17, 8, 8, 5, 2.5)
	g.dot(Painter.hex("e8e0d0"), 24, 8, 3); g.dot(Painter.hex("e8e0d0"), 24, 13, 3)

static func draw_gold(g: Painter) -> void:
	g.ell(Painter.hex("e8b830"), 8, 12, 6, 4); g.ell(Painter.hex("e8b830"), 18, 13, 6, 4)
	g.ell(Painter.hex("ffd84a"), 13, 8, 6, 4); g.dot(Painter.hex("fff0a0"), 12, 7, 1.6)

static func draw_sword_item(g: Painter) -> void:
	g.line(Painter.hex("b8c4d0"), 6, 4, 16, 18, 3.6)
	g.rrect(Painter.hex("d8b050"), 13, 16, 9, 4, 2)
	g.rrect(Painter.hex("5e4226"), 16.5, 19, 4, 8, 2)

static func draw_staff_item(g: Painter) -> void:
	g.line(Painter.hex("6a4c2c"), 10, 30, 14, 8, 3.4)
	g.dot(Painter.hex("70d8ff"), 14, 6, 5); g.dot(Painter.hex("e8fbff"), 14, 6, 2.2)

static func draw_stairs(g: Painter) -> void:
	g.rrect(Painter.hex("6a6a74"), 2, 2, 48, 40, 5)
	g.shp(Painter.hex("08060a"), func(p): p.move_to(8, 8); p.line_to(44, 8); p.line_to(44, 40); p.line_to(8, 40))
	g.rect_fill(Painter.hex("5e5e68"), 10, 10, 32, 8)
	g.rect_fill(Painter.hex("44444e"), 13, 18, 26, 8)
	g.rect_fill(Painter.hex("2c2c34"), 16, 26, 20, 7)
	g.rect_fill(Painter.hex("18181e"), 19, 33, 14, 5)
	g.dot(Painter.hex("ffce42"), 6, 6, 2); g.dot(Painter.hex("ffce42"), 46, 6, 2)

static func draw_portal(g: Painter) -> void:
	g.ell(Painter.hex("0a2a50"), 28, 35, 22, 32)
	g.ell(Painter.hex("1565c8"), 28, 35, 16, 25)
	g.ell(Painter.hex("5ec8ff"), 28, 35, 9, 16)
	g.ell(Painter.hex("dff4ff"), 28, 35, 4, 8)

static func draw_brazier(g: Painter) -> void:
	g.ell(Painter.hex("ffa020"), 18, 12, 8, 11)
	g.ell(Painter.hex("ffd860"), 18, 15, 4.5, 7)
	g.ell(Painter.hex("fff0b0"), 18, 18, 2.2, 3.5)
	g.shp(Painter.hex("3a3a40"), func(p): p.move_to(6, 22); p.line_to(30, 22); p.line_to(26, 30); p.line_to(10, 30))
	g.rrect(Painter.hex("2c2c30"), 15, 30, 6, 14, 2)
	g.shp(Painter.hex("3a3a40"), func(p): p.move_to(8, 48); p.line_to(28, 48); p.line_to(24, 43); p.line_to(12, 43))

static func draw_trap(g: Painter) -> void:
	g.rrect(Painter.hex("44444c"), 2, 16, 36, 8, 2)
	g.rect_fill(Painter.hex("33333a"), 4, 18, 32, 2)
	for i in range(5):
		g.tri(Painter.hex("aab2bc"), 5 + i * 7, 18, 8.5 + i * 7, 2, 12 + i * 7, 18)

static func draw_shrine(g: Painter) -> void:
	g.rrect(Painter.hex("6a6a74"), 8, 40, 28, 12, 3)
	g.rrect(Painter.hex("7a7a84"), 14, 22, 16, 20, 3)
	g.shp(Painter.hex("8a8a94"), func(p): p.move_to(4, 14); p.line_to(40, 14); p.line_to(34, 24); p.line_to(10, 24))
	g.ell(Painter.hex("62d8ff"), 22, 15, 14, 4)
	g.ell(Painter.hex("bdf0ff"), 22, 15, 7, 2)
	g.dot(Painter.hex("bdf0ff"), 14, 8, 1.5); g.dot(Painter.hex("bdf0ff"), 28, 5, 1.8); g.dot(Painter.hex("bdf0ff"), 22, 10, 1.2)

static func draw_key_item(g: Painter) -> void:
	g.ell(Painter.hex("e8c050"), 8, 8, 5.5, 5.5)
	g.ell(Painter.hex("16100a"), 8, 8, 2.2, 2.2)
	g.line(Painter.hex("e8c050"), 11, 11, 19, 21, 3.4)
	g.line(Painter.hex("e8c050"), 16, 21, 19, 18, 3.4)

static func draw_armor_item(g: Painter) -> void:
	g.shp(Painter.hex("8a96a4"), func(p): p.move_to(5, 4); p.line_to(21, 4); p.line_to(23, 10); p.line_to(19, 22); p.line_to(7, 22); p.line_to(3, 10))
	g.rrect(Painter.hex("2858c8"), 10, 6, 6, 14, 2)
	g.dot(Painter.hex("d8b050"), 13, 12, 2)

static func draw_helm_item(g: Painter) -> void:
	g.shp(Painter.hex("9aa6b4"), func(p): p.move_to(4, 16); p.quad_to(4, 3, 13, 2); p.quad_to(22, 3, 22, 16))
	g.rrect(Painter.hex("7a8694"), 4, 15, 18, 5, 2)
	g.tri(Painter.hex("d8b050"), 11, 4, 13, 0, 15, 4)

static func draw_ring_item(g: Painter) -> void:
	g.ell(Painter.hex("e8c050"), 11, 13, 8, 8)
	g.ell(Color(0, 0, 0, 0), 11, 13, 5, 5)
	g.dot(Painter.hex("b048f8"), 11, 4, 3)

static func draw_goblin(g: Painter) -> void:
	g.rrect(Painter.hex("5e4226"), 5, 54, 50, 18, 3)
	g.rect_fill(Painter.hex("3a2614"), 5, 60, 50, 2)
	g.ell(Painter.hex("d83030"), 13, 52, 3, 4); g.ell(Painter.hex("3060d8"), 21, 52, 3, 4)
	g.dot(Painter.hex("ffd84a"), 46, 53, 3); g.dot(Painter.hex("fff0a0"), 45, 52, 1.2)
	g.rrect(Painter.hex("7a9a3a"), 15, 34, 8, 18, 3); g.rrect(Painter.hex("7a9a3a"), 37, 34, 8, 18, 3)
	g.ell(Painter.hex("6a8a30"), 18, 50, 4, 3); g.ell(Painter.hex("6a8a30"), 41, 50, 4, 3)
	g.rrect(Painter.hex("7a9a3a"), 21, 30, 18, 24, 5)
	g.rrect(Painter.hex("6a4c2c"), 24, 33, 12, 19, 2)
	g.dot(Painter.hex("d8b050"), 30, 43, 2.2)
	g.ell(Painter.hex("7a9a3a"), 30, 19, 12, 10)
	g.ell(Painter.hex("8aaa44"), 30, 23, 4, 5)
	g.tri(Painter.hex("7a9a3a"), 17, 17, 7, 9, 19, 24)
	g.tri(Painter.hex("7a9a3a"), 43, 17, 53, 9, 41, 24)
	g.dot(Painter.hex("ffd040"), 25, 16, 2.2); g.dot(Painter.hex("ffd040"), 35, 16, 2.2)
	g.dot(Painter.hex("170f06"), 25, 16, 1); g.dot(Painter.hex("170f06"), 35, 16, 1)
	g.line(Painter.hex("170f06"), 24, 27, 30, 30, 1.6)
	g.line(Painter.hex("170f06"), 30, 30, 36, 27, 1.6)
	g.rect_fill(Painter.hex("f0ead8"), 27, 27, 2, 2); g.rect_fill(Painter.hex("f0ead8"), 31, 27, 2, 2)
	g.shp(Painter.hex("9a2a2a"), func(p): p.move_to(19, 11); p.quad_to(30, 1, 41, 11); p.quad_to(30, 8, 19, 11))
	g.dot(Painter.hex("ffd84a"), 30, 5, 2)
