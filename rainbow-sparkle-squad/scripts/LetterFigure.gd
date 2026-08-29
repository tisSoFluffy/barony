class_name LetterFigure
extends Area3D

## One letter character: a real extruded 3D letter with a face.
##
## The shapes in Shape Cove are extruded from outlines I wrote by hand, but
## letterforms are far too fiddly for that - so these use Godot's `TextMesh`,
## which extrudes glyphs straight out of the project font. The result lands in
## the same visual family as the shapes and the Numberblocks: a chunky standing
## slab of one strong colour with eyes and a mouth.
##
## Using the real font matters for the same reason the Numberblocks are real
## cube stacks. A child is learning what the letter p LOOKS like, so it has to
## be the actual glyph, not an approximation of one.

signal touched(figure: LetterFigure)

const HEIGHT := 1.6               # cap height, metres
const DEPTH := 0.30
const BOB_HZ := 0.6
const BOB_HEIGHT := 0.03

## Warm, well-separated hues. Colour is never part of the puzzle here - it just
## has to keep ten letters telling themselves apart across the lagoon.
const COLOURS := {
	"s": Color("#e8332a"), "a": Color("#f58220"), "t": Color("#ffc400"),
	"p": Color("#5cc14c"), "i": Color("#2f9fd8"), "n": Color("#7b4fa8"),
	"m": Color("#ec4899"), "d": Color("#0d9488"), "g": Color("#d97706"),
	"o": Color("#4f46e5"),
}

var letter := "s"

var _visual: Node3D
var _mat: StandardMaterial3D
var _phase := 0.0
var _squash := 0.0
var _squash_vel := 0.0
var _lit := false


func _ready() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var mi := MeshInstance3D.new()
	var tm := TextMesh.new()
	# Lower case on purpose: it is what a child meets first in a book, and what
	# phonics teaches before capitals.
	tm.text = letter
	tm.depth = DEPTH
	tm.font_size = 128
	tm.pixel_size = 0.01
	mi.mesh = tm

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOURS.get(letter, Color.WHITE)
	_mat.roughness = 0.55
	mi.material_override = _mat
	_visual.add_child(mi)

	# TextMesh centres the glyph on its own origin and every letter is a
	# different size, so measure the mesh and stand THIS letter on the ground
	# at a common cap height. Guessing an offset gives a lagoon where p and o
	# float at different heights.
	var aabb := tm.get_aabb()
	var scale: float = HEIGHT / maxf(aabb.size.y, 0.001)
	mi.scale = Vector3(scale, scale, 1.0)
	mi.position = Vector3(-aabb.get_center().x * scale, -aabb.position.y * scale, 0.0)

	_build_face(aabb, scale)
	_build_collider(aabb, scale)

	_phase = randf() * TAU
	monitoring = true
	body_entered.connect(_on_body_entered)


## The face goes in FRONT of the glyph rather than on it. A letter has holes and
## thin strokes, and eyes placed on the surface fall through the gap in an o or
## straddle the stem of an i.
##
## It is also sized from the glyph's own ink width rather than from HEIGHT. The
## letters differ enormously in width - m is eight times wider than i - and one
## fixed eye spread hangs clean off the sides of the narrow ones. Widening with
## the letter, and shrinking the eyes when there is no room, keeps every face on
## its letter without a per-letter table.
func _build_face(aabb: AABB, scale: float) -> void:
	var ink_w: float = aabb.size.x * scale
	var half: float = ink_w * 0.5
	# Narrow letters get smaller features so the pair still fits inside the ink.
	var face: float = clampf(ink_w / 0.9, 0.42, 1.0)
	var dx: float = clampf(ink_w * 0.20, 0.045, 0.22)
	var eye_r: float = HEIGHT * 0.070 * face
	# Last resort for something as thin as an i: pull the eyes in until they fit.
	if dx + eye_r > half:
		dx = maxf(half - eye_r, 0.02)

	var front := -(DEPTH * 0.5) - 0.06
	var eye_y := HEIGHT * 0.54

	for side in [-1.0, 1.0]:
		var white := MeshInstance3D.new()
		var wm := SphereMesh.new()
		wm.radius = eye_r
		wm.height = eye_r * 2.0
		white.mesh = wm
		white.material_override = _flat(Color.WHITE)
		white.position = Vector3(side * dx, eye_y, front)
		white.scale = Vector3(1.0, 1.12, 0.45)
		_visual.add_child(white)

		var pupil := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = eye_r * 0.48
		pm.height = eye_r * 0.96
		pupil.mesh = pm
		pupil.material_override = _flat(Color("#101014"))
		pupil.position = Vector3(side * dx, eye_y, front - eye_r * 0.38)
		pupil.scale = Vector3(1.0, 1.0, 0.45)
		_visual.add_child(pupil)

	var mouth := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = HEIGHT * 0.075 * face
	mm.height = HEIGHT * 0.15 * face
	mouth.mesh = mm
	mouth.material_override = _flat(Color("#a5174a"))
	mouth.position = Vector3(0.0, eye_y - HEIGHT * 0.15 * face, front - HEIGHT * 0.008)
	mouth.scale = Vector3(1.25, 0.6, 0.3)
	_visual.add_child(mouth)


## Sized from the glyph so a wide m is as easy to walk into as a narrow i, and
## generous enough that a three-year-old aiming roughly at a letter hits it.
func _build_collider(aabb: AABB, scale: float) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(aabb.size.x * scale, 0.7) + 0.5, HEIGHT, DEPTH + 0.6)
	shape.shape = box
	shape.position.y = HEIGHT * 0.5
	add_child(shape)


func _flat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.6
	return mat


# -- life ----------------------------------------------------------------

func _process(delta: float) -> void:
	_phase += delta
	_squash_vel += (-150.0 * _squash - 13.0 * _squash_vel) * delta
	_squash += _squash_vel * delta
	_squash = clampf(_squash, -0.5, 0.5)

	_visual.scale = Vector3(1.0 - _squash * 0.45, 1.0 + _squash, 1.0 - _squash * 0.45)
	_visual.position.y = sin(_phase * TAU * BOB_HZ) * BOB_HEIGHT
	_visual.rotation.y = sin(_phase * 0.7) * 0.05


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		touched.emit(self)


func cheer() -> void:
	_squash = 0.42
	_squash_vel = 0.0
	set_lit(true)


func buzz() -> void:
	_squash = -0.3
	_squash_vel = 0.0
	var tween := create_tween()
	for i in 3:
		tween.tween_property(_visual, "rotation:z", 0.11, 0.05)
		tween.tween_property(_visual, "rotation:z", -0.11, 0.05)
	tween.tween_property(_visual, "rotation:z", 0.0, 0.05)


## A nudge for a player stuck on a round - the answer hops without lighting up,
## so the discovery stays theirs.
func hint() -> void:
	_squash = 0.26
	_squash_vel = 0.0


func set_lit(on: bool) -> void:
	_lit = on
	_mat.emission_enabled = on
	if on:
		_mat.emission = _mat.albedo_color
		_mat.emission_energy_multiplier = 0.6


func is_lit() -> bool:
	return _lit
