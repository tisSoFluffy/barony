# Static library for building tile meshes and collision shapes.

enum Type {
	EMPTY,
	FLOOR,
	WALL,
	WALL_CORNER,
	DOORWAY,
	STAIRS_DOWN,
	TORCH_WALL,
}

# Tile dimensions
const TILE_SIZE := 2.0
const WALL_HEIGHT := 3.0
const WALL_Y_CENTER := 1.5  # WALL_HEIGHT / 2

const WALL_TEX   := preload("res://sprites/environments/dungeon-wall.png")
const FLOOR_TEX  := preload("res://sprites/environments/dungeon-floor.png")
const STAIRS_TEX := preload("res://sprites/environments/dungeon-stairs.png")

# One shared material per surface type — a procedural dungeon spawns hundreds
# of tiles, and per-tile materials defeat draw-call batching.
static var _wall_mat:   StandardMaterial3D
static var _floor_mat:  StandardMaterial3D
static var _stairs_mat: StandardMaterial3D


# World-space triplanar mapping so brick courses and flagstone rows run
# continuously across adjacent tile meshes — hides the box-per-tile seams.
# uv1_scale sets density: 0.5 = texture spans 2m, 0.35 ≈ 2.9m.
static func _make_material(texture: Texture2D, density: float, roughness: float = 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.roughness = roughness
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(density, density, density)
	return mat


static func _wall_material() -> StandardMaterial3D:
	if _wall_mat == null:
		_wall_mat = _make_material(WALL_TEX, 0.5)
	return _wall_mat


static func _floor_material() -> StandardMaterial3D:
	if _floor_mat == null:
		# Lower density → larger flagstones, less visual noise at camera distance
		_floor_mat = _make_material(FLOOR_TEX, 0.35, 0.95)
	return _floor_mat


static func _stairs_material() -> StandardMaterial3D:
	if _stairs_mat == null:
		_stairs_mat = _make_material(STAIRS_TEX, 0.5)
	return _stairs_mat


# Returns a MeshInstance3D for the given tile type, or null for EMPTY/DOORWAY.
static func build_mesh(type: int) -> MeshInstance3D:
	match type:
		Type.EMPTY:
			return null

		Type.FLOOR:
			var mi := MeshInstance3D.new()
			var mesh := PlaneMesh.new()
			mesh.size = Vector2(TILE_SIZE, TILE_SIZE)
			mi.mesh = mesh
			mi.material_override = _floor_material()
			# PlaneMesh is horizontal at Y=0 by default
			return mi

		Type.WALL:
			var mi := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(TILE_SIZE, WALL_HEIGHT, TILE_SIZE)
			mi.mesh = mesh
			mi.material_override = _wall_material()
			mi.position.y = WALL_Y_CENTER
			return mi

		Type.WALL_CORNER:
			var mi := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			# Square footprint (equal x/z)
			mesh.size = Vector3(TILE_SIZE, WALL_HEIGHT, TILE_SIZE)
			mi.mesh = mesh
			mi.material_override = _wall_material()
			mi.position.y = WALL_Y_CENTER
			return mi

		Type.DOORWAY:
			return null  # Open passage — no mesh

		Type.STAIRS_DOWN:
			var mi := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			# Slightly thinner vertical profile to suggest steps
			mesh.size = Vector3(TILE_SIZE, 0.3, TILE_SIZE)
			mi.mesh = mesh
			mi.material_override = _stairs_material()
			# Slight incline to suggest descent
			mi.rotation_degrees.x = -10.0
			return mi

		Type.TORCH_WALL:
			# Same geometry as a regular wall; TorchLight node added by TileLevel
			var mi := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(TILE_SIZE, WALL_HEIGHT, TILE_SIZE)
			mi.mesh = mesh
			mi.material_override = _wall_material()
			mi.position.y = WALL_Y_CENTER
			return mi

		_:
			return null


# Adds StaticBody3D + CollisionShape3D to `parent` for solid tile types.
# FLOOR and DOORWAY intentionally have no collision added.
static func build_collision(type: int, parent: Node3D) -> void:
	match type:
		Type.WALL, Type.WALL_CORNER, Type.TORCH_WALL:
			var body := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(TILE_SIZE, WALL_HEIGHT, TILE_SIZE)
			col.shape = shape
			# StaticBody3D is a child of the mesh (already at WALL_Y_CENTER in world);
			# collision shape sits at local origin — no additional Y offset needed
			body.add_child(col)
			parent.add_child(body)
		_:
			pass  # No collision for FLOOR, DOORWAY, STAIRS_DOWN, EMPTY
