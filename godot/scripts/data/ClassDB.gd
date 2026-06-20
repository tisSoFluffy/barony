extends Node
## Hero class + ability data, ported from the web build. Autoload name: Classes

var order: Array[String] = ["war", "mage", "hunter", "paladin", "rogue", "warlock"]

var defs: Dictionary = {
	"war": {
		"name": "Footman", "glyph": "⚔", "res": "RAGE",
		"hp": 110, "mp": 50, "regen": 2.0, "dmg": 16, "spell": 0,
		"hp_lv": 14, "mp_lv": 4, "dmg_lv": 3, "spell_lv": 0,
		"hpots": 1, "mpots": 0, "avatar": "pfoot", "portrait": "war",
		"blurb": "Stormwind knight — sword & shield. Whirlwind clears rooms; Charge closes the gap.",
		"hint": "LMB swing · hold RMB block · Q Whirlwind · B Charge",
	},
	"mage": {
		"name": "Mage", "glyph": "✶", "res": "MANA",
		"hp": 75, "mp": 80, "regen": 1.4, "dmg": 8, "spell": 42,
		"hp_lv": 8, "mp_lv": 10, "dmg_lv": 1, "spell_lv": 6,
		"hpots": 1, "mpots": 1, "avatar": "pmage", "portrait": "mage",
		"blurb": "Dalaran scholar — frail but devastating. Fireballs, Frost Nova, Blink.",
		"hint": "LMB/RMB Fireball · Q Frost Nova · B Blink",
	},
	"hunter": {
		"name": "Hunter", "glyph": "🏹", "res": "FOCUS",
		"hp": 92, "mp": 60, "regen": 2.6, "dmg": 13, "spell": 0,
		"hp_lv": 11, "mp_lv": 6, "dmg_lv": 3, "spell_lv": 0,
		"hpots": 1, "mpots": 0, "avatar": "phunt", "portrait": "hunter",
		"blurb": "Ranger of the wilds — rapid arrows from afar. Multishot fans the line; Roll to escape.",
		"hint": "LMB Arrow · RMB Power Shot · Q Multishot · B Roll",
	},
	"paladin": {
		"name": "Paladin", "glyph": "✚", "res": "FAITH",
		"hp": 118, "mp": 60, "regen": 1.4, "dmg": 15, "spell": 0,
		"hp_lv": 14, "mp_lv": 6, "dmg_lv": 3, "spell_lv": 0,
		"hpots": 1, "mpots": 1, "avatar": "ppala", "portrait": "paladin",
		"blurb": "Champion of the Light — holy bruiser. Holy Light mends; Consecration burns the unholy.",
		"hint": "LMB Hammer · RMB Holy Light · Q Consecration · B Divine Shield",
	},
	"rogue": {
		"name": "Rogue", "glyph": "🗡", "res": "ENERGY",
		"hp": 86, "mp": 60, "regen": 3.0, "dmg": 12, "spell": 0,
		"hp_lv": 10, "mp_lv": 6, "dmg_lv": 4, "spell_lv": 0,
		"hpots": 1, "mpots": 0, "avatar": "prog", "portrait": "rogue",
		"blurb": "Shadow assassin — fast crits. Fan of Knives hits all around; Shadowstep blinks to the kill.",
		"hint": "LMB Daggers · RMB Throw · Q Fan of Knives · B Shadowstep",
	},
	"warlock": {
		"name": "Warlock", "glyph": "☣", "res": "MANA",
		"hp": 82, "mp": 80, "regen": 1.5, "dmg": 8, "spell": 36,
		"hp_lv": 9, "mp_lv": 9, "dmg_lv": 1, "spell_lv": 5,
		"hpots": 1, "mpots": 1, "avatar": "pwarl", "portrait": "warlock",
		"blurb": "Fel-touched sorcerer — drains life with shadow. Hellfire scorches; Shadowstep slips away.",
		"hint": "LMB/RMB Shadow Bolt (heals you) · Q Hellfire · B Shadowstep",
	},
}

# Projectiles: damage is data-driven via a "dmg_kind" the gameplay layer resolves.
# dmg_kind: "spell" -> totSpell();  "dmg" -> totDmg()+dmg_add;  "dmg2" -> totDmg()*2+dmg_add
var proj: Dictionary = {
	"fire": { "speed": 9.0, "cost": 8, "cd": 0.42, "dmg_kind": "spell", "dmg_add": 0, "pierce": 0, "life": 0.0,
			  "c1": "ff5810", "c2": "ffd040", "trail": "ff9020", "sfx": "fire" },
	"arrow": { "speed": 13.0, "cost": 0, "cd": 0.30, "dmg_kind": "dmg", "dmg_add": 4, "pierce": 0, "life": 0.0,
			   "c1": "6a4a28", "c2": "e8e0c8", "trail": "caa070", "sfx": "swing" },
	"power": { "speed": 12.0, "cost": 16, "cd": 0.55, "dmg_kind": "dmg2", "dmg_add": 8, "pierce": 1, "life": 0.0,
			   "c1": "caa84a", "c2": "fff0a0", "trail": "ffe48a", "sfx": "fire" },
	"shadow": { "speed": 8.0, "cost": 7, "cd": 0.46, "dmg_kind": "spell", "dmg_add": 0, "pierce": 0, "life": 0.4,
				"c1": "3a1050", "c2": "9aff6a", "trail": "7aff50", "sfx": "fire" },
	"dagger": { "speed": 11.0, "cost": 6, "cd": 0.30, "dmg_kind": "dmg", "dmg_add": 0, "pierce": 0, "life": 0.0,
				"c1": "4a4a54", "c2": "ccd6e0", "trail": "aab4c0", "sfx": "swing" },
}

# Self-centred ability bursts (Q). dmg_kind:
#   "dmg" -> round(totDmg()*dmg_mul)+dmg_add ; "spell_half" -> dmg_add+(totSpell()/2) ; "spell_56" -> dmg_add+(totSpell()*5/6)
var aoe: Dictionary = {
	"whirl": { "res": 22, "cd": 3.2, "r": 2.2, "dmg_kind": "dmg", "dmg_mul": 1.3, "dmg_add": 0, "slow": 0.0, "col": "e0e0ee", "name": "Whirlwind!" },
	"nova": { "res": 20, "cd": 4.0, "r": 3.0, "dmg_kind": "spell_half", "dmg_mul": 1.0, "dmg_add": 12, "slow": 3.0, "col": "9adfff", "name": "Frost Nova!" },
	"conse": { "res": 24, "cd": 4.5, "r": 2.6, "dmg_kind": "dmg", "dmg_mul": 1.0, "dmg_add": 14, "slow": 0.0, "col": "ffe48a", "name": "Consecration!" },
	"fan": { "res": 20, "cd": 3.0, "r": 2.4, "dmg_kind": "dmg", "dmg_mul": 1.1, "dmg_add": 0, "slow": 0.0, "col": "ccd6e0", "name": "Fan of Knives!" },
	"hellf": { "res": 24, "cd": 4.0, "r": 3.0, "dmg_kind": "spell_56", "dmg_mul": 1.0, "dmg_add": 12, "slow": 0.0, "col": "ff7a30", "name": "Hellfire!" },
}

var melee_cd: Dictionary = { "war": 0.42, "paladin": 0.52, "rogue": 0.3 }

func get_def(id: String) -> Dictionary:
	return defs.get(id, defs["war"])
