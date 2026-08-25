extends SceneTree
## Throwaway: steps live Enemy instances and prints their visual transform, so
## the procedural animation can be checked without eyeballing the game.
##   godot --headless --path fractured-orbit -s tools/anim_probe.gd

const TYPES := ["silence_guard", "drone_swarm", "turret_spider", "scrap_crawler"]

var _enemy: Node
var _which := -1
var _frame := 0
var _rows: Array[String] = []

func _initialize() -> void:
	var ground := StaticBody3D.new()
	var fcol := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(60, 1, 60)
	fcol.shape = fbox
	fcol.position = Vector3(0, -0.5, 0)
	ground.add_child(fcol)
	root.add_child(ground)

	# Stand-in for the player, in the group Enemy looks itself up against.
	var player := Node3D.new()
	player.add_to_group("player")
	player.position = Vector3(9, 0, 0)
	root.add_child(player)
	_next()

func _next() -> void:
	if _enemy and _which >= 0:
		print("%-16s %s" % [TYPES[_which], " | ".join(_rows)])
		_enemy.queue_free()
	_rows = []
	_frame = 0
	_which += 1
	if _which >= TYPES.size():
		return
	_enemy = load("res://scripts/Enemy.gd").new()
	_enemy.setup(TYPES[_which], {})
	root.add_child(_enemy)

func _physics_process(_delta: float) -> bool:
	if _which >= TYPES.size():
		return true                      # true == quit the main loop
	if not is_instance_valid(_enemy):
		_rows.append("<self-destructed>")
		_next()
		return false
	_frame += 1
	if _frame % 15 == 0:
		var v: Node3D = _enemy.get("_visual")
		_rows.append("y%+.3f pitch%+.3f roll%+.3f yaw%+.3f" % [
			v.position.y, v.rotation.x, v.rotation.z, v.rotation.y])
	if _frame >= 60:
		_next()
	return false

func _process(_delta: float) -> bool:
	return false
