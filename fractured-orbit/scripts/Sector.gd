class_name Sector
extends Node3D
## Turns a SectorGen layout into walkable 3D space: brutalist floor/wall slabs
## with collision, corridors between rooms, vertical platforms, area lighting in
## the sector palette, and instanced props / hazards / enemies. Also spawns the
## permadeath "echoes" — debris + ghost-notes at the positions where past runs
## died.

const WALL_H := 5.0
const WALL_T := 0.6

var gen: SectorGen
var pal: Dictionary
var enemies: Array = []          # live Enemy nodes
var hazards: Array = []          # live Hazard nodes
var interactables: Array = []    # {pos, kind, id/name} for the player's E-prompt
var boss: Node = null            # the NEXUS / Core Guardian, if this sector has one
var _glitch := false             # sector 4: walls wear the reality-break shader

func build(g: SectorGen) -> void:
	gen = g
	pal = Sectors.palette(g.sector)
	_glitch = g.sector == 4
	for room in gen.rooms:
		_build_room(room)
	_build_corridors()
	_spawn_echoes()
	_spawn_boss()

func _build_room(room: Dictionary) -> void:
	var c: Vector3 = room["center"]
	var s: Vector2 = room["size"]
	var is_safe: bool = room["kind"] == "safe"

	# floor
	add_child(_solid(Vector3(s.x, WALL_T, s.y), c + Vector3(0, -WALL_T * 0.5, 0), pal["floor"],
			0.0, false, s))
	# four walls with a doorway gap on each side (corridors punch through)
	var hx := s.x * 0.5
	var hz := s.y * 0.5
	var door := 3.0
	_wall_run(c + Vector3(0, WALL_H * 0.5, -hz), Vector3(s.x, WALL_H, WALL_T), door, true)
	_wall_run(c + Vector3(0, WALL_H * 0.5, hz), Vector3(s.x, WALL_H, WALL_T), door, true)
	_wall_run(c + Vector3(-hx, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, s.y), door, false)
	_wall_run(c + Vector3(hx, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, s.y), door, false)

	# lighting: warm amber in safe zones, cool accent elsewhere
	var light := OmniLight3D.new()
	light.position = c + Vector3(0, WALL_H - 0.5, 0)
	light.omni_range = s.x * 1.4
	light.light_energy = 1.6 if is_safe else 1.1
	light.light_color = pal["safe"] if is_safe else pal["accent"]
	light.shadow_enabled = true
	add_child(light)

	_decorate_room(c, s)

	# a glowing ceiling trim strip (door-strip aesthetic)
	var strip := Forge.slab(Vector3(s.x * 0.8, 0.15, 0.3), pal["accent"], 2.5)
	strip.position = c + Vector3(0, WALL_H - 0.2, hz - 0.6)
	add_child(strip)

	# platforms
	for p in room["platforms"]:
		add_child(_solid(p["size"], p["pos"], pal["trim"], 0.0, false, Vector2.ZERO))

	# props
	for pr in room["props"]:
		_place_prop(pr["name"], pr["pos"])

	# hazards
	for hz2 in room["hazards"]:
		_place_hazard(hz2["type"], hz2["pos"])

	# enemies
	for en in room["enemies"]:
		_place_enemy(en["type"], en["pos"])

