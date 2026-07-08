# LevelDressing.gd
# Static library that scatters props, mounts torch sconces, and adds wall-top
# trim after TileLevel builds the base geometry. Deterministic per floor:
# seeded from a hash of the grid + room layout so the same dungeon always
# dresses the same way.

const DungeonTile = preload("res://scripts/level/DungeonTile.gd")

const TILE_SIZE := 2.0
const EXCLUDE_RADIUS := 1.5  # tiles — keep props off spawn/stairs/doorways

# Prop sprite order in sprites/sliced/props/: barrel, crate, pots, bones, rubble, brazier
const PROP_BARREL  := 0
const PROP_CRATE   := 1
const PROP_POTS    := 2
const PROP_BONES   := 3
const PROP_RUBBLE  := 4
const PROP_BRAZIER := 5

const PROP_PIXEL_SIZE := 0.0036
const PROP_COLLIDER_RADIUS := 0.35

# Solid props get a walk-blocking StaticBody3D cylinder.
const PROP_SOLID := {PROP_BARREL: true, PROP_CRATE: true, PROP_BRAZIER: true}

static var _prop_textures: Array = []          # Array[Texture2D], index-aligned to PROP_*
static var _sconce_textures: Array = []        # Array[Texture2D], flame_0..2
static var _decal_textures: Array = []         # Array[Texture2D], decal_0..3
static var _wall_cap_mat: StandardMaterial3D
static var _decal_mats: Array = []             # Array[StandardMaterial3D], index-aligned to _decal_textures


