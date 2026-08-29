class_name Star
extends Area3D

## A numbered collectible star for the counting trail.
##
## Ten of these are strung in a loop around the meadow, each carrying a number
## 1..10 on a billboarded label so a small player can count them off as she
## runs the lap. Same spin-and-bob idle as `Sparkle`, but this one is its own
## goal with its own HUD tally rather than feeding the gate.

signal collected(star: Star)

const SPIN_SPEED := 1.1
const BOB_HEIGHT := 0.16
const BOB_HZ := 0.9

## Set by Game.gd before the star enters the tree.
var number := 1

var _visual: Node3D
var _label: Label3D
var _base_y := 0.0
var _phase := 0.0
var _taken := false


func _ready() -> void:
	_visual = Models.spawn("res://assets/models/star.glb", 0.7)
	add_child(_visual)

	# The number floats just above the star, always turned to face the camera
	# so it stays readable from anywhere on the trail.
	_label = Label3D.new()
	_label.text = str(number)
	_label.font_size = 200
	_label.outline_size = 48
	_label.modulate = Color(0.98, 0.42, 0.62)
	_label.outline_modulate = Color(1, 1, 1, 0.95)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0026
	_label.position.y = 1.0
	_label.no_depth_test = false
	add_child(_label)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	shape.shape = sphere
	add_child(shape)

	_base_y = position.y
	# Desync the bob so a trail of stars does not pulse in lockstep.
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
	# Can't toggle monitoring from inside its own signal; defer it. The _taken
	# guard already stops a second pickup this frame.
	set_deferred("monitoring", false)
	collected.emit(self)
	_play_pickup()


## Pop up and grow, then remove. Matches Sparkle's pickup so the two
## collectibles feel like they belong to the same toybox.
func _play_pickup() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual, "scale", Vector3.ONE * 1.8, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "position:y", 2.0, 0.25)
	tween.tween_property(self, "position:y", position.y + 1.2, 0.25)
	tween.chain().tween_callback(queue_free)
