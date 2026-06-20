extends CharacterBody3D
class_name Player
## First-person controller: WASD move, mouse look (+ arrow-key turn), Esc frees
## the cursor. Built in code so there is no scene to hand-author.

@export var speed := 4.2
@export var look_sens := 0.0032

var cls := "war"
var yaw := 0.0
var pitch := 0.0
var cam: Camera3D

func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.4
	col.shape = cap
	add_child(col)
	cam = Camera3D.new()
	cam.position = Vector3(0, 0.55, 0)
	cam.fov = 78
	add_child(cam)
	if not OS.has_feature("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * look_sens
		pitch = clampf(pitch - e.relative.y * look_sens, -1.35, 1.35)
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(dt: float) -> void:
	if Input.is_action_pressed("turn_left"):
		yaw += 2.4 * dt
	if Input.is_action_pressed("turn_right"):
		yaw -= 2.4 * dt
	rotation.y = yaw
	if cam:
		cam.rotation.x = pitch
	var ix := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var iz := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	var dir := (transform.basis * Vector3(ix, 0, iz))
	dir.y = 0
	if dir.length() > 0.001:
		dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0
	move_and_slide()
