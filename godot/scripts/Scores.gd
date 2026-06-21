extends Node
## Local Hall of Heroes — persisted to user://boa_scores.json. Autoload: Scores

const PATH := "user://boa_scores.json"

const CLASS_NAMES: Dictionary = {
	"war": "Footman", "mage": "Mage", "hunter": "Hunter",
	"paladin": "Paladin", "rogue": "Rogue", "warlock": "Warlock",
}

## entry keys: "name":String, "cls":String, "depth":int, "level":int,
##             "gold":int, "kills":int, "win":bool, "seed":String
func record(entry: Dictionary) -> void:
	var list: Array = load_all()
	list.append(entry)
	list.sort_custom(_cmp)
	list = list.slice(0, 8)
	_save(list)

func _cmp(a: Dictionary, b: Dictionary) -> bool:
	var aw: int = 1 if a.get("win", false) else 0
	var bw: int = 1 if b.get("win", false) else 0
	if aw != bw:
		return aw > bw
	var ad: int = a.get("depth", 0)
	var bd: int = b.get("depth", 0)
	if ad != bd:
		return ad > bd
	return int(a.get("gold", 0)) > int(b.get("gold", 0))

func load_all() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return []
	var raw: String = file.get_as_text()
	file.close()
	if raw.is_empty():
		return []
	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null or not (parsed is Array):
		return []
	return parsed as Array

func _save(list: Array) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(list))
	file.close()

func formatted() -> Array:
	var list: Array = load_all()
	var result: Array = []
	for item: Variant in list:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item as Dictionary
		var pname: String = str(entry.get("name", "Unknown"))
		var cls: String = str(entry.get("cls", ""))
		var depth: int = entry.get("depth", 0)
		var level: int = entry.get("level", 1)
		var gold: int = entry.get("gold", 0)
		var kills: int = entry.get("kills", 0)
		var win: bool = entry.get("win", false)
		var seed_s: String = str(entry.get("seed", ""))
		var cls_name: String = CLASS_NAMES.get(cls, cls)
		var prefix: String = "⚔" if win else "†"
		var status: String = "VICTORY" if win else ("fell on depth %d" % depth)
		var line: String = "%s %s the %s — %s · lv %d · %d gold · %d kills" % [
			prefix, pname, cls_name, status, level, gold, kills]
		if not seed_s.is_empty():
			line += " · " + seed_s
		result.append(line)
	return result