## Wall dressing: vent panels, light strips and a conduit run. Everything sits
## just proud of the wall surface so it reads as mounted rather than sunk, and
## stays clear of the central doorway gap each wall leaves for its corridor.
func _decorate_room(c: Vector3, s: Vector2) -> void:
	var hx := s.x * 0.5
	var hz := s.y * 0.5
	for side in 4:
		var along_x: bool = side < 2                 # this wall runs along X
		var sgn: float = 1.0 if side % 2 == 0 else -1.0
		var run: float = hx if along_x else hz       # half-length of the wall
		var out: float = (hz if along_x else hx) - WALL_T * 0.5
		for i in 2:
			# 2.4 m clear of centre keeps fixtures off the 3 m doorway
			var t: float = Util.rf(2.4, maxf(2.6, run - 1.0))
			if Util.chance(0.5):
				t = -t
			_wall_fixture(c, t, out * sgn, along_x)

	# one conduit running the length of a random wall, up near the ceiling
	var cx: bool = Util.chance(0.5)
	var cs: float = 1.0 if Util.chance(0.5) else -1.0
	var length: float = (s.x if cx else s.y) - 1.2
	var pipe := Forge.pillar(0.09, length, pal.get("trim", Color("5a5560")))
	pipe.rotation = Vector3(0, 0, PI * 0.5) if cx else Vector3(PI * 0.5, 0, 0)
	var cout: float = ((hz if cx else hx) - WALL_T * 0.5 - 0.18) * cs
	pipe.position = c + (Vector3(0, WALL_H - 0.85, cout) if cx else Vector3(cout, WALL_H - 0.85, 0))
	add_child(pipe)

## One mounted fixture on a wall: either a dark vent panel or a small emissive
## strip light. `out` is the signed distance to the wall surface; `along_x` says
## which axis the wall runs along, so the panel is flattened against it.
func _wall_fixture(c: Vector3, t: float, out: float, along_x: bool) -> void:
	var lit := Util.chance(0.45)
	var w: float = Util.rf(0.5, 0.7) if lit else Util.rf(0.8, 1.3)
	var h: float = 0.14 if lit else Util.rf(0.6, 0.9)
	var y: float = Util.rf(2.6, 3.6) if lit else Util.rf(1.1, 2.2)
	var thick := 0.09
	var size := Vector3(w, h, thick) if along_x else Vector3(thick, h, w)
	var col: Color = pal.get("accent", Color("2a9df4")) if lit else pal.get("trim", Color("5a5560")).darkened(0.62)
	var mi := Forge.slab(size, col, 2.2 if lit else 0.0)
	# nudged inwards by half its own thickness so it touches, not intersects
	var push: float = out - signf(out) * thick * 0.5
	mi.position = c + (Vector3(t, y, push) if along_x else Vector3(push, y, t))
	add_child(mi)
	if lit:
		return
	# a flat dark rectangle reads as nothing; a lit slit makes it a panel
	var slit_w := w * 0.55
	var slit := Forge.slab(
			Vector3(slit_w, 0.05, thick) if along_x else Vector3(thick, 0.05, slit_w),
			pal.get("accent", Color("2a9df4")), 1.4)
	var sp: float = push - signf(out) * 0.01
	slit.position = c + (Vector3(t, y - h * 0.28, sp) if along_x else Vector3(sp, y - h * 0.28, t))
	add_child(slit)

func _wall_run(center: Vector3, size: Vector3, door_gap: float, along_x: bool) -> void:
	# Split a wall into two segments leaving a central doorway gap.
	if along_x:
		var seg := (size.x - door_gap) * 0.5
		if seg <= 0.1:
			add_child(_solid(size, center, pal["wall"], 0.0, true))
			return
		var off := (door_gap + seg) * 0.5
		add_child(_solid(Vector3(seg, size.y, size.z), center + Vector3(-off, 0, 0), pal["wall"], 0.0, true))
		add_child(_solid(Vector3(seg, size.y, size.z), center + Vector3(off, 0, 0), pal["wall"], 0.0, true))
	else:
		var seg2 := (size.z - door_gap) * 0.5
		if seg2 <= 0.1:
			add_child(_solid(size, center, pal["wall"], 0.0, true))
			return
		var off2 := (door_gap + seg2) * 0.5
		add_child(_solid(Vector3(size.x, size.y, seg2), center + Vector3(0, 0, -off2), pal["wall"], 0.0, true))
		add_child(_solid(Vector3(size.x, size.y, seg2), center + Vector3(0, 0, off2), pal["wall"], 0.0, true))

