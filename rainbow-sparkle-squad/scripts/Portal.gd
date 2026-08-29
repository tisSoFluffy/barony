class_name Portal
extends Node3D

## A doorway between the meadow and Blockland.
##
## Built from the Numberblock palette so the door itself hints at where it goes:
## a frame of coloured cubes around a soft glowing sheet. Walking into the sheet
## fires `entered`; Game.gd owns the fade and the actual move, because only it
## knows where the player should come out.

signal entered(portal: Portal)

const COLUMN := 5                 # cubes up each side
const CUBE := 0.42

@export var label_text := ""

var _sheet: MeshInstance3D
var _sheet_mat: StandardMaterial3D
var _phase := 0.0
var _armed := true


func _ready() -> void:
	_build_frame()
	_build_sheet()
	_build_label()

	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CUBE * 2.4, COLUMN * CUBE, 0.7)
	shape.shape = box
	shape.position.y = COLUMN * CUBE * 0.5
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

	_phase = randf() * TAU


## Two towers and a lintel, each cube a different Numberblock colour so the
## whole frame counts up as it climbs.
func _build_frame() -> void:
	var half := CUBE * 1.7
	for side in [-1.0, 1.0]:
		for row in COLUMN:
			_cube(Vector3(side * half, (row + 0.5) * CUBE, 0.0), _colour(row + 1))
	for i in 4:
		var x: float = -half + (CUBE * 2.0 * float(i) / 3.0) * 1.7
		_cube(Vector3(x, (COLUMN + 0.5) * CUBE, 0.0), _colour(i + 6))


func _colour(n: int) -> Color:
	var k: int = ((n - 1) % 10) + 1
	if k == 7:
		return Numberblock.SEVEN[2]
	return Numberblock.COLOURS.get(k, Color.WHITE)


func _cube(at: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * CUBE * 0.96
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.55
	mi.material_override = mat
	mi.position = at
	add_child(mi)


func _build_sheet() -> void:
	_sheet = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(CUBE * 2.9, COLUMN * CUBE)
	_sheet.mesh = quad

	_sheet_mat = StandardMaterial3D.new()
	_sheet_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.42)
	_sheet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sheet_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sheet_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sheet_mat.emission_enabled = true
	_sheet_mat.emission = Color(0.75, 0.92, 1.0)
	_sheet_mat.emission_energy_multiplier = 0.9
	_sheet.material_override = _sheet_mat

	_sheet.position.y = COLUMN * CUBE * 0.5
	add_child(_sheet)


func _build_label() -> void:
	if label_text == "":
		return
	var label := Label3D.new()
	label.text = label_text
	label.font_size = 150
	label.outline_size = 40
	label.modulate = Color("#3d2a52")
	label.outline_modulate = Color(1, 1, 1, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0028
	label.position.y = (COLUMN + 1.6) * CUBE
	add_child(label)


func _process(delta: float) -> void:
	_phase += delta
	# Slow pulse so the doorway reads as live rather than as scenery.
	var glow: float = 0.7 + 0.35 * (0.5 + 0.5 * sin(_phase * 2.0))
	_sheet_mat.emission_energy_multiplier = glow
	_sheet_mat.albedo_color.a = 0.34 + 0.12 * (0.5 + 0.5 * sin(_phase * 2.0))


func _on_body_entered(body: Node3D) -> void:
	if _armed and body is Player:
		entered.emit(self)


## Held disarmed while the player is standing in the doorway they just arrived
## at, so they do not bounce straight back through it.
func set_armed(on: bool) -> void:
	_armed = on
