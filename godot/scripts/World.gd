extends Node3D
class_name World
## Builds the 3D dungeon from a Dungeon.generate() dictionary: textured floor &
## ceiling, instanced walls (visual via MultiMesh, collision via StaticBody),
## and torch lights. Billboards for actors/items are added by Game.

const WALL_H := 3.0

var level: Dictionary
var _doors: Dictionary = {}   # Vector2i → [MeshInstance3D, StaticBody3D]

func build(lv: Dictionary) -> void:
	level = lv
	var ms: int = lv.w
	var tiles: PackedByteArray = lv.tiles
	var theme: int = lv.theme

	# ---- floor ----
	var fmat := StandardMaterial3D.new()
	fmat.albedo_texture = Art.floor_texture(theme)
	fmat.uv1_scale = Vector3(ms, ms, 1)
	fmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var fm := MeshInstance3D.new()
	var fp := PlaneMesh.new()
	fp.size = Vector2(ms, ms)
	fm.mesh = fp
	fm.material_override = fmat
	fm.position = Vector3(ms / 2.0, 0, ms / 2.0)
	add_child(fm)

	# ---- ceiling ----
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Art.ceil_color(theme)
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cm := MeshInstance3D.new()
	var cp := PlaneMesh.new()
	cp.size = Vector2(ms, ms)
	cm.mesh = cp
	cm.material_override = cmat
	cm.position = Vector3(ms / 2.0, WALL_H, ms / 2.0)
	add_child(cm)

	# ---- walls: solid tiles only — doors handled separately ----
	var wpos: Array = []
	for y in range(ms):
		for x in range(ms):
			var t := tiles[y * ms + x]
			if t > 0 and t != 8 and t != 9:
				wpos.append(Vector2i(x, y))

	var wmat := StandardMaterial3D.new()
	wmat.albedo_texture = Art.wall_texture(theme)
	wmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var box := BoxMesh.new()
	box.size = Vector3(1, WALL_H, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = wpos.size()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = wmat
	add_child(mmi)

	var body := StaticBody3D.new()
	add_child(body)
	for i in wpos.size():
		var p: Vector2i = wpos[i]
		var t := Transform3D(Basis(), Vector3(p.x + 0.5, WALL_H / 2.0, p.y + 0.5))
		mm.set_instance_transform(i, t)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1, WALL_H, 1)
		cs.shape = bs
		cs.position = Vector3(p.x + 0.5, WALL_H / 2.0, p.y + 0.5)
		body.add_child(cs)

	# ---- doors: individual nodes keyed by grid pos for runtime removal ----
	_doors.clear()
	for y in range(ms):
		for x in range(ms):
			var t := tiles[y * ms + x]
			if t == 8 or t == 9:
				_spawn_door(x, y, t)

	# ---- torch lights ----
	for it in lv.items:
		if it.type == "torch":
			var l := OmniLight3D.new()
			l.position = Vector3(it.pos.x, 1.9, it.pos.y)
			l.light_color = Color(1.0, 0.62, 0.22)
			l.omni_range = 7.0
			l.light_energy = 2.4
			add_child(l)

func _spawn_door(x: int, y: int, tile: int) -> void:
	var pos := Vector3(x + 0.5, WALL_H / 2.0, y + 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = Art.door_texture(tile == 9)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(1.0, 1.0 / WALL_H, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.06, 0.04, 0.01)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, WALL_H, 1.0)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, WALL_H, 1.0)
	cs.shape = bs
	sb.position = pos
	sb.add_child(cs)
	add_child(sb)
	_doors[Vector2i(x, y)] = [mi, sb]

func open_door(grid_pos: Vector2i) -> void:
	if not _doors.has(grid_pos):
		return
	var pair: Array = _doors[grid_pos]
	pair[0].queue_free()
	pair[1].queue_free()
	_doors.erase(grid_pos)

func make_billboard(spr: String, ground_pos: Vector3, world_h: float) -> Sprite3D:
	var s := Sprite3D.new()
	var tx: Texture2D = Art.actor_texture(spr)
	s.texture = tx
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.pixel_size = world_h / float(tx.get_height())
	s.position = ground_pos + Vector3(0, world_h / 2.0, 0)
	s.shaded = false
	return s

func spawn_spark(pos: Vector3, col: Color) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = pos
	add_child(m)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ZERO, 0.4)
	tw.tween_callback(m.queue_free)
