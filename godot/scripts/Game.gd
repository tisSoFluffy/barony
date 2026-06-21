extends Node3D
class_name Game
## Orchestrates a run: build floors, spawn AI enemies + item pickups, the player,
## the HUD and the inventory/shop UIs; pickups, interaction (E), descent, the
## boss portal, blessings, win/lose. Also the shared combat helpers.

static var instance: Game

const ITEM_SPR := {
	"hpot": "hpot", "mpot": "mpot", "meat": "meat", "gold": "gold",
	"gear": "sword", "stairs": "stairs", "portal": "portal",
	"shrine": "shrine", "trap": "trap", "key": "key", "shop": "shop",
}
const ITEM_H := {
	"hpot": 0.5, "mpot": 0.5, "meat": 0.45, "gold": 0.4, "gear": 0.55,
	"stairs": 1.0, "portal": 1.8, "shrine": 1.1, "trap": 0.3, "key": 0.45, "shop": 1.6,
}
const PICKABLE := {"gold": true, "hpot": true, "mpot": true, "meat": true, "gear": true, "key": true}

var world: World
var player: Player
var hud: HUD
var inv_ui: InventoryUI
var shop_ui: ShopUI
var floor_root: Node3D
var level: Dictionary
var items: Array = []     # [{type,amt,gear,pos,node,used}]
var depth := 1
var run_seed := ""
var ended := false

func _ready() -> void:
	instance = self

func start(cls: String, seed_str := "", start_depth := 1) -> void:
	run_seed = seed_str
	depth = start_depth
	player = Player.new()
	player.cls = cls
	add_child(player)
	hud = HUD.new(); hud.player = player; add_child(hud)
	inv_ui = InventoryUI.new(); add_child(inv_ui)
	shop_ui = ShopUI.new(); add_child(shop_ui)
	_build_floor(true)

func _build_floor(first: bool) -> void:
	if floor_root and is_instance_valid(floor_root):
		floor_root.queue_free()
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	items.clear()
	floor_root = Node3D.new()
	add_child(floor_root)

	Util.seed_floor(run_seed, depth)
	level = Dungeon.generate(depth)

	world = World.new()
	floor_root.add_child(world)
	world.build(level)

	for e in level.enemies:
		var def: Dictionary = Bestiary.get_def(e.type)
		if def.is_empty():
			continue
		var en := Enemy.new()
		floor_root.add_child(en)
		en.has_key = e.get("has_key", false)
		en.setup(e.type, Vector3(e.pos.x, 0, e.pos.y))

	for it in level.items:
		if it.type == "torch":
			continue
		var spr: String = ITEM_SPR.get(it.type, "")
		if spr == "":
			continue
		var gear = null
		if it.type == "gear":
			gear = GearDB.roll_gear(depth)
		var node := world.make_billboard(spr, Vector3(it.pos.x, 0, it.pos.y), ITEM_H.get(it.type, 0.5))
		world.add_child(node)
		items.append({"type": it.type, "amt": int(it.get("amt", 0)), "gear": gear,
			"pos": Vector3(it.pos.x, 0, it.pos.y), "node": node, "used": false})

	var env := WorldEnvironment.new()
	var e2 := Environment.new()
	e2.background_mode = Environment.BG_COLOR
	e2.background_color = Art.ceil_color(level.theme)
	e2.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e2.ambient_light_color = Color(0.34, 0.32, 0.38)
	e2.ambient_light_energy = 0.4
	floor_root.add_child(env)
	env.environment = e2

	player.global_position = Vector3(level.start.x, 1.0, level.start.y)
	hud.message("You enter depth %d." % depth, Color("ffce42"))
	if depth == 5:
		hud.message("The air reeks of ogre. Gor'maul is near.", Color("ff7050"))

func _process(_dt: float) -> void:
	if ended or player == null or not is_instance_valid(player):
		return
	if Input.is_action_just_pressed("inventory"):
		if shop_ui.is_open: shop_ui.close()
		else: inv_ui.toggle(player)
	if Input.is_action_just_pressed("use_action"):
		_use_action()
	if not (inv_ui.is_open or shop_ui.is_open) and not player.dead:
		_check_pickups()

func _hdist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _check_pickups() -> void:
	for i in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		if not PICKABLE.has(it.type):
			continue
		if _hdist(player.global_position, it.pos) < 0.9:
			if it.type == "gear" and player.bag.size() >= 6:
				continue
			player.grant(it.type, it.amt, it.gear)
			if is_instance_valid(it.node): it.node.queue_free()
			items.remove_at(i)

