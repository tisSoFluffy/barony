extends Node
## Enemy + spawn-table data, ported from the web build. Autoload name: Bestiary

var defs: Dictionary = {
	"kobold":   { "spr": "kobold", "hp": 22, "dmg": 6, "speed": 1.7, "xp": 14, "scale": 0.55,
				"atk_cd": 1.1, "range": 0.95, "sight": 7, "name": "Kobold Tunneler" },
	"murloc":   { "spr": "murloc", "hp": 32, "dmg": 9, "speed": 2.3, "xp": 26, "scale": 0.62,
				"atk_cd": 0.85, "range": 0.95, "sight": 8, "name": "Murloc Raider" },
	"troll":    { "spr": "troll", "hp": 42, "dmg": 11, "speed": 2.0, "xp": 55, "scale": 0.86,
				"atk_cd": 1.7, "range": 7.0, "sight": 10, "ranged": "axe", "keep_dist": 4.0, "name": "Troll Headhunter" },
	"skeleton": { "spr": "skeleton", "hp": 48, "dmg": 13, "speed": 1.5, "xp": 42, "scale": 0.82,
				"atk_cd": 1.2, "range": 1.05, "sight": 9, "name": "Scourge Skeleton" },
	"orc":      { "spr": "orc", "hp": 75, "dmg": 17, "speed": 1.9, "xp": 75, "scale": 0.92,
				"atk_cd": 1.0, "range": 1.05, "sight": 9, "name": "Orc Grunt" },
	"necro":    { "spr": "necro", "hp": 58, "dmg": 15, "speed": 1.4, "xp": 95, "scale": 0.88,
				"atk_cd": 2.2, "range": 8.0, "sight": 10, "ranged": "bolt", "keep_dist": 5.0, "summon": 9.0, "name": "Cultist Necromancer" },
	"ogre":     { "spr": "ogre", "hp": 420, "dmg": 30, "speed": 1.25, "xp": 600, "scale": 1.45,
				"atk_cd": 1.5, "range": 1.5, "sight": 12, "name": "Gor'maul the Warlord", "boss": true },
}

var spawns: Dictionary = {
	1: { "n": 8,  "pool": [["kobold", 70], ["murloc", 30]] },
	2: { "n": 10, "pool": [["kobold", 25], ["murloc", 35], ["troll", 20], ["skeleton", 20]] },
	3: { "n": 12, "pool": [["murloc", 20], ["skeleton", 30], ["troll", 20], ["orc", 20], ["necro", 10]] },
	4: { "n": 13, "pool": [["skeleton", 30], ["orc", 40], ["troll", 15], ["necro", 15]] },
	5: { "n": 9,  "pool": [["skeleton", 25], ["orc", 50], ["necro", 25]] },
}

func get_def(id: String) -> Dictionary:
	return defs.get(id, {})

func spawn_table(depth: int) -> Dictionary:
	return spawns.get(clampi(depth, 1, 5), spawns[1])
