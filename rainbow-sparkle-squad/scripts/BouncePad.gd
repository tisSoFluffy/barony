class_name BouncePad
extends Area3D

## A rainbow arch you run through to get flung upward.
##
## The trigger is a flat box lying under the arch rather than the arch's own
## shape, so you bounce by running through the opening and can still land on
## top of the arch normally.

signal bounced

@export var force := 16.0
@export var width := 3.4

var _visual: Node3D
var _cooldown := 0.0


func _ready() -> void:
	_visual = Models.spawn_wide("res://assets/models/rainbow_arch.glb", width, false)
	add_child(_visual)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width * 0.55, 0.6, width * 0.55)
	shape.shape = box
	shape.position.y = 0.3
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	# Idle shimmy so the arch reads as springy rather than as scenery.
	_visual.scale.y = 1.0 + sin(Time.get_ticks_msec() * 0.002) * 0.03


func _on_body_entered(body: Node3D) -> void:
	if _cooldown > 0.0 or not (body is Player):
		return
	_cooldown = 0.25
	(body as Player).bounce(force)
	bounced.emit()
	_squash()


func _squash() -> void:
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3(1.15, 0.75, 1.15), 0.06)
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.28) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
