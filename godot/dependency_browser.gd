@tool
extends EditorScript

# ============================================================================
#  DEPENDENCY BROWSER  —  EmacEArt  (Godot 4.x)
# ============================================================================
#  Klikalne okno w edytorze: lista WSZYSTKICH zasobow + filtr po typie.
#  Po kliknieciu pozycji widzisz powiazania W OBIE STRONY:
#     - "Czego TO uzywa"   (zaleznosci w dol  — jak Unity 'Select Dependencies')
#     - "Co uzywa TEGO"     (kto referuje      — jak Unity 'Find References')
#
#  WAZNE — logika "sieroty" jest swiadoma roznicy:
#     * Zrodlowe assety paczki (.gltf/.glb/.fbx/.png/.mesh) NIE sa "do kasacji",
#       nawet jesli demo ich nie uzywa — to jest ZAWARTOSC paczki dla kupujacego.
#       Dostaja neutralny tag "treść paczki".
#     * Tylko nieuzywane ZASOBY Godota (.tres/.material/.res) sa realnymi
#       kandydatami do sprzatania — te swieca na pomaranczowo.
#
#  Jak odpalic:
#     1. Wrzuc plik do projektu (np. res://dependency_browser.gd)
#     2. Otworz w edytorze skryptow -> File -> Run (Ctrl+Shift+X)
#     3. Wyskoczy okno. NIC NIE USUWA — tylko pokazuje i nawiguje.
#
#  Dwuklik na liscie glownej = "wypikuj" plik w panelu FileSystem.
#  Dwuklik w panelach powiazan = skok do tego zasobu.
# ============================================================================

func _run() -> void:
	var base: Control = EditorInterface.get_base_control()
	var old: Node = base.find_child("EmacEArtDepBrowser", false, false)
	if old != null:
		old.free()
	var win := DependencyBrowser.new()
	win.name = "EmacEArtDepBrowser"
	base.add_child(win)
	win.popup_centered(Vector2i(1150, 700))


