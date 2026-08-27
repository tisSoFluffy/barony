class_name Gate
extends Node3D

## The castle gate: the level goal.
##
## Stays shut until the player is carrying `required` sparkles, then swings
## open and the archway becomes the win trigger. The gate mesh is a single
## unrigged slab, so "opening" is the whole model lifting and fading rather
## than doors on hinges.

signal entered

@export var required := 8
@export var width := 7.0

var _visual: Node3D
var _trigger: Area3D
var _wall: StaticBody3D
var _open := false
var _sparkles := 0


func _ready() -> void:
	_visual = Models.spawn_wide("res://assets/models/castle_gate.glb", width, false)
	add_child(_visual)

	# Solid while shut: two blocks flanking the archway, so you cannot simply
	# walk through the hole before you have earned it.
	_wall = StaticBody3D.new()
	add_child(_wall)
	for side in [-1.0, 1.0]:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width * 0.32, 4.0, 1.2)
		col.shape = box
		col.position = Vector3(side * width * 0.34, 2.0, 0.0)
		_wall.add_child(col)

	_trigger = Area3D.new()
	var tcol := CollisionShape3D.new()
	var tbox := BoxShape3D.new()
	tbox.size = Vector3(width * 0.30, 3.0, 1.6)
	tcol.shape = tbox
	tcol.position = Vector3(0.0, 1.5, 0.0)
	_trigger.add_child(tcol)
	_trigger.monitoring = false
	_trigger.body_entered.connect(_on_body_entered)
	add_child(_trigger)


## Called by Game.gd whenever the sparkle count changes.
func set_sparkles(count: int) -> void:
	_sparkles = count
	if not _open and _sparkles >= required:
		open()


func is_open() -> bool:
	return _open


func remaining() -> int:
	return maxi(required - _sparkles, 0)


func open() -> void:
	if _open:
		return
	_open = true
	_wall.process_mode = Node.PROCESS_MODE_DISABLED
	for child in _wall.get_children():
		(child as CollisionShape3D).disabled = true
	_trigger.monitoring = true

	var tween := create_tween()
	tween.tween_property(_visual, "position:y", 0.6, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_visual, "scale", Vector3(1.04, 1.04, 1.04), 0.7)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		entered.emit()
