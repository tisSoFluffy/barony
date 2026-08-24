extends Node
## Cross-run persistence — the "vania" half of the rogue-vania.
##
## Roguelike death resets the *run* (position, health, current-run pickups), but
## the following persist to user://echoes.save and carry into every future run:
##   * gates   — permanent traversal powers (see AbilityDB)
##   * tech    — Tech-Tree carry-over upgrades
##   * reached — the deepest sector unlocked (metroidvania progress)
##   * runs    — the loop counter; feeds SectorGen difficulty ("The Glitch")
##   * echoes  — where past selves died, with a note left behind. On later runs
##               the world spawns debris + a ghost-note at each echo, so failure
##               becomes environmental storytelling ("Be careful of the lasers,
##               they moved!").

const SAVE_PATH := "user://echoes.save"
const MAX_ECHOES := 40   # keep the most recent deaths; older ones fade

var gates := {}          # id -> true
var tech := {}           # id -> true
var reached := 0         # deepest sector index unlocked
var runs := 0            # completed loops (deaths + resets)
var echoes := []         # [{sector:int, pos:[x,y,z], note:String, run:int}, ...]

func _ready() -> void:
	load_state()

## ---- Queries used by gameplay ---------------------------------------------

func has_gate(id: String) -> bool:
	return gates.get(id, false)

func has_tech(id: String) -> bool:
	return tech.get(id, false)

## True when a Tech upgrade that neutralizes / enables `effect` is owned
## (effects are the AbilityDB "unlocks" strings, e.g. "clear_spores").
func has_effect(effect: String) -> bool:
	for id in tech.keys():
		if tech[id] and String(Abilities.get_tech(id).get("unlocks", "")) == effect:
			return true
	return false

func echoes_for(sector: int) -> Array:
	var out := []
	for e in echoes:
		if int(e.get("sector", -1)) == sector:
			out.append(e)
	return out

## ---- Mutations ------------------------------------------------------------

func unlock_gate(id: String) -> bool:
	if gates.get(id, false):
		return false
	gates[id] = true
	save_state()
	return true

func unlock_tech(id: String) -> bool:
	if tech.get(id, false):
		return false
	tech[id] = true
	save_state()
	return true

func mark_reached(sector: int) -> void:
	if sector > reached:
		reached = sector
		save_state()

## Record a death for the permadeath echo system, then bump the loop counter.
func record_death(sector: int, pos: Vector3, note: String) -> void:
	echoes.append({
		"sector": sector,
		"pos": [pos.x, pos.y, pos.z],
		"note": note,
		"run": runs,
	})
	if echoes.size() > MAX_ECHOES:
		echoes = echoes.slice(echoes.size() - MAX_ECHOES)
	runs += 1
	save_state()

## Wipe everything (true permadeath / new game). Used by menu + Path C ending.
func reset_all() -> void:
	gates.clear()
	tech.clear()
	reached = 0
	runs = 0
	echoes.clear()
	save_state()

## ---- Disk -----------------------------------------------------------------

func save_state() -> void:
	var data := {
		"gates": gates, "tech": tech, "reached": reached,
		"runs": runs, "echoes": echoes,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	gates = parsed.get("gates", {})
	tech = parsed.get("tech", {})
	reached = int(parsed.get("reached", 0))
	runs = int(parsed.get("runs", 0))
	echoes = parsed.get("echoes", [])
