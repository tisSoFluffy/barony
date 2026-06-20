extends Node
## Root of the game. For now it just boots; the menu/world wiring lands next.

func _ready() -> void:
	print("Barony of Azeroth — Godot port booting on Godot %s" % Engine.get_version_info().string)
	print("Autoloads OK: Util=%s Classes=%s Bestiary=%s Art=%s" % [
		Util != null, Classes != null, Bestiary != null, Art != null])
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--gametest" in args:
		_run_tests()
		get_tree().quit(0)
		return
	if "--smoke" in args:
		await get_tree().create_timer(0.2).timeout
		print("SMOKE OK")
		get_tree().quit(0)

func _run_tests() -> void:
	print("--- DATA ---")
	print("classes: %d, enemies: %d" % [Classes.defs.size(), Bestiary.defs.size()])
	assert(Classes.defs.size() == 6)
	assert(Bestiary.defs.size() == 7)

	print("--- DUNGEON GEN (floors 1..5) ---")
	for d in range(1, 6):
		Util.seed_floor("", d)
		var lv := Dungeon.generate(d)
		var doors := 0; var locked := 0; var floor_t := 0
		for t in lv.tiles:
			if t == 0: floor_t += 1
			elif t == 8: doors += 1
			elif t == 9: locked += 1
		print("d%d: rooms=%d enemies=%d items=%d floors=%d doors=%d locked=%d boss=%s" % [
			d, lv.rooms.size(), lv.enemies.size(), lv.items.size(), floor_t, doors, locked, lv.boss])
		assert(lv.rooms.size() >= 2)
		assert(lv.start is Vector2)

	print("--- DETERMINISM ---")
	Util.seed_floor("AZEROTH", 1)
	var a := Dungeon.generate(1)
	Util.seed_floor("AZEROTH", 1)
	var b := Dungeon.generate(1)
	Util.seed_floor("OTHER", 1)
	var c := Dungeon.generate(1)
	var same: bool = a.tiles == b.tiles
	var diff: bool = a.tiles != c.tiles
	print("same seed identical: %s | different seed differs: %s" % [same, diff])
	assert(same and diff)

	print("--- SPRITE FACTORY (CPU render) ---")
	var pt := Painter.new(48, 48)
	pt.rrect(Painter.hex("4e8f3a"), 8, 8, 32, 32, 4)
	pt.dot(Painter.hex("ff3020"), 18, 20, 3)
	pt.tri(Painter.hex("f0ead8"), 24, 30, 28, 18, 32, 30)
	var im := pt.img
	var non_empty := false
	for yy in range(48):
		for xx in range(48):
			if im.get_pixel(xx, yy).a > 0.5:
				non_empty = true
				break
		if non_empty: break
	print("painter produced pixels: %s" % non_empty)
	im.save_png("user://painter_test.png")
	print("ALL TESTS PASSED")
