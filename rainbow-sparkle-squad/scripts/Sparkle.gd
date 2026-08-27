class_name Sparkle
extends Area3D

## A collectible cluster of sparkle cubes.
##
## The generated `sparkle_cubes` mesh is already a scattered cloud of little
## cubes, so one instance reads as a handful of sparkles rather than a single
## coin. It spins and bobs so it catches the eye from across the meadow.

signal collected(sparkle: Sparkle)

const SPIN_SPEED := 1.4
const BOB_HEIGHT := 0.18
const BOB_HZ := 1.1

var _visual: Node3D
var _base_y := 0.0
var _phase := 0.0
var _taken := false


func _ready() -> void:
	# The mesh is a loose scatter of small cubes, so it has to be scaled up well
	# past "one pickup sized" before the individual cubes read from a distance.
	_visual = Models.spawn_wide("res://assets/models/sparkle_cubes.glb", 1.6, false)
	add_child(_visual)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.85
	shape.shape = sphere
	add_child(shape)

	_base_y = position.y
	# Desync the bob so a field of sparkles does not pulse in lockstep.
	_phase = randf() * TAU
	monitoring = true
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _taken:
		return
	_phase += delta
	_visual.rotation.y += SPIN_SPEED * delta
	position.y = _base_y + sin(_phase * TAU * BOB_HZ) * BOB_HEIGHT


func _on_body_entered(body: Node3D) -> void:
	if _taken or not (body is Player):
		return
	_taken = true
	monitoring = false
	collected.emit(self)
	_play_pickup()


## Scale up and fade out, then remove. Keeps the pickup readable without
## needing a particle system or any authored animation.
func _play_pickup() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual, "scale", Vector3.ONE * 1.9, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y + 1.2, 0.25)
	tween.chain().tween_callback(queue_free)