# Entry point — call after TileLevel has built floor/wall meshes and torch lights.
#
# parent          - Node3D to attach dressing nodes to (the TileLevel itself)
# grid            - Array of Arrays: grid[row][col] = DungeonTile.Type int
# rooms           - Array of {x,y,w,h,cx,cy} dicts (Dungeon.generate() room rects, tile units)
# torch_positions - Array of Vector2i (col,row) — same list passed to TileLevel.build()
# torch_lights    - Dictionary {Vector2i -> {"light": OmniLight3D, "embers": GPUParticles3D}}
#                   already placed by TileLevel; sconces reposition to match.
# avoid_points    - Array of Vector2 (tile coords: x=col, y=row) to keep props clear of
#                   (player spawn, stairs, doorways)
static func dress(parent: Node3D, grid: Array, rooms: Array, torch_positions: Array,
		torch_lights: Dictionary, avoid_points: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_grid(grid, rooms)

	_load_prop_textures()
	_load_sconce_textures()
	_load_decal_textures()

	# Sconce mounts are prop-exclusion zones too — a barrel clipping into a wall
	# torch reads as a bug, not clutter. Merge them into the avoid list.
	var prop_avoid := avoid_points.duplicate()
	for v: Vector2i in torch_positions:
		prop_avoid.append(Vector2(v.x, v.y))

	_build_wall_caps(parent, grid)
	_build_doorway_arches(parent, grid)
	_scatter_props(parent, grid, rooms, prop_avoid, rng)
	_mount_sconces(parent, grid, torch_positions, torch_lights)
	_scatter_decals(parent, grid, rooms, prop_avoid, rng)


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

static func _hash_grid(grid: Array, rooms: Array) -> int:
	var h := 2166136261
	for row: Array in grid:
		for t: int in row:
			h = (h ^ t) & 0xffffffff
			h = (h * 16777619) & 0xffffffff
	for r: Dictionary in rooms:
		h = (h ^ int(r.get("x", 0)) ^ (int(r.get("y", 0)) << 8)) & 0xffffffff
		h = (h * 16777619) & 0xffffffff
	return h & 0x7fffffff


# ---------------------------------------------------------------------------
# Asset loading (guarded — sprites may not exist yet)
# ---------------------------------------------------------------------------

static func _load_prop_textures() -> void:
	if not _prop_textures.is_empty():
		return
	for i in range(6):
		var path := "res://sprites/sliced/props/prop_%d.png" % i
		_prop_textures.append(load(path) if ResourceLoader.exists(path) else null)


static func _load_sconce_textures() -> void:
	if not _sconce_textures.is_empty():
		return
	for i in range(3):
		var path := "res://sprites/sliced/sconce/flame_%d.png" % i
		_sconce_textures.append(load(path) if ResourceLoader.exists(path) else null)


static func _load_decal_textures() -> void:
	if not _decal_textures.is_empty():
		return
	for i in range(4):
		var path := "res://sprites/sliced/decals/decal_%d.png" % i
		_decal_textures.append(load(path) if ResourceLoader.exists(path) else null)


# Autoload lookup that works from static functions — bare autoload identifiers
# don't reliably resolve in static scope (editor analyzer rejects them until a
# project reload, and it's fragile across Godot versions). Null-safe.
static func _autoload(from: Node, name: String) -> Node:
	var tree := from.get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(name)


# ---------------------------------------------------------------------------
# Prop scatter
# ---------------------------------------------------------------------------

static func _scatter_props(parent: Node3D, grid: Array, rooms: Array,
		avoid_points: Array, rng: RandomNumberGenerator) -> void:
	if _prop_textures.is_empty() or _prop_textures[0] == null:
		return  # no prop sprites yet — skip gracefully

	for room_idx in rooms.size():
		var room: Dictionary = rooms[room_idx]
		var count := rng.randi_range(1, 4)
		# Later rooms (by generation order) read as farther from the start —
		# skew their prop mix toward bones/rubble; early rooms toward supplies.
		var depth_frac := float(room_idx) / maxf(1.0, float(rooms.size() - 1))

		var placed := 0
		var tries := 0
		while placed < count and tries < count * 6:
			tries += 1
			var tile: Variant = _pick_wall_hugging_tile(grid, room, rng)
			if tile == null:
				continue
			var col: int = (tile as Vector2i).x
			var row: int = (tile as Vector2i).y

			if _near_any(Vector2(col, row), avoid_points, EXCLUDE_RADIUS):
				continue

			var prop_type := _pick_prop_type(depth_frac, rng)
			_place_prop(parent, room, col, row, prop_type, rng)
			placed += 1


# Picks a floor tile near a room's wall/corner (not center) to hug props against.
static func _pick_wall_hugging_tile(grid: Array, room: Dictionary, rng: RandomNumberGenerator) -> Variant:
	var rx: int = room.x
	var ry: int = room.y
	var rw: int = room.w
	var rh: int = room.h
	# Bias toward the ring one tile in from the room's border.
	var side := rng.randi_range(0, 3)
	var col: int; var row: int
	match side:
		0: col = rx + 1;          row = rng.randi_range(ry + 1, ry + rh - 2)
		1: col = rx + rw - 2;     row = rng.randi_range(ry + 1, ry + rh - 2)
		2: col = rng.randi_range(rx + 1, rx + rw - 2); row = ry + 1
		_: col = rng.randi_range(rx + 1, rx + rw - 2); row = ry + rh - 2

	if row < 0 or row >= grid.size():
		return null
	var row_data: Array = grid[row]
	if col < 0 or col >= row_data.size():
		return null
	if row_data[col] != DungeonTile.Type.FLOOR:
		return null
	return Vector2i(col, row)


static func _pick_prop_type(depth_frac: float, rng: RandomNumberGenerator) -> int:
	# Brazier: rare, roughly 1 in every 2 rooms worth of props (~12% per prop roll)
	if rng.randf() < 0.12:
		return PROP_BRAZIER

	var pool: Array
	if depth_frac < 0.5:
		pool = [PROP_BARREL, PROP_BARREL, PROP_CRATE, PROP_CRATE, PROP_POTS, PROP_BONES, PROP_RUBBLE]
	else:
		pool = [PROP_BONES, PROP_BONES, PROP_RUBBLE, PROP_RUBBLE, PROP_BARREL, PROP_CRATE, PROP_POTS]
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _place_prop(parent: Node3D, room: Dictionary, col: int, row: int,
		prop_type: int, rng: RandomNumberGenerator) -> void:
	var tex: Texture2D = _prop_textures[prop_type]
	if tex == null:
		return

	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = PROP_PIXEL_SIZE * rng.randf_range(0.85, 1.15)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.flip_h = rng.randf() < 0.5

	# Offset a touch toward the nearest wall so props hug the room edge rather
	# than sitting dead-center on the tile.
	var cx: float = room.cx
	var cy: float = room.cy
	var away := Vector2(col - cx, row - cy).normalized()
	var wx := col * TILE_SIZE + away.x * 0.4
	var wz := row * TILE_SIZE + away.y * 0.4

	sprite.position = Vector3(wx, tex.get_height() * sprite.pixel_size * 0.5, wz)
	parent.add_child(sprite)

	var sf := _autoload(parent, "ShadowFactory")
	if sf != null and sf.has_method("make_shadow"):
		var shadow: Node3D = sf.make_shadow(0.5)
		shadow.position = Vector3(sprite.position.x, 0.02, sprite.position.z)
		parent.add_child(shadow)

	if PROP_SOLID.has(prop_type):
		_add_prop_collision(parent, sprite.position)

	if prop_type == PROP_BRAZIER:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.18)
		light.light_energy = 3.0
		light.omni_range = 6.0
		light.position = sprite.position + Vector3(0, 0.4, 0)
		parent.add_child(light)

		var pf := _autoload(parent, "ParticleFactory")
		if pf != null and pf.has_method("torch_embers"):
			var embers: GPUParticles3D = pf.torch_embers()
			embers.position = sprite.position + Vector3(0, 0.5, 0)
			parent.add_child(embers)

		if pf != null and pf.has_method("dust_motes"):
			var motes: GPUParticles3D = pf.dust_motes()
			motes.position = sprite.position + Vector3(0, 0.8, 0)
			parent.add_child(motes)


