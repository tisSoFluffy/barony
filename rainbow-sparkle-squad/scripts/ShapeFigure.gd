class_name ShapeFigure
extends Area3D

## One shape character: a flat outline extruded into a chunky standing slab,
## with a face on the front.
##
## Like the Numberblocks these are built in code rather than generated, and for
## the same reason - a circle has to be a real circle and a triangle three real
## sides, or the thing being taught is wrong. Generated geometry cannot promise
## that.
##
## Every shape comes out of ONE extrusion of a 2D outline, so the whole set is
## guaranteed to share a look: same thickness, same bevel-free chunk, same face.
## Adding a shape means adding a list of points and nothing else.

signal touched(figure: ShapeFigure)

# Comfortably taller than the player, so a shape is something you walk up to
# and stand in front of rather than something you step over.
const HEIGHT := 1.7
const DEPTH := 0.34
const BOB_HZ := 0.6
const BOB_HEIGHT := 0.03

## name -> colour. Deliberately one strong hue each, well separated, so colour
## never becomes a second puzzle on top of the shape.
const COLOURS := {
	"circle": Color("#e8332a"),
	"square": Color("#2f7fe0"),
	"triangle": Color("#ffc400"),
	"rectangle": Color("#3fae4a"),
	"star": Color("#f58220"),
	"heart": Color("#ec4899"),
}

var shape_name := "circle"

var _visual: Node3D
var _mat: StandardMaterial3D
var _label: Label3D
var _phase := 0.0
var _squash := 0.0
var _squash_vel := 0.0
var _lit := false


func _ready() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var outline := _outline(shape_name)
	var mesh := _extrude(outline, DEPTH)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOURS.get(shape_name, Color.WHITE)
	_mat.roughness = 0.55
	mi.material_override = _mat
	_visual.add_child(mi)

	_build_face()
	_build_label()

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HEIGHT * 0.95, HEIGHT, DEPTH + 0.45)
	shape.shape = box
	shape.position.y = HEIGHT * 0.5
	add_child(shape)

	_phase = randf() * TAU
	monitoring = true
	body_entered.connect(_on_body_entered)


# -- outlines ------------------------------------------------------------

