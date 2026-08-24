extends Node
## Root of Fractured Orbit. Boots a title menu, or runs headless self-tests when
## launched with a flag (mirrors the sibling Barony port's test harness so this
## project is verifiable without a display):
##   godot --headless --path fractured-orbit --gametest
##   godot --headless --path fractured-orbit -- --play 0
##   godot --headless --path fractured-orbit -- --smoke

var game: Game
var menu: CanvasLayer

func _ready() -> void:
	print("Fractured Orbit: The Echoes — booting on Godot %s" % Engine.get_version_info().string)
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--gametest" in args:
		var ok := _run_tests()
		get_tree().quit(0 if ok else 1)
		return
	if "--play" in args:
		var i := args.find("--play")
		var sec := int(args[i + 1]) if i + 1 < args.size() else 0
		await _headless_play(sec)
		return
	if "--smoke" in args:
		await get_tree().create_timer(0.2).timeout
		print("SMOKE OK")
		get_tree().quit(0)
		return
	_build_menu()

## ---- Menu -----------------------------------------------------------------

func _build_menu() -> void:
	menu = CanvasLayer.new()
	var bg := ColorRect.new()
	bg.color = Color("06080f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := Label.new()
	title.text = "FRACTURED ORBIT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("2a9df4"))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "THE ECHOES"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color("ffe08a"))
	box.add_child(sub)

	var stat := Label.new()
	stat.text = "Loops survived: %d    Gates: %d/5    Deepest: %s" % [
		Meta.runs, Meta.gates.size(), Sectors.name_of(Meta.reached)]
	stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat.add_theme_color_override("font_color", Color("8fa4c4"))
	stat.add_theme_font_size_override("font_size", 13)
	box.add_child(stat)

	var seed_edit := LineEdit.new()
	seed_edit.placeholder_text = "run seed (blank = random)"
	seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(seed_edit)

	var begin := Button.new()
	begin.text = "BEGIN THE DESCENT"
	begin.custom_minimum_size = Vector2(0, 44)
	begin.pressed.connect(func(): _start(seed_edit.text, 0))
	box.add_child(begin)

	if Meta.reached > 0:
		var cont := Button.new()
		cont.text = "CONTINUE — %s" % Sectors.name_of(Meta.reached)
		cont.custom_minimum_size = Vector2(0, 38)
		cont.pressed.connect(func(): _start(seed_edit.text, Meta.reached))
		box.add_child(cont)

	var wipe := Button.new()
	wipe.text = "Collapse the simulation (wipe save)"
	wipe.custom_minimum_size = Vector2(0, 30)
	wipe.pressed.connect(func():
		Meta.reset_all()
		menu.queue_free()
		_build_menu())
	box.add_child(wipe)

	var hint := Label.new()
	hint.text = "WASD move · Space jump · Shift dash · LMB strike · F gate power · E interact · Esc cursor · audio on"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("5f6b82"))
	hint.add_theme_font_size_override("font_size", 12)
	box.add_child(hint)

	add_child(menu)

func _start(seed: String, sector: int) -> void:
	if menu:
		menu.queue_free()
		menu = null
	game = Game.new()
	add_child(game)
	game.start(seed, sector)

## ---- Headless ------------------------------------------------------------

func _headless_play(sector: int) -> void:
	game = Game.new()
	game._headless = true
	add_child(game)
	game.start("testseed", sector)
	for _i in range(12):
		await get_tree().physics_frame
	var live := get_tree().get_nodes_in_group("enemies").size()
	print("PLAY OK — sector %d '%s': %d rooms, player at %s, %d enemies live" % [
		sector, Sectors.name_of(sector), game.sector.gen.rooms.size(),
		str(game.player.global_position.round()), live])
	get_tree().quit(0)

## ---- Self-tests -----------------------------------------------------------

func _run_tests() -> bool:
	var pass_all := true
	pass_all = _t_data() and pass_all
	pass_all = _t_determinism() and pass_all
	pass_all = _t_generation() and pass_all
	pass_all = _t_meta() and pass_all
	pass_all = _t_boss() and pass_all
	print("=== %s ===" % ("ALL TESTS PASSED" if pass_all else "TESTS FAILED"))
	return pass_all

func _ok(name: String, cond: bool) -> bool:
	print(("  ok  " if cond else "  FAIL") + "  " + name)
	return cond

