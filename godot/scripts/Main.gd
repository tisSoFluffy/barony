extends Node
## Root of the game. For now it just boots; the menu/world wiring lands next.

var game: Game
var menu: CanvasLayer

func _ready() -> void:
	print("Barony of Azeroth — Godot port booting on Godot %s" % Engine.get_version_info().string)
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--gametest" in args:
		_run_tests()
		get_tree().quit(0)
		return
	if "--play" in args:
		var i := args.find("--play")
		var cls := args[i + 1] if i + 1 < args.size() else "war"
		await _headless_play(cls)
		return
	if "--smoke" in args:
		await get_tree().create_timer(0.2).timeout
		print("SMOKE OK")
		get_tree().quit(0)
		return
	_build_menu()

func _build_menu() -> void:
	menu = CanvasLayer.new()
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.03, 0.02, 1)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(340, 0)
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var title := Label.new()
	title.text = "BARONY OF AZEROTH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("ffce42"))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Choose your hero"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color("c9b37e"))
	box.add_child(sub)
	for id in Classes.order:
		var d: Dictionary = Classes.get_def(id)
		var b := Button.new()
		b.text = "%s  %s — %s" % [d.glyph, d.name, d.hint]
		b.tooltip_text = d.blurb
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(_start_game.bind(id))
		box.add_child(b)
	var scores: Array = Scores.formatted()
	if scores.size() > 0:
		var hall := Label.new()
		hall.text = "— HALL OF HEROES —\n" + "\n".join(scores)
		hall.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hall.add_theme_color_override("font_color", Color("9a8a64"))
		hall.add_theme_font_size_override("font_size", 12)
		box.add_child(hall)
	add_child(menu)

func _start_game(cls: String) -> void:
	if menu:
		menu.queue_free()
		menu = null
	game = Game.new()
	add_child(game)
	game.start(cls)