func _build_corridors() -> void:
	# connect each room to the next in the generated path with a floor strip
	for i in range(gen.rooms.size() - 1):
		var a: Vector3 = gen.rooms[i]["center"]
		var b: Vector3 = gen.rooms[i + 1]["center"]
		var mid := (a + b) * 0.5
		var span := b - a
		var size := Vector3(maxf(absf(span.x), 3.0), WALL_T, maxf(absf(span.z), 3.0))
		add_child(_solid(size, mid + Vector3(0, -WALL_T * 0.5, 0), pal["trim"], 0.0, false, Vector2.ZERO))

func _place_prop(name: String, pos: Vector3) -> void:
	var node := Forge.model(name)
	node.position = pos
	add_child(node)
	if name in ["tech_node", "blueprint", "health_cell"]:
		interactables.append({"pos": pos, "kind": "pickup", "name": name})
	elif name in ["magnet_ring", "vine_ribbon", "laser_emitter", "anchor_beacon", "reality_switch"]:
		interactables.append({"pos": pos, "kind": "gate", "name": name})

func _place_hazard(type: String, pos: Vector3) -> void:
	var h := Hazard.new()
	h.setup(type, pal)
	h.position = pos
	add_child(h)
	hazards.append(h)

func _place_enemy(type: String, pos: Vector3) -> void:
	var e := Enemy.new()
	e.setup(type, pal)
	e.position = pos + Vector3(0, 0.1, 0)
	add_child(e)
	enemies.append(e)

func _spawn_boss() -> void:
	if gen.boss_type == "":
		return
	if gen.boss_type == "nexus":
		var b := Boss.new()
		b.setup(pal)
		b.position = gen.boss_pos
		add_child(b)
		boss = b
	elif gen.boss_type == "core_guardian":
		var g := Guardian.new()
		g.setup(pal)
		g.position = gen.boss_pos
		add_child(g)
		boss = g
	else:
		var e := Enemy.new()
		e.setup(gen.boss_type, pal)
		e.position = gen.boss_pos
		add_child(e)
		enemies.append(e)
		boss = e

func _spawn_echoes() -> void:
	for e in Meta.echoes_for(gen.sector):
		var p: Array = e.get("pos", [0, 0, 0])
		var pos := Vector3(p[0], p[1], p[2])
		var debris := Forge.model("echo_debris")
		debris.position = pos
		add_child(debris)
		interactables.append({"pos": pos, "kind": "echo", "name": String(e.get("note", ""))})

## Reality Bender gate: rewrite the room. Deletes the nearest hazard (opening a
## path) and briefly flips a stretch of geometry to the negative-space "glitch"
## material as feedback. Returns true if anything changed.
func rewrite(from: Vector3) -> bool:
	# Near NEXUS, a rewrite strips its active attack pattern (opens the core).
	if boss != null and is_instance_valid(boss) and boss.has_method("strip_pattern"):
		if boss.global_position.distance_to(from) < 12.0:
			if boss.strip_pattern():
				return true
	# Otherwise, delete the nearest hazard to open a path.
	var nearest: Hazard = null
	var best := 8.0
	for h in hazards:
		if is_instance_valid(h):
			var d: float = h.global_position.distance_to(from)
			if d < best:
				best = d
				nearest = h
	if nearest:
		hazards.erase(nearest)
		nearest.queue_free()
		return true
	return false

## A visual box + matching static collision. Walls wear the generated wall
## surface; in sector 4 some of them wear the animated reality-break shader
## instead. Floors and platforms keep the flat palette material.
func _solid(size: Vector3, pos: Vector3, color: Color, emit: float = 0.0, glitchable: bool = false,
		deck: Vector2 = Vector2(-1, -1)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := Forge.slab(size, color, emit)
	if glitchable and _glitch and Util.chance(0.45):
		mi.material_override = Forge.glitch_shader_mat()
	elif glitchable:
		mi.material_override = Forge.wall_shader_mat(pal)
	elif deck.x >= 0.0:
		mi.material_override = Forge.floor_shader_mat(pal, deck)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body
