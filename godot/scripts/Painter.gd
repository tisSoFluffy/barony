extends RefCounted
class_name Painter
## A tiny CPU rasterizer that mirrors the web build's canvas helper API
## (S / shp / rrect / ell / tri / dot + path ops), so the procedural
## Warcraft-style art ports across almost 1:1. Renders into an Image, which
## works in headless mode (no GPU) and is therefore unit-testable.

var img: Image
var w: int
var h: int
var _pts: PackedVector2Array = PackedVector2Array()
const OUTLINE := Color(0.090, 0.059, 0.024)   # #170f06

func _init(width: int, height: int) -> void:
	w = width
	h = height
	img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

func texture() -> ImageTexture:
	return ImageTexture.create_from_image(img)

# ---- low-level blending ----
func _blend(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
		return
	if c.a <= 0.001:
		return
	var d := img.get_pixel(x, y)
	var a := c.a + d.a * (1.0 - c.a)
	if a <= 0.0001:
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var r := (c.r * c.a + d.r * d.a * (1.0 - c.a)) / a
	var g := (c.g * c.a + d.g * d.a * (1.0 - c.a)) / a
	var b := (c.b * c.a + d.b * d.a * (1.0 - c.a)) / a
	img.set_pixel(x, y, Color(r, g, b, a))

func _disc(cx: float, cy: float, r: float, c: Color) -> void:
	var r2 := r * r
	var x0 := int(floor(cx - r)); var x1 := int(ceil(cx + r))
	var y0 := int(floor(cy - r)); var y1 := int(ceil(cy + r))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			if dx * dx + dy * dy <= r2:
				_blend(x, y, c)

# ---- public colour helper ----
static func hex(s: String) -> Color:
	return Color.html("#" + s) if not s.begins_with("#") else Color.html(s)

# ---- path building (canvas-style) ----
func begin() -> void:
	_pts = PackedVector2Array()

func move_to(x: float, y: float) -> void:
	_pts.append(Vector2(x, y))

func line_to(x: float, y: float) -> void:
	_pts.append(Vector2(x, y))

func quad_to(cx: float, cy: float, x: float, y: float) -> void:
	# tessellate a quadratic bezier from the last point
	var p0: Vector2 = _pts[_pts.size() - 1] if _pts.size() > 0 else Vector2(x, y)
	var steps := 10
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var u := 1.0 - t
		var px := u * u * p0.x + 2.0 * u * t * cx + t * t * x
		var py := u * u * p0.y + 2.0 * u * t * cy + t * t * y
		_pts.append(Vector2(px, py))

func fill_path(c: Color) -> void:
	_fill_polygon(_pts, c)

func stroke_path(c: Color, width: float, closed: bool = true) -> void:
	_stroke(_pts, c, width, closed)

# ---- scanline polygon fill ----
func _fill_polygon(pts: PackedVector2Array, c: Color) -> void:
	var n := pts.size()
	if n < 3:
		return
	var miny := INF; var maxy := -INF
	for p in pts:
		miny = min(miny, p.y); maxy = max(maxy, p.y)
	var ys := int(floor(miny)); var ye := int(ceil(maxy))
	for y in range(ys, ye + 1):
		var yc := y + 0.5
		var xs: Array = []
		var j := n - 1
		for i in range(n):
			var a := pts[i]; var b := pts[j]
			if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
				var t := (yc - a.y) / (b.y - a.y)
				xs.append(a.x + t * (b.x - a.x))
			j = i
		xs.sort()
		var k := 0
		while k + 1 < xs.size():
			var x0 := int(round(xs[k]))
			var x1 := int(round(xs[k + 1]))
			for x in range(x0, x1):
				_blend(x, y, c)
			k += 2

# ---- thick round-joined/round-capped stroke (stamps discs) ----
func _stroke(pts: PackedVector2Array, c: Color, width: float, closed: bool) -> void:
	var n := pts.size()
	if n < 2:
		return
	var r := width * 0.5
	var segs := n if closed else n - 1
	for i in range(segs):
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var d := a.distance_to(b)
		var steps := int(ceil(d)) + 1
		for s in range(steps + 1):
			var t := float(s) / steps
			_disc(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, r, c)

# ---- canvas-mirroring convenience shapes ----
## filled + outlined arbitrary path
func shp(fill: Color, builder: Callable) -> void:
	begin()
	builder.call(self)
	fill_path(fill)
	stroke_path(OUTLINE, 2.2, true)

func rrect(fill: Color, x: float, y: float, ww: float, hh: float, _r: float = 0.0) -> void:
	begin()
	move_to(x, y); line_to(x + ww, y); line_to(x + ww, y + hh); line_to(x, y + hh)
	fill_path(fill)
	stroke_path(OUTLINE, 2.2, true)

func ell(fill: Color, cx: float, cy: float, rx: float, ry: float) -> void:
	begin()
	var steps := 24
	for i in range(steps):
		var a := TAU * i / steps
		if i == 0:
			move_to(cx + cos(a) * rx, cy + sin(a) * ry)
		else:
			line_to(cx + cos(a) * rx, cy + sin(a) * ry)
	fill_path(fill)
	stroke_path(OUTLINE, 2.2, true)

func tri(fill: Color, x1: float, y1: float, x2: float, y2: float, x3: float, y3: float) -> void:
	begin()
	move_to(x1, y1); line_to(x2, y2); line_to(x3, y3)
	fill_path(fill)
	stroke_path(OUTLINE, 2.2, true)

## filled circle, no outline (the web `dot`)
func dot(fill: Color, x: float, y: float, r: float) -> void:
	_disc(x, y, r, fill)

func rect_fill(fill: Color, x: float, y: float, ww: float, hh: float) -> void:
	for yy in range(int(y), int(y + hh)):
		for xx in range(int(x), int(x + ww)):
			_blend(xx, yy, fill)

## thick line in an arbitrary colour (for held weapon shafts etc.)
func line(col: Color, x1: float, y1: float, x2: float, y2: float, width: float) -> void:
	var seg := PackedVector2Array([Vector2(x1, y1), Vector2(x2, y2)])
	_stroke(seg, col, width, false)