func _use_action() -> void:
	if shop_ui.is_open:
		shop_ui.close(); return
	if inv_ui.is_open:
		inv_ui.close(); return
	for it in items:
		var near: bool = _hdist(player.global_position, it.pos) < 2.2
		if not near:
			continue
		match it.type:
			"shop": shop_ui.open(player); return
			"stairs": descend(); return
			"portal": do_win(); return
			"shrine":
				if not it.used:
					it.used = true
					do_blessing()
				else:
					hud.message("The shrine is spent.", Color("9a8a64"))
				return

func descend() -> void:
	if depth >= 5:
		return
	depth += 1
	_build_floor(false)

func do_blessing() -> void:
	match Util.li(1, 5):
		1: player.hp = player.tot_maxhp(); hud.flash(Color(0.3, 0.8, 0.35, 0.25)); hud.message("The Light mends your every wound!", Color("9ad870"))
		2: player.maxhp += 12; player.hp += 12; hud.message("You feel hardier! (+12 max health)", Color("9ad870"))
		3: player.maxmana += 10; player.mana = player.tot_maxmana(); hud.message("Arcane power floods you! (+10 max mana)", Color("8ab8ff"))
		4: player.take_damage(12, "an angry spirit"); hud.message("The spirit demands tribute!", Color("ff5040"))
		5: player.gold += 25 * depth; hud.message("The shrine showers you in gold!", Color("ffd84a"))

func spawn_drop(kind: String, pos: Vector3) -> void:
	var spr: String = ITEM_SPR.get(kind, "")
	if spr == "":
		return
	var node := world.make_billboard(spr, Vector3(pos.x, 0, pos.z), ITEM_H.get(kind, 0.5))
	world.add_child(node)
	items.append({"type": kind, "amt": 0, "gear": null, "pos": Vector3(pos.x, 0, pos.z), "node": node, "used": false})

func spawn_portal(pos: Vector3) -> void:
	var node := world.make_billboard("portal", Vector3(pos.x, 0, pos.z), ITEM_H["portal"])
	world.add_child(node)
	items.append({"type": "portal", "amt": 0, "gear": null, "pos": Vector3(pos.x, 0, pos.z), "node": node, "used": false})
	hud.message("GOR'MAUL FALLS! A portal home tears open — press E.", Color("62d8ff"))

func do_win() -> void:
	if ended: return
	ended = true
	_record(true)
	hud.show_win("%s of level %d — you slew Gor'maul and took back the barony! For the Alliance!" % [player.def.name, player.level])

func on_player_death(src: String) -> void:
	if ended: return
	ended = true
	_record(false)

func _record(win: bool) -> void:
	Scores.record({
		"name": player.def.name, "cls": player.cls, "depth": depth, "level": player.level,
		"gold": player.gold, "kills": player.kills, "win": win, "seed": run_seed})

# ---- shared combat helpers ----
func is_wall(world_pos: Vector3) -> bool:
	var x := int(floor(world_pos.x))
	var y := int(floor(world_pos.z))
	if x < 0 or y < 0 or x >= level.w or y >= level.h:
		return true
	return level.tiles[y * level.w + x] > 0

func has_los(a: Vector3, b: Vector3) -> bool:
	var d := a.distance_to(b)
	var steps := int(ceil(d / 0.25))
	for i in range(1, steps):
		if is_wall(a.lerp(b, float(i) / steps)):
			return false
	return true

func spawn_projectile(team: String, from: Vector3, dir: Vector3, kind: String, dmg: int, owner: Player) -> void:
	var pr := Projectile.new()
	pr.team = team; pr.kind = kind; pr.dmg = dmg; pr.dir = dir.normalized(); pr.owner_player = owner
	var d: Dictionary = Classes.proj.get(kind, {})
	pr.speed = d.get("speed", 9.0)
	pr.pierce = int(d.get("pierce", 0))
	pr.life = d.get("life", 0.0)
	floor_root.add_child(pr)
	pr.global_position = from

func do_aoe(center: Vector3, radius: float, dmg: int, slow: float, col: Color) -> void:
	for en in get_tree().get_nodes_in_group("enemy"):
		if center.distance_to(en.global_position) <= radius:
			en.take_damage(dmg + Util.li(0, 4), col)
			if slow > 0.0:
				en.slow_t = slow
	if world:
		for i in range(18):
			var a := TAU * i / 18.0
			world.spawn_spark(center + Vector3(cos(a), 0.3, sin(a)) * 0.5, col)

func on_enemy_killed(xp: int, ename: String) -> void:
	if player and is_instance_valid(player):
		player.gain_xp(xp)
		player.kills += 1
	if hud:
		hud.message("%s dies!" % ename, Color("9ad870"))