static func _add_prop_collision(parent: Node3D, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = PROP_COLLIDER_RADIUS
	shape.height = 1.2
	col_shape.shape = shape
	col_shape.position = Vector3(0, 0.6, 0)
	body.add_child(col_shape)
	body.position = pos
	parent.add_child(body)


static func _near_any(p: Vector2, points: Array, radius: float) -> bool:
	for a in points:
		var av: Vector2 = a
		if p.distance_to(av) < radius:
			return true
	return false


# ---------------------------------------------------------------------------
# Standing torches — a floor-standing torch placed against the adjacent wall.
# Grounded (base on the floor) so the billboard never reads as floating the
# way a wall-mounted sconce did from off-axis camera angles.
# ---------------------------------------------------------------------------

const TORCH_PIXEL_SIZE := 0.0025  # 691px frame → ~1.7m tall, human scale

static func _mount_sconces(parent: Node3D, grid: Array, torch_positions: Array,
		torch_lights: Dictionary) -> void:
	if _sconce_textures.is_empty() or _sconce_textures[0] == null:
		return  # no sconce sprites yet — skip gracefully

	for v in torch_positions:
		var pos: Vector2i = v
		var wall_dir := _find_adjacent_wall_dir(grid, pos)
		# Pull in from the wall face so the tripod base doesn't clip into it
		var offset := Vector3(wall_dir.x, 0.0, wall_dir.y) * (TILE_SIZE * 0.5 - 0.35)

		var tex_h: float = _sconce_textures[0].get_height() * TORCH_PIXEL_SIZE
		var base_pos := Vector3(pos.x * TILE_SIZE, 0.0, pos.y * TILE_SIZE) + offset
		var sprite_pos := base_pos + Vector3(0, tex_h * 0.5, 0)   # bottom on floor
		var flame_pos := base_pos + Vector3(0, tex_h * 0.85, 0)   # brazier cup height

		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		frames.add_animation("flame")
		frames.set_animation_speed("flame", 8.0)
		frames.set_animation_loop("flame", true)
		for tex: Texture2D in _sconce_textures:
			if tex != null:
				frames.add_frame("flame", tex)

		var sprite := AnimatedSprite3D.new()
		sprite.sprite_frames = frames
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.shaded = false
		sprite.pixel_size = TORCH_PIXEL_SIZE
		sprite.position = sprite_pos
		sprite.play("flame")
		parent.add_child(sprite)

		# Ground it like the other billboards
		var sf := _autoload(parent, "ShadowFactory")
		if sf != null and sf.has_method("make_shadow"):
			var shadow: Node3D = sf.make_shadow(0.5)
			shadow.position = base_pos + Vector3(0, 0.02, 0)
			parent.add_child(shadow)

		# Move the pre-placed light/embers to the flame so the glow reads
		# as coming from the brazier cup.
		if torch_lights.has(pos):
			var entry: Dictionary = torch_lights[pos]
			var light: OmniLight3D = entry.get("light")
			var embers: GPUParticles3D = entry.get("embers")
			if light != null:
				light.position = flame_pos
			if embers != null:
				embers.position = flame_pos + Vector3(0, -0.15, 0)

		var pf := _autoload(parent, "ParticleFactory")
		if pf != null and pf.has_method("dust_motes"):
			var motes: GPUParticles3D = pf.dust_motes()
			motes.position = base_pos + Vector3(-wall_dir.x, 0.5, -wall_dir.y) * 0.8
			parent.add_child(motes)


# Returns a unit-ish Vector2i direction (dx, dy) toward the nearest solid wall
# tile adjacent to `pos`; Vector2i.ZERO if none found (shouldn't happen for a
# valid TORCH_WALL tile, which always borders open space it faces away from).
static func _find_adjacent_wall_dir(grid: Array, pos: Vector2i) -> Vector2i:
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var rows: int = grid.size()
	for d: Vector2i in dirs:
		var nr := pos.y + d.y
		var nc := pos.x + d.x
		if nr < 0 or nr >= rows:
			continue
		var row_data: Array = grid[nr]
		if nc < 0 or nc >= row_data.size():
			continue
		var t: int = row_data[nc]
		var is_open := t == DungeonTile.Type.FLOOR or t == DungeonTile.Type.DOORWAY \
			or t == DungeonTile.Type.STAIRS_DOWN
		if is_open:
			return -d  # face outward from the open side, i.e. toward the wall
	return Vector2i.ZERO


# ---------------------------------------------------------------------------
# Wall-top trim — thin dark cap on each rendered wall tile, strengthens
# room silhouettes from the isometric camera.
# ---------------------------------------------------------------------------

const WALL_TEX := preload("res://sprites/environments/dungeon-wall.png")

# Cap reuses the wall texture, heavily darkened — reads as stone in shadow
# rather than a flat black void slab from the iso camera.
static func _wall_cap_material() -> StandardMaterial3D:
	if _wall_cap_mat == null:
		_wall_cap_mat = StandardMaterial3D.new()
		_wall_cap_mat.albedo_texture = WALL_TEX
		_wall_cap_mat.albedo_color = Color(0.25, 0.25, 0.25)  # multiplies texture down dark
		_wall_cap_mat.roughness = 1.0
		_wall_cap_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_wall_cap_mat.uv1_triplanar = true
		_wall_cap_mat.uv1_world_triplanar = true
		_wall_cap_mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return _wall_cap_mat


static func _build_wall_caps(parent: Node3D, grid: Array) -> void:
	const CAP_HEIGHT := 0.12
	const WALL_HEIGHT := 3.0  # DungeonTile.WALL_HEIGHT

	for row in grid.size():
		var row_data: Array = grid[row]
		for col in row_data.size():
			var t: int = row_data[col]
			var is_wall := t == DungeonTile.Type.WALL or t == DungeonTile.Type.WALL_CORNER \
				or t == DungeonTile.Type.TORCH_WALL
			if not is_wall:
				continue
			if not _wall_is_surface(grid, row, col):
				continue  # same culling as TileLevel — only dress visible walls

			var mi := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(TILE_SIZE, CAP_HEIGHT, TILE_SIZE)
			mi.mesh = mesh
			mi.material_override = _wall_cap_material()
			mi.position = Vector3(col * TILE_SIZE, WALL_HEIGHT + CAP_HEIGHT * 0.5, row * TILE_SIZE)
			parent.add_child(mi)


# Mirrors TileLevel._wall_is_surface — kept local so LevelDressing has no
# hard dependency on TileLevel's private helper.
static func _wall_is_surface(grid: Array, row: int, col: int) -> bool:
	var rows: int = grid.size()
	var cols: int = (grid[0] as Array).size()
	var dirs: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for d: Vector2i in dirs:
		var nr := row + d.y
		var nc := col + d.x
		if nr < 0 or nr >= rows or nc < 0 or nc >= cols:
			return true
		var t: int = (grid[nr] as Array)[nc]
		if t == DungeonTile.Type.FLOOR or t == DungeonTile.Type.DOORWAY or t == DungeonTile.Type.STAIRS_DOWN:
			return true
	return false


# ---------------------------------------------------------------------------
# Doorway arches — jamb posts + lintel so DOORWAY tiles (currently empty
# geometry) read as a built opening rather than a random gap in the wall.
# ---------------------------------------------------------------------------

const JAMB_WIDTH := 0.25
const LINTEL_DROP := 0.6  # lintel spans the top slice of the opening

static func _build_doorway_arches(parent: Node3D, grid: Array) -> void:
	const WALL_HEIGHT := 3.0  # DungeonTile.WALL_HEIGHT

	for row in grid.size():
		var row_data: Array = grid[row]
		for col in row_data.size():
			if row_data[col] != DungeonTile.Type.DOORWAY:
				continue

			# Passage axis: whichever side pair (N/S or E/W) is walled off is
			# perpendicular to the walk-through direction. Jambs sit on that axis.
			var wall_ns := _is_wall_at(grid, row - 1, col) or _is_wall_at(grid, row + 1, col)
			var wall_ew := _is_wall_at(grid, row, col - 1) or _is_wall_at(grid, row, col + 1)

			# Jambs flank the opening along the axis perpendicular to travel —
			# if walls are N/S, the doorway is walked through E/W, so jambs sit N/S.
			var jamb_axis := Vector3(0, 0, 1) if wall_ns else Vector3(1, 0, 0)
			if not wall_ns and not wall_ew:
				continue  # isolated doorway tile, shouldn't happen — skip safely

			var base := Vector3(col * TILE_SIZE, 0.0, row * TILE_SIZE)
			var half_gap := TILE_SIZE * 0.5 - JAMB_WIDTH * 0.5

			for sign in [-1.0, 1.0]:
				var post := MeshInstance3D.new()
				var post_mesh := BoxMesh.new()
				# Post footprint stretches along the wall-flush axis, narrow across the opening.
				if jamb_axis.x > 0.5:
					post_mesh.size = Vector3(JAMB_WIDTH, WALL_HEIGHT, TILE_SIZE)
				else:
					post_mesh.size = Vector3(TILE_SIZE, WALL_HEIGHT, JAMB_WIDTH)
				post.mesh = post_mesh
				post.material_override = _wall_cap_material()
				post.position = base + jamb_axis * (sign * half_gap) + Vector3(0, WALL_HEIGHT * 0.5, 0)
				parent.add_child(post)

				var body := StaticBody3D.new()
				var cshape := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = post_mesh.size
				cshape.shape = shape
				body.add_child(cshape)
				post.add_child(body)

			# Lintel spans the full opening width at the top, leaving the walk-through
			# clear below (WALL_HEIGHT - LINTEL_DROP).
			var lintel := MeshInstance3D.new()
			var lintel_mesh := BoxMesh.new()
			lintel_mesh.size = Vector3(TILE_SIZE, LINTEL_DROP, TILE_SIZE)
			lintel.mesh = lintel_mesh
			lintel.material_override = _wall_cap_material()
			lintel.position = base + Vector3(0, WALL_HEIGHT - LINTEL_DROP * 0.5, 0)
			parent.add_child(lintel)


static func _is_wall_at(grid: Array, row: int, col: int) -> bool:
	if row < 0 or row >= grid.size():
		return true
	var row_data: Array = grid[row]
	if col < 0 or col >= row_data.size():
		return true
	var t: int = row_data[col]
	return t == DungeonTile.Type.WALL or t == DungeonTile.Type.WALL_CORNER or t == DungeonTile.Type.TORCH_WALL


# ---------------------------------------------------------------------------
# Floor decals — crack/moss/puddle/pebbles quads scattered on room floors.
# Purely cosmetic (no collision), guarded by ResourceLoader.exists at load —
# degrades to a no-op if the decal sprites haven't landed yet.
# ---------------------------------------------------------------------------

const DECAL_SIZE_MIN := 0.5
const DECAL_SIZE_MAX := 1.1

static func _decal_material(idx: int) -> StandardMaterial3D:
	while _decal_mats.size() <= idx:
		_decal_mats.append(null)
	if _decal_mats[idx] == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _decal_textures[idx]
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_decal_mats[idx] = mat
	return _decal_mats[idx]


static func _scatter_decals(parent: Node3D, grid: Array, rooms: Array,
		avoid_points: Array, rng: RandomNumberGenerator) -> void:
	if _decal_textures.is_empty() or _decal_textures[0] == null:
		return  # no decal sprites yet — skip gracefully

	for room: Dictionary in rooms:
		var rx: int = room.x
		var ry: int = room.y
		var rw: int = room.w
		var rh: int = room.h
		var count := rng.randi_range(2, 4)

		var placed := 0
		var tries := 0
		while placed < count and tries < count * 6:
			tries += 1
			var col := rng.randi_range(rx + 1, rx + rw - 2)
			var row := rng.randi_range(ry + 1, ry + rh - 2)
			if row < 0 or row >= grid.size():
				continue
			var row_data: Array = grid[row]
			if col < 0 or col >= row_data.size():
				continue
			if row_data[col] != DungeonTile.Type.FLOOR:
				continue
			if _near_any(Vector2(col, row), avoid_points, EXCLUDE_RADIUS):
				continue

			var idx := rng.randi_range(0, _decal_textures.size() - 1)
			if _decal_textures[idx] == null:
				continue

			var mi := MeshInstance3D.new()
			var mesh := PlaneMesh.new()  # FACE_Y — flat on the floor
			var sz := rng.randf_range(DECAL_SIZE_MIN, DECAL_SIZE_MAX)
			mesh.size = Vector2(sz, sz)
			mi.mesh = mesh
			mi.material_override = _decal_material(idx)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.rotation.y = rng.randf_range(0.0, TAU)
			mi.position = Vector3(col * TILE_SIZE, 0.01, row * TILE_SIZE)
			parent.add_child(mi)
			placed += 1
