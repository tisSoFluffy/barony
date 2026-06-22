extends Control
class_name Minimap
## Fog-of-war corner minimap.  Renders the tile grid, player position/facing,
## live enemies, and key items (stairs, portal, shop).  Revealed area grows as
## the player explores; unvisited tiles stay dark.

const CELL    := 2     # screen pixels per dungeon tile
const PAD     := 5     # border padding (pixels)
const REVEAL_R := 10.0  # fog-of-war reveal radius (tiles)

# tile colours
const C_WALL   := Color(0.17, 0.13, 0.10)
const C_FLOOR  := Color(0.36, 0.27, 0.19)
const C_DOOR   := Color(0.56, 0.40, 0.16)
const C_LOCKED := Color(0.60, 0.47, 0.06)
const C_BG     := Color(0.04, 0.03, 0.02, 0.88)
const C_BORDER := Color(0.50, 0.38, 0.16, 0.70)

var ms: int = 1          # set in setup() from level.w
var _tiles: PackedByteArray
var _explored: PackedByteArray   # 1 = tile has been seen

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(level: Dictionary) -> void:
	ms = level.w
	_tiles = level.tiles
	_explored = PackedByteArray()
	_explored.resize(ms * ms)
	size = Vector2(ms * CELL + PAD * 2, ms * CELL + PAD * 2)

func _process(_dt: float) -> void:
	if _tiles.is_empty():
		return
	var g := Game.instance
	if g == null or g.player == null or not is_instance_valid(g.player):
		return
	_reveal(g.player.global_position.x, g.player.global_position.z)
	queue_redraw()

func _reveal(px: float, pz: float) -> void:
	var r2 := REVEAL_R * REVEAL_R
	var x0 := maxi(0, int(px - REVEAL_R) - 1)
	var x1 := mini(ms - 1, int(px + REVEAL_R) + 1)
	var y0 := maxi(0, int(pz - REVEAL_R) - 1)
	var y1 := mini(ms - 1, int(pz + REVEAL_R) + 1)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			var dx := tx + 0.5 - px
			var dy := ty + 0.5 - pz
			if dx * dx + dy * dy <= r2:
				_explored[ty * ms + tx] = 1

func _draw() -> void:
	if _tiles.is_empty():
		return

	draw_rect(Rect2(Vector2.ZERO, size), C_BG)

	# tiles
	for ty in range(ms):
		for tx in range(ms):
			if _explored[ty * ms + tx] == 0:
				continue
			var col: Color
			match _tiles[ty * ms + tx]:
				0: col = C_FLOOR
				8: col = C_DOOR
				9: col = C_LOCKED
				_: col = C_WALL
			draw_rect(Rect2(PAD + tx * CELL, PAD + ty * CELL, CELL, CELL), col)

	var g := Game.instance
	if g == null:
		return

	# live items: stairs / portal / shop
	for it: Dictionary in g.items:
		if it.get("used", false):
			continue
		var col: Color
		match it.type:
			"stairs": col = Color(0.38, 0.92, 0.38)
			"portal": col = Color(0.28, 0.85, 1.00)
			"shop":   col = Color(1.00, 0.80, 0.18)
			_: continue
		var wp: Vector3 = it.pos
		var ix := int(wp.x); var iz := int(wp.z)
		if ix < 0 or iz < 0 or ix >= ms or iz >= ms:
			continue
		if _explored[iz * ms + ix] == 0:
			continue
		draw_circle(Vector2(PAD + wp.x * CELL, PAD + wp.z * CELL), 2.5, col)

	# enemies visible in explored tiles
	for en: Node3D in g.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(en):
			continue
		var ex := en.global_position.x
		var ez := en.global_position.z
		var eix := int(ex); var eiz := int(ez)
		if eix < 0 or eiz < 0 or eix >= ms or eiz >= ms:
			continue
		if _explored[eiz * ms + eix] == 0:
			continue
		draw_circle(Vector2(PAD + ex * CELL, PAD + ez * CELL), 2.0, Color(0.90, 0.20, 0.16))

	# player dot + facing line
	# at yaw=0 the player faces -Z (north/up on map); rotating right decreases yaw
	var p := g.player
	if p == null or not is_instance_valid(p):
		return
	var cx := PAD + p.global_position.x * CELL
	var cy := PAD + p.global_position.z * CELL
	var pc  := Vector2(cx, cy)
	var fwd := Vector2(-sin(p.yaw), -cos(p.yaw)) * 5.5
	draw_line(pc, pc + fwd, Color(1.0, 0.95, 0.40, 0.90), 1.5, true)
	draw_circle(pc, 2.8, Color(1.0, 0.92, 0.30))

	draw_rect(Rect2(Vector2.ZERO, size), C_BORDER, false, 1.0)