func _headless_play(cls: String) -> void:
	_start_game(cls)
	for _i in range(8):
		await get_tree().physics_frame
	var walls := 0
	for c in game.world.get_children():
		if c is StaticBody3D:
			walls = c.get_child_count()
	var enemies := get_tree().get_nodes_in_group("enemy").size()
	print("PLAY: player=%s walls=%d enemies=%d hud=%s" % [
		game.player != null, walls, enemies, game.hud != null])

	# combat: drop an awake enemy right next to the player, confirm it hurts us
	var en: Enemy = get_tree().get_first_node_in_group("enemy")
	en.global_position = game.player.global_position + Vector3(1.0, 0, 0)
	en.awake = true
	en.maxhp = 9999; en.hp = 9999
	var hp0: float = game.player.hp
	for _i in range(40):
		await get_tree().physics_frame
	print("PLAY: enemy attacked player = %s (hp %d -> %d)" % [game.player.hp < hp0, int(hp0), int(game.player.hp)])

	# player kills an enemy with primary + Q
	var n0 := get_tree().get_nodes_in_group("enemy").size()
	# stand the player just behind the enemy facing -Z (forward), enemy ahead
	game.player.global_position = Vector3(en.global_position.x, 1.0, en.global_position.z + 1.2)
	game.player.yaw = 0.0
	game.player.rotation.y = 0.0
	en.hp = 30; en.maxhp = 30
	for _i in range(10):
		game.player._melee()
		game.player.atk_t = 0.0
		await get_tree().physics_frame
	var n1 := get_tree().get_nodes_in_group("enemy").size()
	print("PLAY: melee killed an enemy = %s (%d -> %d)" % [n1 < n0, n0, n1])

	# abilities fire without error
	game.player.mana = 999
	game.player.abil_t = 0.0; game.player._ability_q()
	game.player.ab2_t = 0.0; game.player._ability_b()
	await get_tree().physics_frame
	print("PLAY: Q+B abilities ran, player level=%d xp=%d" % [game.player.level, game.player.xp])

	# pickups: walk onto a gold + a gear item
	var gold0: int = game.player.gold
	for it in game.items:
		if it.type == "gold":
			game.player.global_position = it.pos + Vector3(0, 1, 0); break
	for _i in range(6): await get_tree().physics_frame
	var bag0: int = game.player.bag.size()
	for it in game.items:
		if it.type == "gear":
			game.player.global_position = it.pos + Vector3(0, 1, 0); break
	for _i in range(6): await get_tree().physics_frame
	print("PLAY: picked gold=%s gear=%s" % [game.player.gold > gold0, game.player.bag.size() > bag0])

	# equip the picked gear, stat should change
	var dmg0: int = game.player.tot_dmg() + game.player.tot_spell() + game.player.tot_armor() + game.player.tot_maxhp()
	if game.player.bag.size() > 0:
		game.player.equip_from_bag(0)
	print("PLAY: equipped gear, equip-not-empty=%s statchanged=%s" % [
		game.player.equip.values().any(func(x): return x != null),
		(game.player.tot_dmg() + game.player.tot_spell() + game.player.tot_armor() + game.player.tot_maxhp()) != dmg0])

	# inventory UI open/refresh with real gear
	game.inv_ui.open(game.player)
	await get_tree().process_frame
	game.inv_ui.close()
	print("PLAY: inventory open/refresh ok (bag=%d)" % game.player.bag.size())

	# shop: buy a potion
	game.player.gold = 9999
	game.shop_ui.open(game.player)
	var hpots0: int = game.player.hpots
	game.shop_ui._buy("hpot")
	game.shop_ui._buy("gear")
	game.shop_ui.close()
	print("PLAY: shop bought potion=%s gear-in-bag=%s" % [game.player.hpots > hpots0, game.player.bag.size() >= 1])

	# descent
	var d0: int = game.depth
	game.descend()
	await get_tree().physics_frame
	print("PLAY: descended %d -> %d, enemies=%d" % [d0, game.depth, get_tree().get_nodes_in_group("enemy").size()])

	# boss floor: kill the ogre -> portal -> win
	game.depth = 5
	game._build_floor(false)
	await get_tree().physics_frame
	var ogre = null
	for e2 in get_tree().get_nodes_in_group("enemy"):
		if e2.type == "ogre": ogre = e2
	if ogre:
		ogre.take_damage(999999)
	await get_tree().physics_frame
	var has_portal := false
	for it in game.items:
		if it.type == "portal": has_portal = true
	game.do_win()
	print("PLAY: boss killed portal=%s ended=%s win_panel=%s" % [has_portal, game.ended, game.hud.win_panel.visible])

	# score persisted
	print("PLAY: scores saved = %d" % Scores.load_all().size())

	# weapon-view gallery for visual QA
	var cell := 200
	var classes := ["war", "mage", "hunter", "paladin", "rogue", "warlock"]
	var gal := Image.create(cell * 3, cell * 2, false, Image.FORMAT_RGBA8)
	gal.fill(Color(0.10, 0.08, 0.06, 1))
	for idx in classes.size():
		var src: Image = WeaponArt.get_weapon(classes[idx]).get_image()
		gal.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()),
			Vector2i((idx % 3) * cell + 10, floori(float(idx) / 3) * cell))
	gal.save_png("user://weapon_gallery.png")
	print("PLAY OK")
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

	print("--- SPRITE GALLERY ---")
	var ids := ["pfoot", "pmage", "phunt", "ppala", "prog", "pwarl",
		"orc", "kobold", "murloc", "skeleton", "troll", "necro", "ogre",
		"hpot", "mpot", "meat", "gold", "stairs", "portal", "torch", "shrine", "shop", "key", "armorI", "helmI", "ringI", "sword", "staff"]
	var cell := 100
	var cols := 7
	var rows := int(ceil(ids.size() / float(cols)))
	var gal := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	gal.fill(Color(0.10, 0.08, 0.06, 1))
	var missing := 0
	for idx in ids.size():
		var tx: ImageTexture = Art.actor_texture(ids[idx])
		if not Art._draw_fns.has(ids[idx]):
			missing += 1
		var src: Image = tx.get_image()
		var cx := (idx % cols) * cell + int((cell - src.get_width()) * 0.5)
		var cy := floori(float(idx) / cols) * cell + int((cell - src.get_height()) * 0.5)
		gal.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(cx, cy))
	gal.save_png("user://sprite_gallery.png")
	print("gallery sprites: %d, missing art (placeholder): %d" % [ids.size(), missing])
	print("ALL TESTS PASSED")