# ============================================================================
#  OKNO  —  cala logika tutaj, dzieki czemu zyje po zakonczeniu _run()
# ============================================================================
class DependencyBrowser extends Window:

	const IGNORE_DIRS := [".godot", ".git", ".import", "addons"]
	const SCAN_EXT := [
		"tscn", "scn", "tres", "res", "material", "mesh",
		"gdshader", "shader", "gd",
		"png", "jpg", "jpeg", "webp", "exr", "hdr", "svg", "tga", "bmp",
		"gltf", "glb", "fbx", "obj", "ogg", "wav", "mp3"
	]
	# Zrodlowe assety paczki — nieuzyte w demo to NORMALNE, nie kasujemy.
	const SOURCE_EXT := [
		"gltf", "glb", "fbx", "obj", "mesh",
		"png", "jpg", "jpeg", "webp", "exr", "hdr", "svg", "tga", "bmp",
		"ogg", "wav", "mp3"
	]
	# Tylko te nieuzywane = realni kandydaci do sprzatania.
	const CLEANUP_EXT := ["tres", "res", "material"]
	const NEVER_ORPHAN_NAME := ["project.godot", "dependency_browser.gd", "project_cleaner.gd", "icon.svg"]

	const COL_CLEANUP := Color(1.0, 0.55, 0.3)     # pomaranczowy — realna sierota
	const COL_CONTENT := Color(0.55, 0.75, 0.95)   # niebieski — tresc paczki
	const COL_MISSING := Color(1.0, 0.4, 0.4)      # czerwony — brak pliku

	# dane
	var all_files: Array[String] = []
	var fwd := {}            # path -> Array[String]  (czego uzywa)
	var rev := {}            # path -> Array[String]  (kto uzywa)
	var cat := {}            # path -> kategoria typu
	var main_scene: String = ""

	# stan UI
	var current_filter := "all"
	var search_text := ""
	var current_path := ""

	# wezly UI
	var main_list: ItemList
	var uses_list: ItemList
	var usedby_list: ItemList
	var info_label: RichTextLabel
	var count_label: Label
	var filter_buttons := {}

	func _init() -> void:
		title = "EmacEArt — Dependency Browser  (nic nie usuwa)"
		min_size = Vector2i(900, 560)
		close_requested.connect(queue_free)
		_build_ui()
		_scan()
		_refresh_list()

	# ----------------------------------------------------------------------
	#  BUDOWA UI
	# ----------------------------------------------------------------------
	func _build_ui() -> void:
		var root := VBoxContainer.new()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(root)

		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 8)
		pad.add_theme_constant_override("margin_right", 8)
		pad.add_theme_constant_override("margin_top", 8)
		pad.add_theme_constant_override("margin_bottom", 8)
		pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(pad)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		pad.add_child(vbox)

		# --- pasek filtrow ---
		var toolbar := HBoxContainer.new()
		vbox.add_child(toolbar)

		var filters := [
			["all", "Wszystko"], ["mesh", "Meshe"], ["mat", "Materiały"],
			["tex", "Tekstury"], ["shader", "Shadery"], ["scene", "Sceny"],
			["script", "Skrypty"], ["other", "Inne"]
		]
		for ff: Array in filters:
			var key: String = ff[0]
			var b := Button.new()
			b.text = ff[1]
			b.toggle_mode = true
			b.button_pressed = (key == "all")
			b.pressed.connect(_on_filter.bind(key))
			toolbar.add_child(b)
			filter_buttons[key] = b

		toolbar.add_child(VSeparator.new())

		var search := LineEdit.new()
		search.placeholder_text = "Szukaj po nazwie / ścieżce..."
		search.custom_minimum_size = Vector2(240, 0)
		search.text_changed.connect(_on_search)
		toolbar.add_child(search)

		var refresh := Button.new()
		refresh.text = "Odśwież"
		refresh.pressed.connect(_on_refresh)
		toolbar.add_child(refresh)

		# --- licznik ---
		count_label = Label.new()
		vbox.add_child(count_label)

		# --- glowny podzial ---
		var split := HSplitContainer.new()
		split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		split.split_offset = 480
		vbox.add_child(split)

		# lewa: lista wszystkiego (dwuklik = pokaz w FileSystem)
		main_list = ItemList.new()
		main_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main_list.item_selected.connect(_on_item_selected)
		main_list.item_activated.connect(_on_locate)
		split.add_child(main_list)

		# prawa
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_theme_constant_override("separation", 4)
		split.add_child(right)

		info_label = RichTextLabel.new()
		info_label.bbcode_enabled = true
		info_label.fit_content = true
		info_label.custom_minimum_size = Vector2(0, 78)
		info_label.text = "[i]Kliknij pozycję po lewej, aby zobaczyć powiązania. Dwuklik = pokaż plik w FileSystem.[/i]"
		right.add_child(info_label)

		var fs_btn := Button.new()
		fs_btn.text = "Pokaż zaznaczony w panelu FileSystem"
		fs_btn.pressed.connect(_on_show_in_filesystem)
		right.add_child(fs_btn)

		var l1 := Label.new()
		l1.text = "▼  Czego TO używa (zależności w dół):"
		right.add_child(l1)
		uses_list = ItemList.new()
		uses_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		uses_list.item_activated.connect(_on_jump.bind(true))
		right.add_child(uses_list)

		var l2 := Label.new()
		l2.text = "▲  Co używa TEGO (kto referuje):"
		right.add_child(l2)
		usedby_list = ItemList.new()
		usedby_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		usedby_list.item_activated.connect(_on_jump.bind(false))
		right.add_child(usedby_list)

		var legend := RichTextLabel.new()
		legend.bbcode_enabled = true
		legend.fit_content = true
		legend.custom_minimum_size = Vector2(0, 48)
		legend.text = "[color=#ff8c4d]■[/color] nieużywany zasób Godota (kandydat do sprzątania)   "
		legend.text += "[color=#8cbfef]■[/color] treść paczki (nieużyte w demo — to OK)\n"
		legend.text += "[i]Dwuklik w listach powiązań = skok do zasobu.[/i]"
		right.add_child(legend)

	# ----------------------------------------------------------------------
	#  SKAN
	# ----------------------------------------------------------------------
	func _scan() -> void:
		all_files.clear()
		fwd.clear()
		rev.clear()
		cat.clear()
		_collect("res://")
		main_scene = String(ProjectSettings.get_setting("application/run/main_scene", ""))

		for p: String in all_files:
			rev[p] = []

		for p: String in all_files:
			var deps := _deps(p)
			fwd[p] = deps
			cat[p] = _category(p)
			for d: String in deps:
				if rev.has(d):
					var arr: Array = rev[d]
					if not p in arr:
						arr.append(p)

	func _collect(path: String) -> void:
		var dir := DirAccess.open(path)
		if dir == null:
			return
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name == "." or name == "..":
				name = dir.get_next()
				continue
			var full := path.path_join(name)
			if dir.current_is_dir():
				if not name in IGNORE_DIRS:
					_collect(full)
			else:
				if name.get_extension().to_lower() in SCAN_EXT:
					all_files.append(full)
			name = dir.get_next()
		dir.list_dir_end()

	func _deps(path: String) -> Array[String]:
		var out: Array[String] = []
		var ext := path.get_extension().to_lower()
		if not ext in ["tscn", "scn", "tres", "res", "material", "mesh"]:
			return out
		for dep: String in ResourceLoader.get_dependencies(path):
			var clean := _clean_dep(dep)
			if clean != "" and clean != path and not clean in out:
				out.append(clean)
		return out

	func _clean_dep(dep: String) -> String:
		var idx := dep.find("res://")
		if idx == -1:
			return ""
		var p := dep.substr(idx)
		var stop := p.find("::")
		if stop != -1:
			p = p.substr(0, stop)
		return p

	func _category(path: String) -> String:
		var ext := path.get_extension().to_lower()
		if ext in ["png", "jpg", "jpeg", "webp", "exr", "hdr", "svg", "tga", "bmp"]:
			return "tex"
		if ext in ["gdshader", "shader"]:
			return "shader"
		if ext == "gd":
			return "script"
		if ext in ["gltf", "glb", "fbx", "obj", "mesh"]:
			return "mesh"
		if ext in ["tscn", "scn"]:
			return "scene"
		if ext == "material":
			return "mat"
		if ext in ["tres", "res"]:
			var t := _resource_type(path)
			if "Material" in t: return "mat"
			if "Shader" in t: return "shader"
			if "Mesh" in t: return "mesh"
			if "Texture" in t: return "tex"
			if "Scene" in t or "Packed" in t: return "scene"
			return "other"
		return "other"

	func _resource_type(path: String) -> String:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			return ""
		var head := f.get_buffer(300).get_string_from_utf8()
		f.close()
		var idx := head.find('type="')
		if idx == -1:
			return ""
		var rest := head.substr(idx + 6)
		var end := rest.find('"')
		if end == -1:
			return ""
		return rest.substr(0, end)

	# zwraca: "used" | "cleanup" | "content" | "scene" | "script"
	func _status(path: String) -> String:
		var refs: Array = rev.get(path, [])
		var referenced := not refs.is_empty()
		if path.get_file() in NEVER_ORPHAN_NAME or path == main_scene:
			referenced = true
		if referenced:
			return "used"
		var ext := path.get_extension().to_lower()
		if ext in CLEANUP_EXT:
			return "cleanup"
		if ext in SOURCE_EXT:
			return "content"
		if ext in ["tscn", "scn"]:
			return "scene"
		if ext == "gd":
			return "script"
		return "content"

	# ----------------------------------------------------------------------
	#  LISTA
	# ----------------------------------------------------------------------
	func _refresh_list() -> void:
		main_list.clear()
		var shown := 0
		var cleanup := 0
		var sorted := all_files.duplicate()
		sorted.sort()
		for p: String in sorted:
			if current_filter != "all" and cat.get(p, "other") != current_filter:
				continue
			if search_text != "" and not search_text.to_lower() in p.to_lower():
				continue
			var st := _status(p)
			var display: String = p.replace("res://", "")
			if st == "cleanup":
				display += "   — nieużywany zasób (sprzątanie)"
			elif st == "content":
				display += "   · treść paczki"
			elif st == "scene":
				display += "   · scena (nieużyta — prefab/demo?)"
			var i := main_list.add_item(display)
			main_list.set_item_metadata(i, p)
			main_list.set_item_tooltip(i, p)
			if st == "cleanup":
				main_list.set_item_custom_fg_color(i, COL_CLEANUP)
				cleanup += 1
			elif st == "content":
				main_list.set_item_custom_fg_color(i, COL_CONTENT)
			shown += 1
		count_label.text = "Pozycji: %d / %d   |   kandydatów do sprzątania (.tres/.material/.res): %d" % [shown, all_files.size(), cleanup]

	# ----------------------------------------------------------------------
	#  ZDARZENIA
	# ----------------------------------------------------------------------
	func _on_refresh() -> void:
		_scan()
		_refresh_list()

	func _on_filter(key: String) -> void:
		current_filter = key
		for k: String in filter_buttons:
			var b: Button = filter_buttons[k]
			b.button_pressed = (k == key)
		_refresh_list()

	func _on_search(txt: String) -> void:
		search_text = txt
		_refresh_list()

	func _on_item_selected(idx: int) -> void:
		var path: String = main_list.get_item_metadata(idx)
		_show_details(path)

	# dwuklik na liscie glownej -> pokaz plik w panelu FileSystem ("wypikuj")
	func _on_locate(idx: int) -> void:
		var meta = main_list.get_item_metadata(idx)
		if meta == null:
			return
		var path := str(meta)
		current_path = path
		_reveal(path)

	func _reveal(path: String) -> void:
		var dock := EditorInterface.get_file_system_dock()
		if dock != null and dock.has_method("navigate_to_path"):
			dock.navigate_to_path(path)
		else:
			EditorInterface.select_file(path)

	func _show_details(path: String) -> void:
		current_path = path
		var c: String = cat.get(path, "other")
		var st := _status(path)
		var head := "[b]%s[/b]\n" % path
		head += "Typ: %s" % _cat_label(c)
		match st:
			"cleanup":
				head += "    [color=#ff8c4d](nieużywany zasób Godota — realny kandydat do sprzątania)[/color]"
			"content":
				head += "    [color=#8cbfef](treść paczki — nieużyte w demo, to normalne, NIE kasuj)[/color]"
			"scene":
				head += "\n[i]Scena nieużyta przez nic — może to prefab dla kupującego albo zapomniane demo. Sprawdź zanim ruszysz.[/i]"
			"script":
				head += "\n[i]Skrypt nieużyty bezpośrednio — może być autoload / class_name. Sprawdź.[/i]"
		info_label.text = head

		uses_list.clear()
		var uses: Array = fwd.get(path, [])
		for d: String in uses:
			var miss := not ResourceLoader.exists(d) and not FileAccess.file_exists(d)
			var t: String = d.replace("res://", "")
			if miss:
				t += "   ⚠ BRAK PLIKU"
			var i := uses_list.add_item(t)
			uses_list.set_item_metadata(i, d)
			if miss:
				uses_list.set_item_custom_fg_color(i, COL_MISSING)
		if uses.is_empty():
			uses_list.add_item("(brak — nie korzysta z żadnych zasobów)")

		usedby_list.clear()
		var usedby: Array = rev.get(path, [])
		for r: String in usedby:
			var i := usedby_list.add_item(r.replace("res://", ""))
			usedby_list.set_item_metadata(i, r)
		if usedby.is_empty():
			usedby_list.add_item("(nikt nie referuje)")

	# dwuklik w panelach powiazan -> skok do zasobu
	func _on_jump(idx: int, from_uses: bool) -> void:
		var lst: ItemList = uses_list if from_uses else usedby_list
		if idx < 0 or idx >= lst.item_count:
			return
		var meta = lst.get_item_metadata(idx)
		if meta == null:
			return
		var path := str(meta)
		if path == "":
			return
		_show_details(path)
		for i in range(main_list.item_count):
			var m = main_list.get_item_metadata(i)
			if m != null and str(m) == path:
				main_list.select(i)
				main_list.ensure_current_is_visible()
				break

	func _on_show_in_filesystem() -> void:
		if current_path == "":
			return
		_reveal(current_path)

	func _cat_label(c: String) -> String:
		match c:
			"mesh": return "Mesh / geometria"
			"mat": return "Materiał"
			"tex": return "Tekstura"
			"shader": return "Shader"
			"scene": return "Scena"
			"script": return "Skrypt"
			_: return "Inny zasób"
