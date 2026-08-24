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
	_ended = true
	hud.show_end("EVENT HORIZON",
		"You reach the singularity. The NEXUS dissolves into data. The crew wakes — but they do not remember you.\n\nName: Unknown.  Status: Erased.",
		Color("ffe08a"))
