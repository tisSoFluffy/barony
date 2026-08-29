extends SceneTree

## Proves the butterfly's rig loaded and that she actually flies.
##
## She is the only rigged asset here, so the first two checks are really about
## the export pipeline: if `tools/rig_butterfly.py` silently produced an
## unskinned mesh, or Godot dropped the armature on import, the wings go stiff
## and nothing else would notice. The rest checks she flies rather than sits.
##
##   Godot_console.exe --headless --path rainbow-sparkle-squad -s tools/butterflytest.gd

const WATCH := 8.0

var _root: Node
var _fly: Node3D
var _clock := 0.0
var _start := Vector3.ZERO
var _min_y := 999.0
var _max_y := -999.0
var _wing_min := 999.0
var _wing_max := -999.0
var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_root = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(_root)


func _process(delta: float) -> bool:
	if _fly == null:
		_fly = _root.get_node_or_null("Butterfly")
		if _fly == null:
			_check(false, "Main.tscn builds a Butterfly")
			return _finish()
		_start = _fly.global_position

		var skel := _skeleton()
		_check(skel != null, "the model imported with a Skeleton3D")
		if skel != null:
			var l := skel.find_bone("Wing_L")
			var r := skel.find_bone("Wing_R")
			_check(l >= 0 and r >= 0, "the rig has Wing_L and Wing_R bones")
		return false

	_clock += delta
	_min_y = minf(_min_y, _fly.global_position.y)
	_max_y = maxf(_max_y, _fly.global_position.y)

	# Sample the live wing angle so we can prove it is being driven, not parked.
	var skel := _skeleton()
	if skel != null:
		var l := skel.find_bone("Wing_L")
		if l >= 0:
			var a: float = skel.get_bone_pose_rotation(l).get_euler().length()
			_wing_min = minf(_wing_min, a)
			_wing_max = maxf(_wing_max, a)

	if _clock > WATCH:
		var travelled := _fly.global_position.distance_to(_start)
		_check(travelled > 3.0, "she flies a real distance (%.1f m)" % travelled)
		_check(_min_y > 0.5, "she stays airborne (lowest %.2f m)" % _min_y)
		_check(_max_y - _min_y > 0.25,
			"her altitude varies rather than tracking flat (%.2f m)" % (_max_y - _min_y))
		_check(_wing_max - _wing_min > 0.3,
			"her wings beat (pose swing %.2f rad)" % (_wing_max - _wing_min))
		return _finish()

	return false


func _skeleton() -> Skeleton3D:
	for node in _fly.find_children("*", "Skeleton3D", true, false):
		return node as Skeleton3D
	return null


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _finish() -> bool:
	print("")
	if _failures.is_empty():
		print("butterflytest: %d/%d checks passed" % [_checks, _checks])
	else:
		print("butterflytest: %d of %d FAILED" % [_failures.size(), _checks])
		for f in _failures:
			print("   - %s" % f)
	quit(0 if _failures.is_empty() else 1)
	return true
