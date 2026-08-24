class_name Hazard
extends Area3D
## Environmental hazards. Each is an Area3D that damages (and sometimes slows)
## whatever CharacterBody3D overlaps it. A few types animate: lasers pulse on a
## cycle, spore clouds are neutralized if the player owns the Spore Purifier
## tech. Visuals are low-poly primitives tinted from the sector palette; swap in
## generated models by name via Forge if desired.

var type := ""
var pal := {}
var dps := 14.0
var slow := 0.0            # 0..1 movement reduction while overlapping
var _active := true
var _cycle := 0.0
var _period := 1.6        # laser on/off period
var _bodies: Array = []   # overlapping bodies

func setup(t: String, p: Dictionary) -> void:
	type = t
	pal = p

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	_build()

func _build() -> void:
	var danger: Color = pal.get("danger", Color("ff5a3a"))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	match type:
		"spore_cloud":
			if Meta.has_effect("clear_spores"):
				# purifier installed: harmless fog, no damage
				_active = false
				dps = 0.0
				slow = 0.0
				danger = pal.get("fog", Color("445544"))
			else:
				dps = 6.0
				slow = 0.45
			box.size = Vector3(3, 3, 3)
			_add_visual(Vector3(3, 3, 3), danger, 0.5, 0.35)
		"laser_grid":
			dps = 26.0
			box.size = Vector3(3, 3, 0.4)
			_add_visual(Vector3(3, 3, 0.4), danger, 3.0, 0.7)
		"molten_floor", "thorn_wall", "reality_rift":
			dps = 20.0
			box.size = Vector3(3, 0.6, 3)
			_add_visual(Vector3(3, 0.5, 3), danger, 1.5, 1.0)
		"black_hole_pit":
			dps = 18.0
			box.size = Vector3(3, 4, 3)
			_add_visual(Vector3(1.2, 1.2, 1.2), pal.get("accent", danger), 3.0, 1.0)
		"zero_g_pocket":
			_active = false        # not damaging; movement handled by Player
			box.size = Vector3(4, 4, 4)
			_add_visual(Vector3(4, 4, 4), pal.get("accent", danger), 0.4, 0.15)
		"falling_crate", "crumbling_walkway", "pressure_plate", "mirror_room", _:
			dps = 12.0
			box.size = Vector3(2.5, 0.5, 2.5)
			_add_visual(Vector3(2.5, 0.4, 2.5), danger, 1.0, 0.9)
	shape.shape = box
	add_child(shape)

func _add_visual(size: Vector3, color: Color, emit: float, alpha: float) -> void:
	var mi := Forge.slab(size, color, emit)
	var m := mi.material_override as StandardMaterial3D
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = alpha
	add_child(mi)
	set_meta("visual", mi)

func _on_enter(body) -> void:
	if body.has_method("take_damage") and not _bodies.has(body):
		_bodies.append(body)

func _on_exit(body) -> void:
	_bodies.erase(body)
	if body.has_method("set_external_slow"):
		body.set_external_slow(0.0)

func _physics_process(delta: float) -> void:
	if type == "laser_grid":
		_cycle += delta
		var on := fmod(_cycle, _period) < _period * 0.5
		_active = on
		var vis = get_meta("visual", null)
		if vis:
			vis.visible = on
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		if _active and dps > 0.0:
			body.take_damage(dps * delta, type)
		if slow > 0.0 and body.has_method("set_external_slow"):
			body.set_external_slow(slow)
