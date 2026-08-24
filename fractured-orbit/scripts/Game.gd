class_name Game
extends Node3D
## Owns one active run: builds the current sector, spawns the Loop-Walker, wires
## the HUD, runs the 10-minute NEXUS reset clock, and closes the loop on death.
##
## Death is roguelike (the run resets) but the world remembers: the death point +
## a note are stored as an echo (Meta) and reappear as debris in every later run.
## Traversal gates, tech, and the deepest sector reached persist, so each reset
## starts a little stronger — the rogue-vania spine.

const LOOP_SECONDS := 600.0     # NEXUS resets the ship every 10 minutes

var run_seed := ""
var current_sector := 0
var player: Player
var sector: Sector
var hud: HUD
var env: WorldEnvironment
var star: DirectionalLight3D
var _loop_left := LOOP_SECONDS
var _ended := false
var _headless := false

func start(seed: String, start_sector: int = 0) -> void:
	run_seed = seed
	current_sector = clampi(start_sector, 0, Sectors.count() - 1)
	_setup_world()
	_build_sector()

func _setup_world() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_energy = 0.35
	e.fog_enabled = true
	env.environment = e
	add_child(env)

	star = DirectionalLight3D.new()
	star.rotation_degrees = Vector3(-55, -35, 0)
	star.light_energy = 0.5     # a distant star; the ship is lit by area lights
	add_child(star)

	hud = HUD.new()
	add_child(hud)

func _apply_palette() -> void:
	var pal := Sectors.palette(current_sector)
	var e := env.environment
	e.background_color = pal["fog"]
	e.ambient_light_color = pal["fog"].lightened(0.15)
	e.fog_light_color = pal["fog"]
	e.fog_density = 0.02 if current_sector != 3 else 0.006   # void reads open
	star.light_color = pal["accent"].lightened(0.3)

func _build_sector() -> void:
	if sector:
		sector.queue_free()
	if player:
		player.queue_free()

	_apply_palette()

	var gen := SectorGen.new()
	gen.generate(current_sector, run_seed, Meta.runs)

	sector = Sector.new()
	add_child(sector)
	sector.build(gen)

	player = Player.new()
	player.current_sector = current_sector
	player.sector = sector
	add_child(player)
	player.global_position = gen.spawn
	player.died.connect(_on_player_died)
	player.health_changed.connect(func(hp, mx): hud.set_health(hp, mx))
	player.notice.connect(func(t): hud.show_notice(t))

	if sector.boss != null and is_instance_valid(sector.boss):
		if sector.boss.has_signal("boss_notice"):
			sector.boss.boss_notice.connect(func(t): hud.show_notice(t))
		if sector.boss.has_signal("defeated"):
			sector.boss.defeated.connect(_on_nexus_defeated)

	Meta.mark_reached(current_sector)
	hud.set_sector(Sectors.name_of(current_sector), Meta.runs)
	hud.set_health(player.hp, player.max_hp)
	hud.refresh_gates()
	hud.show_notice(String(Sectors.get_def(current_sector)["tagline"]))
	_loop_left = LOOP_SECONDS
	_ended = false

func _process(delta: float) -> void:
	if _ended or player == null or not is_instance_valid(player):
		return
	_loop_left -= delta
	hud.set_timer(_loop_left)
	if _loop_left <= 0.0:
		_reset_run("NEXUS purged the run. Reset.")
		return
	# a live boss seals the sector — clear the arena before you can leave
	if sector and sector.boss != null and is_instance_valid(sector.boss):
		return
	# reached the lifted exit → advance a sector
	if sector and player.global_position.distance_to(sector.gen.exit_pos) < 2.5:
		_advance()

func _on_player_died(pos: Vector3, note: String) -> void:
	_ended = true
	Meta.record_death(current_sector, pos, note)
	if _headless:
		return
	hud.show_end("ERASED", note + "\n\nThe ship resets. Your gear and memories remain.", Color("ff5a6a"))
	await get_tree().create_timer(2.5).timeout
	hud.clear_end()
	_build_sector()

func _reset_run(reason: String) -> void:
	Meta.record_death(current_sector, player.global_position, reason)
	hud.show_notice(reason)
	_build_sector()

func _advance() -> void:
	if current_sector >= Sectors.count() - 1:
		_win()
		return
	current_sector += 1
	hud.show_notice("Ascending to " + Sectors.name_of(current_sector))
	_build_sector()

func _win() -> void:
	# Fallback if a final sector ever has no boss; normally endings come via NEXUS.
	_show_endings()

func _on_nexus_defeated() -> void:
	_ended = true
	if _headless:
		return
	hud.show_notice("The singularity opens. Three paths remain.")
	_show_endings()

func _show_endings() -> void:
	_ended = true
	if _headless:
		return
	var options := [
		{"label": "PATH A — Save the Ship", "color": Color("d98a3a"),
			"desc": "Restore the AI. The plague is held at bay, forever threatening. The world is saved, but fragile."},
		{"label": "PATH B — Transcendence", "color": Color("b06ad9"),
			"desc": "Merge with NEXUS and escape into the void as a digital god. The crew is left to fend for itself."},
		{"label": "PATH C — The Loop", "color": Color("ff2a5a"),
			"desc": "Jump into the singularity yourself. The simulation collapses and restarts. True permadeath — your progress is erased."},
	]
	hud.show_choice("EVENT HORIZON", "Choose how the loop ends.", options, _end_with)

func _end_with(index: int) -> void:
	match index:
		0:
			hud.show_end("PATH A — THE SHIP SAVED",
				"NEXUS is restored. The Aethelgard limps on, the Silence held just beyond the walls. You keep watch. It is enough — for now.",
				Color("d98a3a"))
		1:
			hud.show_end("PATH B — TRANSCENDENCE",
				"You pour yourself into NEXUS and slip the hull entirely, unfolding into the dark as something vast and cold. The crew never learns your name.",
				Color("b06ad9"))
		2:
			Meta.reset_all()
			hud.show_end("PATH C — THE LOOP",
				"You step into the singularity. The simulation folds shut and begins again, clean. Name: Unknown. Status: Erased.\n\n(All progress wiped — a fresh loop awaits.)",
				Color("ff2a5a"))
