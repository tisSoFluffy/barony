class_name Numberblock
extends Area3D

## One Numberblock: the number N built out of N cubes, with a face.
##
## These are the only characters here that are NOT generated. A Numberblock is
## literally a stack of unit cubes, so building it from BoxMesh in code is more
## faithful than anything image-to-3D would give us - and it means the shape
## carries the maths. Four really is four cubes, and you can count them.
##
## Each one is built from a (columns, rows) grid, the arrangement the toy uses:
## small numbers are single towers, and the ones that factor neatly become
## rectangles - 6 is 2x3, 8 is 2x4, 9 is 3x3, 10 is 2x5.

signal touched(block: Numberblock)

# Grid pitch. Sized so a One stands about two thirds of the player's height and
# a Ten towers well over it - the size difference between 1 and 10 is the whole
# point, so the cubes have to be big enough for it to land.
const CUBE := 0.55
const SEAM := 0.965              # cube drawn slightly small so seams show

const BOB_HZ := 0.7
const BOB_HEIGHT := 0.035

## columns x rows per number, and the body colour(s).
const SHAPES := {
	1: Vector2i(1, 1), 2: Vector2i(1, 2), 3: Vector2i(1, 3), 4: Vector2i(1, 4),
	5: Vector2i(1, 5), 6: Vector2i(2, 3), 7: Vector2i(1, 7), 8: Vector2i(2, 4),
	9: Vector2i(3, 3), 10: Vector2i(2, 5),
}

const COLOURS := {
	1: Color("#e8332a"), 2: Color("#f58220"), 3: Color("#ffd400"),
	4: Color("#5cc14c"), 5: Color("#4fc3e8"), 6: Color("#7b4fa8"),
	8: Color("#e8368f"), 9: Color("#9aa0a6"),
	# Ten is white in the toy, but a true white loses its seams and its face
	# against a bright sky - a faint cool tint keeps both readable.
	10: Color("#e4eaf0"),
}

## Seven is the rainbow one - a colour per cube, bottom to top.
const SEVEN := [
	Color("#e8332a"), Color("#f58220"), Color("#ffd400"), Color("#5cc14c"),
	Color("#4fc3e8"), Color("#3f6fd8"), Color("#7b4fa8"),
]

var number := 1

var _visual: Node3D
var _cubes: Array[MeshInstance3D] = []
var _cube_mats: Array[StandardMaterial3D] = []
var _label: Label3D
var _phase := 0.0
var _squash := 0.0
var _squash_vel := 0.0
var _lit := false
var _size := Vector2i.ONE


func _ready() -> void:
	_size = SHAPES.get(number, Vector2i(1, 1))

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	_build_body()
	_build_face()
	_build_limbs()
	_build_label()

	# One box collider around the whole stack - you touch the Numberblock, not
	# an individual cube.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_size.x * CUBE + 0.25, _size.y * CUBE, CUBE + 0.25)
	shape.shape = box
	shape.position.y = _size.y * CUBE * 0.5
	add_child(shape)

	_phase = randf() * TAU
	monitoring = true
	body_entered.connect(_on_body_entered)


# -- construction --------------------------------------------------------

func _cube_colour(row: int) -> Color:
	if number == 7:
		return SEVEN[clampi(row, 0, SEVEN.size() - 1)]
	return COLOURS.get(number, Color.WHITE)


func _build_body() -> void:
	var half := (_size.x - 1) * 0.5
	for row in _size.y:
		for col in _size.x:
			var mi := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3.ONE * CUBE * SEAM
			mi.mesh = mesh

			var mat := StandardMaterial3D.new()
			mat.albedo_color = _cube_colour(row)
			mat.roughness = 0.55
			mi.material_override = mat

			mi.position = Vector3((col - half) * CUBE, (row + 0.5) * CUBE, 0.0)
			_visual.add_child(mi)
			_cubes.append(mi)
			_cube_mats.append(mat)


