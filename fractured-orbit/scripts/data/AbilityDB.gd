extends Node
## The Metroidvania spine of Fractured Orbit.
##
## GATES are the five permanent, sector-locked traversal powers. Finding one is
## how a sector "opens" — and, because unlocks persist across runs (see Meta),
## a gate found in run 3 is usable from the start of run 4. Each gate also names
## the sector it lives in and the sector it unlocks passage toward.
##
## TECH are smaller carry-over upgrades from the Tech Tree: not required to
## finish, but they reshape hazards (a Spore Purifier turns a lethal cloud into
## harmless fog) and reward exploration of earlier sectors on later runs.
##
## Everything here is pure data. Player.gd reads `has()` (via Meta) to decide
## which moves resolve; SectorGen reads gate ids to place the correct locked
## traversal challenge.

## Gate ids, in the intended unlock order (also the sector order).
const GATE_ORDER := ["magnet_boots", "wall_run", "kinetic_charge", "zero_g_anchor", "reality_bender"]

var _gates := {
	"magnet_boots": {
		"name": "Magnet Boots",
		"glyph": "⬇",  # down arrow — pulled to the pole
		"sector": 0,        # found in Docking Bays
		"input": "gate_ability",
		"color": Color("d98a3a"),  # copper
		"verb": "Cling",
		"desc": "Latch onto magnetic pillars and ride the pull upward.",
		"why": "The magnetic pillars rising from the Docking Bay floor are the only way up to the next room's entrance.",
		"log": "Gravity stabilizers failing... we need to reach the Core before the ship implodes.",
	},
	"wall_run": {
		"name": "Wall-Run Climb",
		"glyph": "↗",  # up-right — running along a slope
		"sector": 1,        # Hydroponics
		"input": "gate_ability",
		"color": Color("3ad98a"),  # neon vine green
		"verb": "Run",
		"desc": "Sprint along a wall or living vine without falling — briefly defy gravity's pull sideways.",
		"why": "The plants grew a roof over Hydroponics; the only way up is to leap onto a vine and run its length.",
		"log": "The garden ate the stairwell. Climb the growth or stay below with the Silence.",
	},
	"kinetic_charge": {
		"name": "Kinetic Charge",
		"glyph": "⚡",  # bolt
		"sector": 2,        # Engineering Core
		"input": "attack",
		"color": Color("2a9df4"),  # electric blue
		"verb": "Charge Punch",
		"desc": "Ground your charge on metal, then shatter laser barricades with a kinetic strike.",
		"why": "Laser barricades in Engineering only break to a grounded kinetic punch — touch the metal floor first, then hit.",
		"log": "Don't trust the turrets. He died here.",
	},
	"zero_g_anchor": {
		"name": "Zero-G Anchor",
		"glyph": "⚓",  # anchor
		"sector": 3,        # Void Silo
		"input": "gate_ability",
		"color": Color("b06ad9"),  # void violet
		"verb": "Tether",
		"desc": "Fire a gravity tether to a surface and reel yourself across zero-G voids.",
		"why": "The Void Silo drops you into zero-G where you can't run; only tethers pull you across.",
		"log": "It isn't a cure. The Event Horizon is a trap. Join us, Loop-Walker.",
	},
	"reality_bender": {
		"name": "Reality Bender",
		"glyph": "↻",  # rewrite / cycle
		"sector": 4,        # Event Horizon
		"input": "gate_ability",
		"color": Color("f2f2f2"),  # negative-space white
		"verb": "Rewrite",
		"desc": "Swap a room's geometry: turn walls to floor, open doors, delete a hazard.",
		"why": "The Event Horizon flickers between layouts; rewrite the room to carve a path — and to strip the boss of an attack pattern.",
		"log": "You are the glitch. The world is trying to reject you. Rewrite it first.",
	},
}

## Optional carry-over upgrades from the Tech Tree. `unlocks` names a hazard or
## situation the upgrade neutralizes/enables so SectorGen and Hazard can react.
var _tech := {
	"gravity_manipulator": {
		"name": "Gravity Manipulator",
		"desc": "Flip local gravity on command — run on walls and ceilings.",
		"unlocks": "gravity_flip",
	},
	"warp_jump": {
		"name": "Warp Jump",
		"desc": "A short blink dash through the air; refunds on landing a gate move.",
		"unlocks": "extra_mobility",
	},
	"spore_purifier": {
		"name": "Spore Purifier",
		"desc": "Installed at a vent, converts Hydroponics spore clouds into harmless fog.",
		"unlocks": "clear_spores",
	},
	"hacking": {
		"name": "Hacking Spike",
		"desc": "Disable a turret or open a sealed data-door for a few seconds.",
		"unlocks": "disable_turret",
	},
	"time_dilation": {
		"name": "Time Dilation",
		"desc": "Slow enemy time in a bubble around you; your own time runs normal.",
		"unlocks": "slow_enemies",
	},
	"noise_canceller": {
		"name": "Noise Canceller",
		"desc": "Move silently; Silence-Touched enemies lose your trail.",
		"unlocks": "stealth",
	},
}

func gate_ids() -> Array:
	return GATE_ORDER.duplicate()

func get_gate(id: String) -> Dictionary:
	return _gates.get(id, {})

## The gate that lives in / opens a given sector index (0-based), or "".
func gate_for_sector(sector_id: int) -> String:
	for id in GATE_ORDER:
		if int(_gates[id]["sector"]) == sector_id:
			return id
	return ""

func tech_ids() -> Array:
	return _tech.keys()

func get_tech(id: String) -> Dictionary:
	return _tech.get(id, {})

func name_of(id: String) -> String:
	if _gates.has(id):
		return String(_gates[id]["name"])
	if _tech.has(id):
		return String(_tech[id]["name"])
	return id
