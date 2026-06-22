extends RefCounted
class_name Dungeon
## Pure-logic procedural dungeon generator, ported from the web build's genLevel().
## All randomness routes through Util.* (seeded) so floors are reproducible.

const MS := 72

static func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < MS and y >= 0 and y < MS

static func _tile(tiles: PackedByteArray, x: int, y: int) -> int:
	var ix := int(floor(x)); var iy := int(floor(y))
	if not _in_bounds(ix, iy):
		return 0
	return tiles[iy * MS + ix]

static func _set_tile(tiles: PackedByteArray, x: int, y: int, v: int) -> void:
	var ix := int(floor(x)); var iy := int(floor(y))
	if not _in_bounds(ix, iy):
		return
	tiles[iy * MS + ix] = v

static func _solid(tiles: PackedByteArray, x: int, y: int) -> bool:
	return _tile(tiles, x, y) > 0

static func dist2(ax: float, ay: float, bx: float, by: float) -> float:
	var dx := ax - bx; var dy := ay - by
	return dx * dx + dy * dy

static func generate(depth: int) -> Dictionary:
	var tiles := PackedByteArray()
	tiles.resize(MS * MS)
	for i in range(MS * MS):
		tiles[i] = 1

	var rooms: Array = []
	var enemies: Array = []
	var items: Array = []

	# carve rooms — larger chambers for DS feel
	var attempts := 0
	while attempts < 200 and rooms.size() < 14:
		attempts += 1
		var w := Util.ri(8, 18)
		var h := Util.ri(8, 18)
		var x := Util.ri(3, MS - w - 4)
		var y := Util.ri(3, MS - h - 4)
		var ok := true
		for r in rooms:
			if x < r.x + r.w + 3 and x + w + 3 > r.x and y < r.y + r.h + 3 and y + h + 3 > r.y:
				ok = false
				break
		if not ok:
			continue
		rooms.append({ "x": x, "y": y, "w": w, "h": h, "cx": x + w / 2.0, "cy": y + h / 2.0 })
		for yy in range(y, y + h):
			for xx in range(x, x + w):
				_set_tile(tiles, xx, yy, 0)

	# corridors — 2 tiles wide for DS hallway feel
	for i in range(1, rooms.size()):
		var ax := int(rooms[i - 1].cx)
		var ay := int(rooms[i - 1].cy)
		var bx := int(rooms[i].cx)
		var by := int(rooms[i].cy)
		while ax != bx:
			_set_tile(tiles, ax, ay, 0)
			_set_tile(tiles, ax, ay + 1, 0)
			ax += 1 if ax < bx else -1
		while ay != by:
			_set_tile(tiles, ax, ay, 0)
			_set_tile(tiles, ax + 1, ay, 0)
			ay += 1 if ay < by else -1
		_set_tile(tiles, ax, ay, 0)
		_set_tile(tiles, ax + 1, ay, 0)

	# wall variety
	for i in range(MS * MS):
		if tiles[i] == 1:
			var r := Util.rf(0.0, 1.0)
			tiles[i] = 2 if r < 0.14 else (3 if r < 0.19 else 1)

	# doors at corridor pinch points
	for y in range(1, MS - 1):
		for x in range(1, MS - 1):
			if _tile(tiles, x, y) != 0:
				continue
			var hp := _solid(tiles, x - 1, y) and _solid(tiles, x + 1, y) and not _solid(tiles, x, y - 1) and not _solid(tiles, x, y + 1)
			var vp := _solid(tiles, x, y - 1) and _solid(tiles, x, y + 1) and not _solid(tiles, x - 1, y) and not _solid(tiles, x + 1, y)
			if (hp or vp) and Util.chance(0.4):
				_set_tile(tiles, x, y, 8)

	var r0: Dictionary = rooms[0]
	var start := Vector2(r0.cx, r0.cy)

	var rl: Dictionary = rooms[rooms.size() - 1]
	var boss := false
	var stairs = null
	if depth < 5:
		stairs = Vector2(rl.cx, rl.cy)
		items.append({ "type": "stairs", "pos": Vector2(rl.cx, rl.cy) })
	else:
		boss = true
		enemies.append({ "type": "ogre", "pos": Vector2(rl.cx, rl.cy), "has_key": false })

	# enemies
	var sp: Dictionary = Bestiary.spawn_table(depth)
	var pool: Array = sp.pool
	var n: int = sp.n
	for i in range(n):
		var r: Dictionary = rooms[Util.ri(1, rooms.size() - 1)]
		var ex: float = Util.rf(r.x + 0.8, r.x + r.w - 0.8)
		var ey: float = Util.rf(r.y + 0.8, r.y + r.h - 0.8)
		if dist2(ex, ey, start.x, start.y) < 100.0:
			continue
		enemies.append({ "type": Util.weighted(pool), "pos": Vector2(ex, ey), "has_key": false })

	# scattered loot
	var loot_n := Util.ri(5, 8)
	for i in range(loot_n):
		var r: Dictionary = rooms[Util.ri(0, rooms.size() - 1)]
		var lx := Util.rf(r.x + 0.6, r.x + r.w - 0.6)
		var ly := Util.rf(r.y + 0.6, r.y + r.h - 0.6)
		var roll := Util.rf(0.0, 1.0)
		var ltype := "meat" if roll < 0.3 else ("hpot" if roll < 0.5 else ("mpot" if roll < 0.62 else "gold"))
		items.append({ "type": ltype, "pos": Vector2(lx, ly), "amt": Util.ri(6, 14) * depth })

	# guaranteed gear
	var rg: Dictionary = rooms[Util.ri(1, rooms.size() - 1)]
	items.append({ "type": "gear", "pos": Vector2(rg.cx + 0.5, rg.cy - 0.5), "amt": 0 })

	# braziers light the rooms
	for r in rooms:
		if Util.chance(0.8):
			items.append({ "type": "torch", "pos": Vector2(r.x + 0.55, r.y + 0.55) })

	# spike traps (depth 2+)
	if depth >= 2:
		for i in range(2 + depth):
			var r: Dictionary = rooms[Util.ri(1, rooms.size() - 1)]
			var tx := Util.rf(r.x + 0.8, r.x + r.w - 0.8)
			var ty := Util.rf(r.y + 0.8, r.y + r.h - 0.8)
			if dist2(tx, ty, start.x, start.y) > 16.0:
				items.append({ "type": "trap", "pos": Vector2(tx, ty) })

	# blessing shrine, sometimes
	if Util.chance(0.6) and rooms.size() > 3:
		var r: Dictionary = rooms[Util.ri(1, rooms.size() - 2)]
		items.append({ "type": "shrine", "pos": Vector2(r.cx - 0.6, r.cy + 0.6), "amt": 0 })

	# locked treasure vault (depth 2+)
	if depth >= 2 and rooms.size() >= 5 and enemies.size() > 0:
		var v: Dictionary = rooms[Util.ri(1, rooms.size() - 2)]
		var sealed := 0
		for x in range(v.x - 1, v.x + v.w + 1):
			for y in range(v.y - 1, v.y + v.h + 1):
				var on_ring: bool = (x == v.x - 1 or x == v.x + v.w or y == v.y - 1 or y == v.y + v.h)
				if on_ring and _in_bounds(x, y):
					var t := _tile(tiles, x, y)
					if t == 0 or t == 8:
						_set_tile(tiles, x, y, 9)
						sealed += 1
		if sealed > 0:
			items.append({ "type": "gear", "pos": Vector2(v.cx - 0.5, v.cy), "amt": 0 })
			items.append({ "type": "gear", "pos": Vector2(v.cx + 0.5, v.cy), "amt": 0 })
			items.append({ "type": "gold", "pos": Vector2(v.cx, v.cy + 0.7), "amt": Util.ri(20, 40) * depth })
			items.append({ "type": "hpot", "pos": Vector2(v.cx, v.cy - 0.7) })
			var carrier: Dictionary = enemies[Util.ri(0, enemies.size() - 1)]
			if carrier.type != "ogre":
				carrier.has_key = true
			elif enemies.size() > 1:
				enemies[0].has_key = true

	# Gazlowe the goblin merchant (every floor but the throne)
	if depth < 5 and rooms.size() > 2:
		var r: Dictionary = rooms[Util.ri(1, rooms.size() - 2)]
		items.append({ "type": "shop", "pos": Vector2(r.cx + 0.4, r.cy) })

	return {
		"w": MS, "h": MS, "tiles": tiles, "rooms": rooms,
		"start": start, "stairs": stairs, "boss": boss,
		"enemies": enemies, "items": items, "theme": min(depth, 5),
	}
