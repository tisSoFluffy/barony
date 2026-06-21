extends RefCounted
class_name GearDB
## Randomized gear (weapons/armor/helms/rings), ported from the web build's rollGear.
## A gear instance: { "slot":String, "wtype":String, "name":String, "tier":int, "b":Dictionary }

const TIER_HEX := ["d8d8d8", "4a9eff", "b048f8"]
const TIER_PREFIX := ["", "fine ", "epic "]
const PREFIX := [["Rusty", "Worn", "Iron"], ["Steel", "Orcish", "Runed"], ["Arcanite", "Thorium", "Royal"]]
const SUFFIX := {"dmg": "of the Tiger", "spell": "of the Owl", "hp": "of the Bear", "mana": "of the Eagle", "armor": "of the Boar"}
const STAT_NAME := {"dmg": "melee", "spell": "spell", "hp": "health", "mana": "mana", "armor": "armor"}

static func _pick(a: Array) -> String:
	return a[Util.ri(0, a.size() - 1)]

static func roll_gear(d: int) -> Dictionary:
	var slot: String = _pick(["weapon", "weapon", "armor", "helm", "ring"])
	var tier: int = 2 if Util.rf(0, 1) < 0.12 + d * 0.03 else (1 if Util.rf(0, 1) < 0.42 else 0)
	var b: Dictionary = {}
	var base: String = ""
	var wtype: String = ""
	if slot == "weapon":
		wtype = "sword" if Util.rf(0, 1) < 0.5 else "staff"
		if wtype == "sword":
			base = _pick(["Blade", "Cleaver", "Greatsword", "Axe"])
			b["dmg"] = 2 + d * 2 + tier * 3 + Util.ri(0, 2)
		else:
			base = _pick(["Staff", "Rod", "Scepter"])
			b["spell"] = 4 + d * 3 + tier * 4 + Util.ri(0, 3)
	elif slot == "armor":
		base = _pick(["Hauberk", "Breastplate", "Vest"])
		b["armor"] = 1 + int((d + tier) / 2.0)
		if tier > 0:
			b["hp"] = 5 * tier + d
	elif slot == "helm":
		base = _pick(["Helm", "Coif", "Crown"])
		b["armor"] = 1 + int(tier / 2.0)
		if tier > 0:
			b["mana"] = 4 * tier + d
	else:
		base = _pick(["Ring", "Band", "Signet"])
		var st: String = _pick(["dmg", "spell", "hp", "mana", "armor"])
		if st == "armor":
			b[st] = 1 + tier
		elif st == "hp" or st == "mana":
			b[st] = 6 + d * 2 + tier * 4
		else:
			b[st] = 2 + d + tier * 2
	var nm: String = "%s %s" % [_pick(PREFIX[tier]), base]
	if tier > 0:
		var keys: Array = b.keys()
		nm += " " + str(SUFFIX[keys[keys.size() - 1]])
	return {"slot": slot, "wtype": wtype, "name": nm, "tier": tier, "b": b}

static func tier_color(tier: int) -> Color:
	return Color.html("#" + TIER_HEX[clampi(tier, 0, 2)])

static func tier_name(tier: int) -> String:
	return TIER_PREFIX[clampi(tier, 0, 2)]

static func sprite_id(gear: Dictionary) -> String:
	var slot: String = gear.get("slot", "")
	if slot == "weapon":
		return "staff" if gear.get("wtype", "") == "staff" else "sword"
	if slot == "armor":
		return "armorI"
	if slot == "helm":
		return "helmI"
	return "ringI"

static func describe(gear: Dictionary) -> String:
	var parts: Array = []
	var b: Dictionary = gear.get("b", {})
	for k in b:
		parts.append("+%d %s" % [int(b[k]), STAT_NAME.get(k, k)])
	return ", ".join(parts)
