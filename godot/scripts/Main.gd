extends Node

const TileLevel    = preload("res://scripts/level/TileLevel.gd")
const DungeonGen   = preload("res://scripts/Dungeon.gd")
const HUDScript    = preload("res://scripts/ui/HUD.gd")
const InvScript    = preload("res://scripts/ui/InventoryUI.gd")
const PostProc     = preload("res://scripts/ui/PostProcess.gd")
const DeathScreen  = preload("res://scripts/ui/DeathScreen.gd")
const StairTrigger = preload("res://scripts/level/StairTrigger.gd")
const PlayerScene  = preload("res://scenes/Player.tscn")
const EnemyScene   = preload("res://scenes/Enemy.tscn")

@onready var camera:      Camera3D = $World/Camera
@onready var world_level: Node3D   = $World/Level

var _player_start := Vector3(9.0, 0.1, 9.0)
var _dungeon_data: Dictionary = {}
var _depth: int   = 1
var _player: CharacterBody3D = null
var player: CharacterBody3D:
	get: return _player

var _dev_wheel: DevSpawnWheel
var _t_held := false


func _ready() -> void:
	_spawn_hud()
	_add_base_light()
	_load_floor(_depth)
	_dev_wheel = DevSpawnWheel.new()
	_dev_wheel.host = self
	add_child(_dev_wheel)


func _process(_dt: float) -> void:
	if Input.is_key_pressed(KEY_T) and not _t_held:
		_t_held = true
		_dev_wheel.toggle()
	elif not Input.is_key_pressed(KEY_T):
		_t_held = false

func _add_base_light() -> void:
	# Dim overhead fill light — gives 3D geometry shape without washing out torch mood
	var sun := DirectionalLight3D.new()
	sun.light_color      = Color(0.85, 0.78, 0.70)
	sun.light_energy     = 0.30
	sun.shadow_enabled   = false
	sun.rotation_degrees = Vector3(-65.0, 45.0, 0.0)  # matches camera angle
	$World.add_child(sun)


func _spawn_hud() -> void:
	add_child(HUDScript.new())
	add_child(InvScript.new())
	add_child(PostProc.new())
	add_child(DeathScreen.new())


# ── Floor lifecycle ───────────────────────────────────────────────────────────

func _load_floor(depth: int) -> void:
	_depth = depth

	# Tear down previous floor geometry + enemies (keep player)
	for child in world_level.get_children():
		if child == _player:
			continue
		child.queue_free()
	await get_tree().process_frame   # let queue_free flush

	_dungeon_data = DungeonGen.generate(depth)

	var tile_level := TileLevel.new()
	world_level.add_child(tile_level)

	var converted := TileLevel.from_dungeon(_dungeon_data)
	tile_level.build(converted["grid"], converted["torches"], converted["rooms"], converted["avoid_points"])

	var start: Vector2 = _dungeon_data["start"]
	_player_start = Vector3(start.x * TileLevel.TILE_SIZE, 0.1, start.y * TileLevel.TILE_SIZE)

	_spawn_player()
	_spawn_enemies()
	_spawn_stair(depth)


func _spawn_player() -> void:
	if _player == null:
		_player = PlayerScene.instantiate()
		world_level.add_child(_player)
	_player.global_position = _player_start
	camera.set_target(_player)


func _spawn_enemies() -> void:
	for e in _dungeon_data.get("enemies", []):
		var etype: String = e.get("type", "kobold")
		if not SpriteFactory.CHAR_CONFIG.has(etype):
			etype = "kobold"
		var pos: Vector2 = e["pos"]
		var enemy: CharacterBody3D = EnemyScene.instantiate()
		enemy.type = etype
		world_level.add_child(enemy)
		enemy.global_position = Vector3(
			pos.x * TileLevel.TILE_SIZE, 0.1, pos.y * TileLevel.TILE_SIZE)


func _spawn_stair(depth: int) -> void:
	var stairs_pos = _dungeon_data.get("stairs", null)
	if stairs_pos == null:
		return
	var stair: Area3D = StairTrigger.new()
	stair.depth = depth
	world_level.add_child(stair)
	stair.global_position = Vector3(
		stairs_pos.x * TileLevel.TILE_SIZE, 0.05, stairs_pos.y * TileLevel.TILE_SIZE)
	stair.descended.connect(_on_descended)


func _on_descended(next_depth: int) -> void:
	_load_floor(next_depth)
