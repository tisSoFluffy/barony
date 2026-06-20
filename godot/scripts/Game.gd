extends Node3D
class_name Game
## Orchestrates a run: generate the floor, build the 3D world, populate it with
## billboard actors/items, and spawn the first-person player. Combat/AI/descent
## land in the next milestone; this gives a walkable, populated dungeon.

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
var depth := 1
var run_seed := ""

func start(cls: String, seed_str := "", start_depth := 1) -> void:
	run_seed = seed_str
	depth = start_depth
	Util.seed_floor(run_seed, depth)
	var lv := Dungeon.generate(depth)

	world = World.new()
	add_child(world)
	world.build(lv)

	# enemies as billboards (static for now; AI is the next milestone)
	for e in lv.enemies:
		var def: Dictionary = Bestiary.get_def(e.type)
		if def.is_empty():
			continue
		var h: float = float(def.scale) * 1.9
		world.add_child(world.make_billboard(def.spr, Vector3(e.pos.x, 0, e.pos.y), h))

	# items / props as billboards (torches are lights, handled in World)
	for it in lv.items:
		if it.type == "torch":
			continue
		var spr: String = ITEM_SPR.get(it.type, "")
		if spr == "":
			continue
		world.add_child(world.make_billboard(spr, Vector3(it.pos.x, 0, it.pos.y), ITEM_H.get(it.type, 0.5)))

	# ambient: dim, torches provide the warmth
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Art.ceil_color(lv.theme)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.30, 0.36)
	e.ambient_light_energy = 0.35
	env.environment = e
	add_child(env)

	player = Player.new()
	player.cls = cls
	add_child(player)
	player.position = Vector3(lv.start.x, 1.0, lv.start.y)

	print("Game started as %s — depth %d, %d enemies, %d items, theme '%s'" % [
		cls, depth, lv.enemies.size(), lv.items.size(), World.WALL_H])