func _t_data() -> bool:
	var ok := true
	ok = _ok("5 sectors defined", Sectors.count() == 5) and ok
	ok = _ok("5 gates defined", Abilities.gate_ids().size() == 5) and ok
	# every sector's gate exists in AbilityDB and points back to that sector
	for i in Sectors.count():
		var g := String(Sectors.get_def(i)["gate"])
		var def := Abilities.get_gate(g)
		ok = _ok("sector %d gate '%s' resolves" % [i, g], not def.is_empty() and int(def["sector"]) == i) and ok
	return ok

func _t_determinism() -> bool:
	var a := SectorGen.new()
	var b := SectorGen.new()
	var c := SectorGen.new()
	a.generate(0, "alpha", 0)
	b.generate(0, "alpha", 0)
	c.generate(0, "beta", 0)
	var sa := _fingerprint(a)
	var sb := _fingerprint(b)
	var sc := _fingerprint(c)
	var ok := true
	ok = _ok("same seed -> identical layout", sa == sb) and ok
	ok = _ok("different seed -> different layout", sa != sc) and ok
	return ok

func _t_generation() -> bool:
	var ok := true
	for i in Sectors.count():
		var g := SectorGen.new()
		g.generate(i, "gen", 0)
		ok = _ok("sector %d has rooms" % i, g.rooms.size() >= 4) and ok
		ok = _ok("sector %d exit is lifted" % i, g.exit_pos.y > g.spawn.y + 1.0) and ok
		var first_kind := String(g.rooms[0]["kind"])
		ok = _ok("sector %d starts safe" % i, first_kind == "safe") and ok
	# harder loop => at least as many rooms / denser
	var early := SectorGen.new(); early.generate(1, "d", 0)
	var late := SectorGen.new(); late.generate(1, "d", 8)
	ok = _ok("later loops are >= size", late.rooms.size() >= early.rooms.size()) and ok
	return ok

func _t_meta() -> bool:
	var ok := true
	var before := Meta.gates.duplicate()
	var was := Meta.has_gate("magnet_boots")
	Meta.unlock_gate("magnet_boots")
	ok = _ok("gate unlock sticks", Meta.has_gate("magnet_boots")) and ok
	# tech effect lookup
	Meta.unlock_tech("spore_purifier")
	ok = _ok("tech effect resolves", Meta.has_effect("clear_spores")) and ok
	# restore prior save state so tests are side-effect free
	if not was:
		Meta.gates.erase("magnet_boots")
	Meta.tech.erase("spore_purifier")
	Meta.gates = before
	Meta.save_state()
	return ok

func _t_boss() -> bool:
	var ok := true
	# generation places the right boss in the arena
	var g := SectorGen.new(); g.generate(4, "b", 0)
	ok = _ok("sector 4 boss is nexus", g.boss_type == "nexus") and ok
	ok = _ok("sector 4 boss positioned", g.boss_pos != Vector3.ZERO) and ok
	var g2 := SectorGen.new(); g2.generate(2, "b", 0)
	ok = _ok("sector 2 boss is core_guardian", g2.boss_type == "core_guardian") and ok
	var g0 := SectorGen.new(); g0.generate(0, "b", 0)
	ok = _ok("sector 0 has no boss", g0.boss_type == "") and ok

	# the core loop: shielded until a Reality-Bender rewrite strips a pattern
	var arena := Node3D.new()
	add_child(arena)
	var boss := Boss.new()
	boss.setup(Sectors.palette(4))
	arena.add_child(boss)
	var defeated := [false]
	boss.defeated.connect(func(): defeated[0] = true)
	var hp0: float = boss.hp
	boss.take_damage(50.0)
	ok = _ok("NEXUS ignores damage while shielded", boss.hp == hp0) and ok
	ok = _ok("Reality Bender strips a pattern", boss.strip_pattern()) and ok
	boss.take_damage(50.0)
	ok = _ok("NEXUS takes damage while exposed", boss.hp < hp0) and ok
	for _i in range(20):
		boss.strip_pattern()
		boss.take_damage(100.0)
		if defeated[0]:
			break
	ok = _ok("NEXUS can be defeated", defeated[0]) and ok
	arena.queue_free()
	return ok

func _fingerprint(g: SectorGen) -> String:
	var s := "n=%d;" % g.rooms.size()
	for r in g.rooms:
		s += "%s:%d,%d|" % [r["kind"], int(r["center"].x), int(r["center"].z)]
		s += "e%d,h%d,p%d;" % [r["enemies"].size(), r["hazards"].size(), r["platforms"].size()]
	return s