## Points in the XY plane, roughly inside [-0.5, 0.5]. Order does not matter -
## `_extrude` fixes the winding.
func _outline(which: String) -> PackedVector2Array:
	match which:
		"square":
			return PackedVector2Array([
				Vector2(-0.5, -0.5), Vector2(0.5, -0.5),
				Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
		"rectangle":
			return PackedVector2Array([
				Vector2(-0.62, -0.34), Vector2(0.62, -0.34),
				Vector2(0.62, 0.34), Vector2(-0.62, 0.34)])
		"triangle":
			return PackedVector2Array([
				Vector2(-0.55, -0.42), Vector2(0.55, -0.42), Vector2(0.0, 0.55)])
		"star":
			return _star(5, 0.55, 0.24)
		"heart":
			return _heart(48)
		_:
			return _circle(40, 0.52)


func _circle(steps: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts


## Alternating outer and inner radius, starting at the top so a star always
## stands on two legs with one point straight up.
func _star(points: int, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r: float = outer if i % 2 == 0 else inner
		var a: float = PI * 0.5 + TAU * float(i) / float(points * 2)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts


## The classic parametric heart, sampled and normalised into the same box the
## other outlines use so it does not tower over them.
func _heart(steps: int) -> PackedVector2Array:
	var raw: Array[Vector2] = []
	for i in steps:
		var t: float = TAU * float(i) / float(steps)
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = (13.0 * cos(t) - 5.0 * cos(2.0 * t)
			- 2.0 * cos(3.0 * t) - cos(4.0 * t))
		raw.append(Vector2(x, y))

	var lo := raw[0]
	var hi := raw[0]
	for p in raw:
		lo = lo.min(p)
		hi = hi.max(p)
	var span: float = maxf(maxf(hi.x - lo.x, hi.y - lo.y), 0.001)
	var mid := (lo + hi) * 0.5

	var pts := PackedVector2Array()
	for p in raw:
		pts.append((p - mid) / span * 1.1)
	return pts


# -- extrusion -----------------------------------------------------------

## Turn a closed 2D outline into a solid slab: a front cap, a back cap, and a
## wall around the rim. Normals are set explicitly rather than generated,
## because a generated normal at a sharp star point averages the two faces
## either side of it and rounds off exactly the corner that makes it a star.
func _extrude(outline: PackedVector2Array, depth: float) -> ArrayMesh:
	var pts := outline
	if _signed_area(pts) < 0.0:
		pts.reverse()             # force counter-clockwise so caps face -Z

	var tris := Geometry2D.triangulate_polygon(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var front := -depth * 0.5
	var back := depth * 0.5

	# Front cap, facing -Z (the direction the figure looks).
	for i in range(0, tris.size(), 3):
		for k in [0, 1, 2]:
			var p := pts[tris[i + k]]
			st.set_normal(Vector3(0, 0, -1))
			st.add_vertex(Vector3(p.x, p.y, front))

	# Back cap, wound the other way so it faces +Z.
	for i in range(0, tris.size(), 3):
		for k in [2, 1, 0]:
			var p := pts[tris[i + k]]
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(Vector3(p.x, p.y, back))

	# Rim: one quad per edge, its normal pointing out of the outline.
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var edge := (b - a).normalized()
		var n := Vector3(edge.y, -edge.x, 0.0)

		var a_f := Vector3(a.x, a.y, front)
		var b_f := Vector3(b.x, b.y, front)
		var a_b := Vector3(a.x, a.y, back)
		var b_b := Vector3(b.x, b.y, back)

		for v in [a_f, b_f, b_b, a_f, b_b, a_b]:
			st.set_normal(n)
			st.add_vertex(v)

	var mesh: ArrayMesh = st.commit()

	# Scale to the target height and stand it on the ground. Only X and Y are
	# scaled - depth is a fixed slab thickness shared by every shape, so a
	# circle and a rectangle read as cut from the same sheet.
	var aabb := mesh.get_aabb()
	var scale: float = HEIGHT / maxf(aabb.size.y, 0.001)
	var xform := Transform3D(Basis().scaled(Vector3(scale, scale, 1.0)),
		Vector3(0, -aabb.position.y * scale, 0))

	var out := ArrayMesh.new()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] = xform * verts[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


func _signed_area(pts: PackedVector2Array) -> float:
	var sum := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


# -- face ----------------------------------------------------------------

func _build_face() -> void:
	var front := -(DEPTH * 0.5) - 0.001
	# Sit the face a little above centre - low enough to stay inside a triangle,
	# high enough to read as a head rather than a belly.
	var eye_y := HEIGHT * 0.56
	var dx := HEIGHT * 0.11

	for side in [-1.0, 1.0]:
		var white := MeshInstance3D.new()
		var wm := SphereMesh.new()
		wm.radius = HEIGHT * 0.072
		wm.height = HEIGHT * 0.144
		white.mesh = wm
		white.material_override = _flat(Color.WHITE)
		white.position = Vector3(side * dx, eye_y, front)
		white.scale = Vector3(1.0, 1.12, 0.4)
		_visual.add_child(white)

		var pupil := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = HEIGHT * 0.036
		pm.height = HEIGHT * 0.072
		pupil.mesh = pm
		pupil.material_override = _flat(Color("#101014"))
		pupil.position = Vector3(side * dx, eye_y, front - HEIGHT * 0.028)
		pupil.scale = Vector3(1.0, 1.0, 0.4)
		_visual.add_child(pupil)

	var mouth := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = HEIGHT * 0.08
	mm.height = HEIGHT * 0.16
	mouth.mesh = mm
	mouth.material_override = _flat(Color("#a5174a"))
	mouth.position = Vector3(0.0, eye_y - HEIGHT * 0.15, front - HEIGHT * 0.01)
	mouth.scale = Vector3(1.3, 0.6, 0.28)
	_visual.add_child(mouth)


func _build_label() -> void:
	_label = Label3D.new()
	_label.text = shape_name.capitalize()
	_label.font_size = 130
	_label.outline_size = 38
	_label.modulate = Color("#3d2a52")
	_label.outline_modulate = Color(1, 1, 1, 0.95)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0022
	_label.position.y = HEIGHT + 0.28
	add_child(_label)


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
	_visual.rotation.y = sin(_phase * 0.7) * 0.06


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


## A nudge for a player who has guessed wrong twice - the answer hops on the
## spot without being given away by a glow.
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
