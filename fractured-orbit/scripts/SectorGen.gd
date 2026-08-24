class_name SectorGen
extends RefCounted
## The "Procedural Glitch": roguelike room content inside a metroidvania spine.
##
## The SKELETON is fixed so the player always knows what they are looking for —
## a safe entrance, a run of rooms, the gate-challenge room that houses this
## sector's traversal power, and an exit lifted out of reach so you must USE the
## gate to leave. The CONTENT of each room (props, hazards, enemies, extra
## platforms) is randomized per run, and gets denser/harder the more times the
## loop has reset (run_index) — that's Act II's "hostile generation".
##
## Fully deterministic from (run_seed, sector, run_index) via Util.seed_sector,
## so a given loop is reproducible and headless-testable.

const CELL := 16.0     # world spacing between room centers (metres)
const ROOM := 12.0     # room floor half-not; full room is ROOM x ROOM

var sector: int = 0
var def: Dictionary = {}
var rooms: Array = []
var spawn := Vector3.ZERO
var gate_pos := Vector3.ZERO
var exit_pos := Vector3.ZERO
var gate_id := ""

func generate(sector_id: int, run_seed: String, run_index: int) -> void:
	sector = sector_id
	def = Sectors.get_def(sector_id)
	gate_id = String(def["gate"])
	Util.seed_sector(run_seed, sector_id, run_index)

	var diff := difficulty(run_index)
	var count: int = clampi(int(def["rooms"].x) + int(diff), int(def["rooms"].x), int(def["rooms"].y))
	rooms.clear()

	# Skeleton: a mostly-linear path with occasional side branches, walked on a
	# grid so corridors are axis-aligned (brutalist right angles).
	var cell := Vector2i(0, 0)
	var used := {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for i in count:
		var kind := "combat"
		if i == 0:
			kind = "safe"          # entrance safe zone (fixed)
		elif i == count - 2:
			kind = "gate"          # houses the traversal power (fixed)
		elif i == count - 1:
			kind = "exit"          # lifted exit (fixed)
		used[cell] = true
		rooms.append(_make_room(cell, kind, diff))
		# step to a fresh adjacent cell for the next room
		if i < count - 1:
			var next := cell
			var tries := 0
			while tries < 12:
				var d: Vector2i = Util.pick(dirs)
				var cand: Vector2i = cell + d
				if not used.has(cand):
					next = cand
					break
				tries += 1
			cell = next

	spawn = rooms[0]["center"] + Vector3(0, 1.0, 0)
	gate_pos = rooms[count - 2]["gate_anchor"]
	exit_pos = rooms[count - 1]["exit_anchor"]

## How much harder this loop is. Grows with run_index but saturates so late
## runs stay hard rather than impossible.
static func difficulty(run_index: int) -> float:
	return clampf(float(run_index) * 0.5, 0.0, 5.0)

func _make_room(cell: Vector2i, kind: String, diff: float) -> Dictionary:
	var center := Vector3(cell.x * CELL, 0.0, cell.y * CELL)
	var r := {
		"cell": cell, "center": center, "kind": kind,
		"size": Vector2(ROOM, ROOM),
		"props": [], "hazards": [], "enemies": [], "platforms": [],
		"gate_anchor": center, "exit_anchor": center,
	}
	match kind:
		"safe":
			# warm, empty, a Tech Node lore pickup near the entrance
			r["props"].append({"name": "tech_node", "pos": center + Vector3(2, 0, 2)})
		"combat":
			_populate_combat(r, center, diff)
		"gate":
			_populate_gate(r, center, diff)
		"exit":
			# exit lifted so the gate ability is required to reach it
			var h := lerpf(3.0, 7.0, float(def["vertical"]))
			r["exit_anchor"] = center + Vector3(0, h, 0)
			r["platforms"].append({"pos": center + Vector3(0, h - 0.5, 0), "size": Vector3(4, 0.5, 4)})
	return r

func _populate_combat(r: Dictionary, center: Vector3, diff: float) -> void:
	var enemy_pool: Array = def["enemies"]
	var hazard_pool: Array = def["hazards"]
	# more enemies + hazards on later loops; roughly 1..3 baseline
	var n_enemies: int = 1 + int(diff)
	for i in n_enemies:
		var pos := center + Vector3(Util.rf(-4, 4), 0, Util.rf(-4, 4))
		r["enemies"].append({"type": Util.pick(enemy_pool), "pos": pos})
	var n_hazards: int = 1 + int(diff * 0.6)
	for i in n_hazards:
		var pos := center + Vector3(Util.rf(-4, 4), 0, Util.rf(-4, 4))
		r["hazards"].append({"type": Util.pick(hazard_pool), "pos": pos})
	# a couple of cover props
	for i in Util.ri(1, 3):
		var pos := center + Vector3(Util.rf(-5, 5), 0, Util.rf(-5, 5))
		r["props"].append({"name": "cargo_crate", "pos": pos})
	# high-run twist: multi-platform obstacle courses appear
	if diff >= 2.0 and Util.chance(0.6):
		for i in Util.ri(2, 4):
			var pos := center + Vector3(Util.rf(-4, 4), Util.rf(1.5, 4.0), Util.rf(-4, 4))
			r["platforms"].append({"pos": pos, "size": Vector3(2.5, 0.4, 2.5)})

func _populate_gate(r: Dictionary, center: Vector3, diff: float) -> void:
	# The gate challenge: the traversal power sits atop a vertical obstacle only
	# beatable once you HAVE the power (or, first time, the pickup itself).
	var h := lerpf(3.5, 6.0, float(def["vertical"]))
	r["gate_anchor"] = center + Vector3(0, h, 0)
	# the gate prop (magnet ring / vine ribbon / anchor beacon / etc.)
	r["props"].append({"name": _gate_prop(), "pos": center + Vector3(0, h - 0.5, 0)})
	# stepped platforms leading up (harder gaps at higher difficulty)
	var steps := 3 + int(diff * 0.4)
	for i in steps:
		var t := float(i + 1) / float(steps + 1)
		var jitter: float = Util.rf(-2.0, 2.0) * (1.0 + diff * 0.2)
		r["platforms"].append({
			"pos": center + Vector3(jitter, t * h, jitter * 0.5),
			"size": Vector3(2.5, 0.4, 2.5),
		})
	# a guardian or two at the top on later loops
	if diff >= 1.0:
		r["enemies"].append({"type": Util.pick(def["enemies"]), "pos": r["gate_anchor"] + Vector3(1, 0, 0)})

func _gate_prop() -> String:
	match gate_id:
		"magnet_boots": return "magnet_ring"
		"wall_run": return "vine_ribbon"
		"kinetic_charge": return "laser_emitter"
		"zero_g_anchor": return "anchor_beacon"
		"reality_bender": return "reality_switch"
	return "tech_node"