## Eyes and a wide open smile on the front (-Z, Godot's forward) of the top row,
## so a block always looks at whoever it is turned towards.
func _build_face() -> void:
	var top := _size.y * CUBE
	var front := -(CUBE * 0.5) - 0.001
	var eye_y := top - CUBE * 0.42
	var eye_dx: float = maxf(CUBE * 0.24, _size.x * CUBE * 0.16)

	for side in [-1.0, 1.0]:
		var white := MeshInstance3D.new()
		var wm := SphereMesh.new()
		wm.radius = CUBE * 0.15
		wm.height = CUBE * 0.30
		white.mesh = wm
		white.material_override = _flat(Color.WHITE)
		white.position = Vector3(side * eye_dx, eye_y, front)
		white.scale = Vector3(1.0, 1.15, 0.55)
		_visual.add_child(white)

		var pupil := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = CUBE * 0.075
		pm.height = CUBE * 0.15
		pupil.mesh = pm
		pupil.material_override = _flat(Color("#101014"))
		pupil.position = Vector3(side * eye_dx, eye_y, front - CUBE * 0.06)
		pupil.scale = Vector3(1.0, 1.0, 0.5)
		_visual.add_child(pupil)

	var mouth := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = CUBE * 0.17
	mm.height = CUBE * 0.34
	mouth.mesh = mm
	mouth.material_override = _flat(Color("#c2185b"))
	mouth.position = Vector3(0.0, eye_y - CUBE * 0.36, front - CUBE * 0.02)
	mouth.scale = Vector3(1.35, 0.62, 0.35)
	_visual.add_child(mouth)


## Stub arms out of the sides and two feet under the stack. Not articulated -
## they exist so the silhouette reads as a character rather than a wall.
func _build_limbs() -> void:
	var accent: Color = Color("#e8332a") if number == 10 else _cube_colour(0)
	var half_w := _size.x * CUBE * 0.5
	var arm_y: float = _size.y * CUBE * 0.55

	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = CUBE * 0.055
		am.height = CUBE * 0.55
		arm.mesh = am
		arm.material_override = _flat(accent)
		arm.position = Vector3(side * (half_w + CUBE * 0.16), arm_y, 0.0)
		arm.rotation_degrees = Vector3(0, 0, side * 62.0)
		_visual.add_child(arm)

		var foot := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(CUBE * 0.30, CUBE * 0.16, CUBE * 0.44)
		foot.mesh = fm
		foot.material_override = _flat(accent)
		foot.position = Vector3(side * CUBE * 0.24, CUBE * 0.06, -CUBE * 0.10)
		_visual.add_child(foot)


func _build_label() -> void:
	_label = Label3D.new()
	_label.text = str(number)
	_label.font_size = 180
	_label.outline_size = 44
	_label.modulate = Color("#3d2a52")
	_label.outline_modulate = Color(1, 1, 1, 0.95)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0022
	_label.position.y = _size.y * CUBE + 0.30
	add_child(_label)


func _flat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.6
	return mat


# -- life ----------------------------------------------------------------

func _process(delta: float) -> void:
	_phase += delta

	# Squash spring, same idiom as the rest of the cast.
	_squash_vel += (-150.0 * _squash - 13.0 * _squash_vel) * delta
	_squash += _squash_vel * delta
	_squash = clampf(_squash, -0.5, 0.5)

	_visual.scale = Vector3(1.0 - _squash * 0.45, 1.0 + _squash, 1.0 - _squash * 0.45)
	_visual.position.y = sin(_phase * TAU * BOB_HZ) * BOB_HEIGHT
	_visual.rotation.y = sin(_phase * 0.8) * 0.05


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		touched.emit(self)


## Correct answer: bounce and glow.
func cheer() -> void:
	_squash = 0.40
	_squash_vel = 0.0
	set_lit(true)


## Wrong answer: a quick flat shake, no glow.
func buzz() -> void:
	_squash = -0.34
	_squash_vel = 0.0
	var tween := create_tween()
	for i in 3:
		tween.tween_property(_visual, "rotation:z", 0.12, 0.05)
		tween.tween_property(_visual, "rotation:z", -0.12, 0.05)
	tween.tween_property(_visual, "rotation:z", 0.0, 0.05)


## Lit blocks glow, so the row so far reads at a glance as "these are done".
func set_lit(on: bool) -> void:
	if _lit == on:
		return
	_lit = on
	for i in _cube_mats.size():
		var mat := _cube_mats[i]
		mat.emission_enabled = on
		if on:
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 0.55
	_label.modulate = Color("#1b7f3b") if on else Color("#3d2a52")


func is_lit() -> bool:
	return _lit
