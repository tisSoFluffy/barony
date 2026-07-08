# TileLevel.gd
# Node3D that builds level geometry from a 2D tile-type grid.

extends Node3D

const TILE_SIZE := 2.0

const DungeonTile = preload("res://scripts/level/DungeonTile.gd")
const LevelDressing = preload("res://scripts/level/LevelDressing.gd")


# Build the level from a 2D grid of DungeonTile.Type integers.
#
# grid          - Array of Arrays: grid[row][col] = int (DungeonTile.Type)
# torch_positions - Array of Vector2i grid coords where OmniLight3D torches go
# rooms         - Array of {x,y,w,h,cx,cy} room rects (tile units) for prop scatter
# avoid_points  - Array of Vector2 (tile coords) props must stay clear of
#                 (player spawn, stairs, doorways)
func build(grid: Array, torch_positions: Array = [], rooms: Array = [], avoid_points: Array = []) -> void:
	# Clear previous geometry
	for child in get_children():
		child.queue_free()

	for row in grid.size():
		var row_data: Array = grid[row]
		for col in row_data.size():
			var tile_type: int = row_data[col]

			if tile_type == DungeonTile.Type.EMPTY:
				continue

			# Cull interior wall tiles — only render walls adjacent to open space.
			# This cuts draw calls dramatically on large procedural dungeons.
			var is_wall := tile_type == DungeonTile.Type.WALL \
				or tile_type == DungeonTile.Type.WALL_CORNER \
				or tile_type == DungeonTile.Type.TORCH_WALL
			if is_wall and not _wall_is_surface(grid, row, col):
				continue

			var world_pos := Vector3(col * TILE_SIZE, 0.0, row * TILE_SIZE)

			var mi: MeshInstance3D = DungeonTile.build_mesh(tile_type)
			if mi != null:
				# Preserve Y offset set by build_mesh (wall center etc); only set XZ from grid
				mi.position.x = world_pos.x
				mi.position.z = world_pos.z
				add_child(mi)

				# Add collision to solid wall tiles
				match tile_type:
					DungeonTile.Type.WALL, DungeonTile.Type.WALL_CORNER, DungeonTile.Type.TORCH_WALL:
						DungeonTile.build_collision(tile_type, mi)

	# Spawn placeholder torch lights
	var torch_set: Dictionary = {}
	for v in torch_positions:
		torch_set[v] = true

	# Tracks {Vector2i -> {"light":..., "embers":...}} so LevelDressing can
	# move each light/embers pair onto its sconce mount below.
	var torch_lights: Dictionary = {}

	for v in torch_set.keys():
		var col: int = v.x
		var row: int = v.y
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.60, 0.20)
		light.light_energy = 8.0
		light.omni_range = 14.0
		light.omni_attenuation = 1.6
		light.position = Vector3(col * TILE_SIZE, 2.0, row * TILE_SIZE)
		add_child(light)

		# Ember particles at the flame origin (slightly below the light)
		var embers := ParticleFactory.torch_embers()
		embers.position = Vector3(col * TILE_SIZE, 1.7, row * TILE_SIZE)
		add_child(embers)

		torch_lights[v] = {"light": light, "embers": embers}

	# Props, torch sconces, wall-top trim — all deterministic, built once here.
	LevelDressing.dress(self, grid, rooms, torch_positions, torch_lights, avoid_points)


# Returns a Dictionary {"grid": Array, "torches": Array[Vector2i]} for a
# simple 10×10 test room: border walls, interior floors, one TORCH_WALL at
# column 4 of the top border (row 1, col 4), one DOORWAY at (row 5, col 0).
static func make_test_grid() -> Dictionary:
	const ROWS := 10
	const COLS := 10

	var grid: Array = []
	for r in ROWS:
		var row: Array = []
		for c in COLS:
			var tile: int = DungeonTile.Type.FLOOR

			var on_border := (r == 0 or r == ROWS - 1 or c == 0 or c == COLS - 1)
			if on_border:
				tile = DungeonTile.Type.WALL

			# Corner tiles get WALL_CORNER
			var on_corner := ((r == 0 or r == ROWS - 1) and (c == 0 or c == COLS - 1))
			if on_corner:
				tile = DungeonTile.Type.WALL_CORNER

			# Torch wall: top border, column 4
			if r == 0 and c == 4:
				tile = DungeonTile.Type.TORCH_WALL

			# Doorway: south wall (row ROWS-1), column 5 — opening in bottom wall
			if r == ROWS - 1 and c == 5:
				tile = DungeonTile.Type.DOORWAY

			row.append(tile)
		grid.append(row)

	# Torch at the TORCH_WALL cell (col=4, row=0 — Vector2i(x=col, y=row))
	var torches: Array = [Vector2i(4, 0)]

	return {"grid": grid, "torches": torches}


# ---------------------------------------------------------------------------
# Dungeon.generate() integration
# ---------------------------------------------------------------------------

# Convert Dungeon.generate() output into the {grid, torches} format build() expects.
static func from_dungeon(dungeon: Dictionary) -> Dictionary:
	var w: int = dungeon["w"]
	var h: int = dungeon["h"]
	var raw: PackedByteArray = dungeon["tiles"]

	var grid: Array = []
	for row in h:
		var row_arr: Array = []
		for col in w:
			row_arr.append(_raw_to_type(raw[row * w + col]))
		grid.append(row_arr)

	# Torch items → grid positions for OmniLight3D placement
	var torches: Array = []
	for item in dungeon.get("items", []):
		if item["type"] == "torch":
			var pos: Vector2 = item["pos"]
			torches.append(Vector2i(roundi(pos.x), roundi(pos.y)))

	# Points prop scatter must stay clear of: player spawn, stairs, doorway tiles.
	var avoid_points: Array = []
	if dungeon.has("start"):
		avoid_points.append(dungeon["start"])
	if dungeon.get("stairs") != null:
		avoid_points.append(dungeon["stairs"])
	for row in h:
		for col in w:
			if _raw_to_type(raw[row * w + col]) == DungeonTile.Type.DOORWAY:
				avoid_points.append(Vector2(col, row))

	return {
		"grid": grid, "torches": torches,
		"rooms": dungeon.get("rooms", []), "avoid_points": avoid_points,
	}


static func _raw_to_type(raw: int) -> int:
	match raw:
		0: return DungeonTile.Type.FLOOR
		8: return DungeonTile.Type.DOORWAY
		_: return DungeonTile.Type.WALL


# Returns true if a wall tile borders at least one open (floor/doorway) tile.
# Interior walls surrounded by other walls are skipped to reduce draw calls.
static func _wall_is_surface(grid: Array, row: int, col: int) -> bool:
	var rows: int = grid.size()
	var cols: int = (grid[0] as Array).size()
	var dirs: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for d: Vector2i in dirs:
		var nr: int = row + d.y
		var nc: int = col + d.x
		if nr < 0 or nr >= rows or nc < 0 or nc >= cols:
			return true  # edge of map counts as surface
		var t: int = (grid[nr] as Array)[nc]
		if t == DungeonTile.Type.FLOOR or t == DungeonTile.Type.DOORWAY or t == DungeonTile.Type.STAIRS_DOWN:
			return true
	return false
