class_name Projectile
extends Area3D
## A simple travelling hazard bolt used by boss attack patterns (and available to
## ranged enemies). Moves in a straight line, damages the player on contact, and
## despawns on any solid hit or after its lifetime. Low-poly glowing cube.

var dir := Vector3.FORWARD
var speed := 12.0
var dmg := 14.0
var life := 5.0
var color := Color("ff2a5a")

func _ready() -> void:
	monitoring = true
	var mi := Forge.slab(Vector3(0.35, 0.35, 0.35), color, 3.0)
	add_child(mi)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.35, 0.35, 0.35)
	col.shape = box
	add_child(col)
	body_entered.connect(_on_body)

func launch(from: Vector3, direction: Vector3, p_speed: float, p_dmg: float, p_color: Color) -> void:
	global_position = from
	dir = direction.normalized()
	speed = p_speed
	dmg = p_dmg
	color = p_color

func _physics_process(delta: float) -> void:
	global_position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body(body) -> void:
	if body.has_method("take_damage") and body.is_in_group("player"):
		body.take_damage(dmg, "nexus")
		queue_free()
	elif body is StaticBody3D:
		queue_free()
