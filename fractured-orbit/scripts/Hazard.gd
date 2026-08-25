class_name Hazard
extends Area3D
## Environmental hazards. Each is an Area3D that damages (and sometimes slows)
## whatever CharacterBody3D overlaps it. A few types animate: lasers pulse on a
## cycle, spore clouds are neutralized if the player owns the Spore Purifier
## tech. Hazards with a physical emitter (see DEVICE_MODEL) show the generated
## device for it; area effects stay low-poly primitives tinted from the sector
## palette.

# Hazard type -> the generated device that represents it. Only hazards with a
# physical emitter are listed: molten floors, rifts and crumbling walkways are
# area effects whose look belongs in a floor shader, not a mesh.
const DEVICE_MODEL := {
	"laser_grid": "laser_emitter",
	"thorn_wall": "thorn_cluster",
	"spore_cloud": "spore_vent",
	"black_hole_pit": "black_hole_core",
}

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
			_add_device(Vector3.ZERO)          # the vent the cloud pours out of
		"laser_grid":
			dps = 26.0
			box.size = Vector3(3, 3, 0.4)
			# Emitters bracket the beam and stay lit; only the beam blinks, so they
			# are added separately from the "visual" meta the pulse toggles.
			_add_device(Vector3(-1.5, 0.0, 0.0))
			_add_device(Vector3(1.5, 0.0, 0.0), PI)
			_add_visual(Vector3(3, 3, 0.4), danger, 3.0, 0.7)
		"thorn_wall":
			dps = 20.0
			box.size = Vector3(3, 0.6, 3)
			var thorns := false
			for off in [Vector3(-0.95, 0, -0.7), Vector3(0.9, 0, 0.55), Vector3(0.05, 0, 0.95)]:
				thorns = _add_device(off, Util.rf(0.0, TAU), Util.rf(0.6, 0.8)) or thorns
			# With real thorns the slab is just a footprint; without them it IS the hazard.
			_add_visual(Vector3(3, 0.5, 3), danger,
					0.35 if thorns else 1.5, 0.5 if thorns else 1.0)
		"molten_floor", "reality_rift":
			dps = 20.0
			box.size = Vector3(3, 0.6, 3)
			_add_visual(Vector3(3, 0.5, 3), danger, 1.5, 1.0)
		"black_hole_pit":
			dps = 18.0
			box.size = Vector3(3, 4, 3)
			if not _add_device(Vector3(0.0, 1.0, 0.0)):
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

## Instances this hazard's generated device at a local offset. The damage volume
## is untouched — this only changes what the player sees. Returns false, adding
## nothing, when the model has not been generated yet, so callers can keep their
## primitive stand-in until the .glb lands and then swap automatically.
func _add_device(offset: Vector3, yaw: float = 0.0, scale_mul: float = 1.0) -> bool:
	var asset: String = DEVICE_MODEL.get(type, "")
	if asset == "" or not Forge.has_model(asset):
		return false
	var node := Forge.model(asset)
	node.position = offset
	node.rotation.y = yaw
	# Scaling the instance, not _model_size: several thorns share one 3x3 pad, so
	# they need to be smaller here than the same asset would be standing alone.
	node.scale = Vector3(scale_mul, scale_mul, scale_mul)
	add_child(node)
	return true

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
