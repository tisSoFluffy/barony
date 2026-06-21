extends Node3D
class_name Game
## Orchestrates a run: generate the floor, build the 3D world, spawn AI enemies
## and item billboards, the first-person player, and the HUD. Also the shared
## combat helpers (projectiles, AoE, wall/LOS queries, XP) used by Player/Enemy.

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

var world: World
var player: Player
var hud: HUD
var level: Dictionary
var depth := 1
var run_seed := ""

func _ready() -> void:
	instance = self

func start(cls: String, seed_str := "", start_depth := 1) -> void:
	run_seed = seed_str
	depth = start_depth
	Util.seed_floor(run_seed, depth)
	level = Dungeon.generate(depth)

	world = World.new()
	add_child(world)
	world.build(level)

	for e in level.enemies:
		var def: Dictionary = Bestiary.get_def(e.type)
		if def.is_empty():
			continue
		var en := Enemy.new()
		add_child(en)
		en.setup(e.type, Vector3(e.pos.x, 0, e.pos.y))

	for it in level.items:
		if it.type == "torch":
			continue
		var spr: String = ITEM_SPR.get(it.type, "")
		if spr == "":
			continue
		world.add_child(world.make_billboard(spr, Vector3(it.pos.x, 0, it.pos.y), ITEM_H.get(it.type, 0.5)))

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Art.ceil_color(level.theme)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.34, 0.32, 0.38)
	e.ambient_light_energy = 0.4
	env.environment = e
	add_child(env)

	player = Player.new()
	player.cls = cls
	add_child(player)
	player.position = Vector3(level.start.x, 1.0, level.start.y)

	hud = HUD.new()
	hud.player = player
	add_child(hud)

	hud.message("You enter the fallen barony. Depth %d." % depth, Color("ffce42"))
	print("Game started as %s — depth %d, %d enemies, %d items" % [cls, depth, level.enemies.size(), level.items.size()])

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
		var t := float(i) / steps
		if is_wall(a.lerp(b, t)):
			return false
	return true

func spawn_projectile(team: String, from: Vector3, dir: Vector3, kind: String, dmg: int, owner: Player) -> void:
	var pr := Projectile.new()
	pr.team = team
	pr.kind = kind
	pr.dmg = dmg
	pr.dir = dir.normalized()
	pr.owner_player = owner
	var d: Dictionary = Classes.proj.get(kind, {})
	pr.speed = d.get("speed", 9.0)
	pr.pierce = int(d.get("pierce", 0))
	pr.life = d.get("life", 0.0)
	add_child(pr)
	pr.global_position = from

func do_aoe(center: Vector3, radius: float, dmg: int, slow: float, col: Color) -> void:
	for en in get_tree().get_nodes_in_group("enemy"):
		if center.distance_to(en.global_position) <= radius:
			en.take_damage(dmg + Util.li(0, 4), col)
			if slow > 0.0:
				en.slow_t = slow
	if world:
		# a quick ring of motes
		for i in range(20):
			var a := TAU * i / 20.0
			world.spawn_spark(center + Vector3(cos(a), 0.3, sin(a)) * 0.5, col)

func on_enemy_killed(xp: int, ename: String) -> void:
	if player and is_instance_valid(player):
		player.gain_xp(xp)
	if hud:
		hud.message("%s dies!" % ename, Color("9ad870"))
