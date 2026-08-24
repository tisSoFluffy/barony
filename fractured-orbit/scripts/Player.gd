class_name Player
extends CharacterBody3D
## First-person Loop-Walker. Base kit: WASD + mouse-look, jump, dash, a kinetic
## melee (LMB). On top of that sit the five metroidvania GATE moves, all bound
## to F and resolved by which gate you own (Meta.has_gate) and where you are:
##
##   magnet_boots   — near a magnetic pillar, ride the pull straight up
##   wall_run       — against a wall, run along it with gravity suspended
##   kinetic_charge — grounded, LMB shatters laser barricades ahead
##   zero_g_anchor  — fire a tether toward your look point and reel across
##   reality_bender — rewrite the room: delete the nearest hazard / open a path
##
## Without the gate, F reports what's missing — the core metroidvania feedback.

signal died(pos: Vector3, note: String)
signal health_changed(hp: float, maxhp: float)
signal notice(text: String)

const SPEED := 6.0
const JUMP := 9.5
const GRAVITY := 24.0
const DASH := 15.0
const MOUSE_SENS := 0.0022
const REACH := 3.0

var max_hp := 100.0
var hp := 100.0
var current_sector := 0
var sector: Sector                 # the live Sector, set by Game

var _yaw := 0.0
var _pitch := 0.0
var _cam: Camera3D
var _dash_cd := 0.0
var _invuln := 0.0
var _no_grav_t := 0.0              # wall-run / magnet suspends gravity briefly
var _external_slow := 0.0
var _last_hurt_by := ""

const PROP_TO_GATE := {
	"magnet_ring": "magnet_boots", "vine_ribbon": "wall_run",
	"laser_emitter": "kinetic_charge", "anchor_beacon": "zero_g_anchor",
	"reality_switch": "reality_bender",
}

func _ready() -> void:
	add_to_group("player")
	var col := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.4
	caps.height = 1.7
	col.shape = caps
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.6, 0)
	_cam.current = true
	add_child(_cam)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.4, 1.4)
		rotation.y = _yaw
		_cam.rotation.x = _pitch
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_no_grav_t = maxf(0.0, _no_grav_t - delta)
	_external_slow = maxf(0.0, _external_slow - delta * 1.5)

	# desired horizontal move in body space (body only yaws; camera pitches)
	var ix := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var iz := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	var wish := Vector3(ix, 0, iz)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var move := global_transform.basis * wish
	move.y = 0.0
	var spd := SPEED * (1.0 - clampf(_external_slow, 0.0, 0.8))
	velocity.x = move.x * spd
	velocity.z = move.z * spd

	# gravity + jump
	if _no_grav_t > 0.0:
		velocity.y = move_toward(velocity.y, 0.0, GRAVITY * delta)
	elif is_on_floor():
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
			Audio.play("jump", Util.lf(0.95, 1.08))
	else:
		velocity.y -= GRAVITY * delta

	# dash (base mobility)
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_dash_cd = 0.9
		var d := move
		if d.length() < 0.1:
			d = -global_transform.basis.z
		d = d.normalized()
		velocity.x += d.x * DASH
		velocity.z += d.z * DASH
		Audio.play("dash")

	if Input.is_action_just_pressed("gate_ability"):
		_try_gate()
	if Input.is_action_just_pressed("attack"):
		_attack()
	if Input.is_action_just_pressed("interact"):
		_interact()

	move_and_slide()
	_collect_walkover()

	if global_position.y < -40.0:      # fell into the void
		_last_hurt_by = "the void"
		hp = 0.0
		_check_death()

## ---- Gates ----------------------------------------------------------------

func _try_gate() -> void:
	var gate := String(Sectors.get_def(current_sector)["gate"])
	if not Meta.has_gate(gate):
		var g := Abilities.get_gate(gate)
		emit_signal("notice", "LOCKED — need %s" % g.get("name", gate))
		return
	match gate:
		"magnet_boots":
			if _near_gate_anchor(7.0):
				velocity.y = JUMP * 1.5
				_no_grav_t = 0.2
				emit_signal("notice", "Magnet Boots — riding the pull")
			else:
				emit_signal("notice", "No magnetic pillar in range")
		"wall_run":
			if is_on_wall():
				_no_grav_t = 0.9
				velocity.y = maxf(velocity.y, JUMP * 0.7)
				var n := get_wall_normal()
				var along := n.cross(Vector3.UP).normalized()
				velocity += along * SPEED
				emit_signal("notice", "Wall-Run")
			else:
				emit_signal("notice", "Need a wall to run")
		"zero_g_anchor":
			var fwd := -_cam.global_transform.basis.z
			velocity += fwd * 16.0
			_no_grav_t = 0.4
			emit_signal("notice", "Anchor tether — reeling in")
		"reality_bender":
			if sector and sector.has_method("rewrite"):
				var changed: bool = sector.rewrite(global_position)
				emit_signal("notice", "Reality rewritten" if changed else "Nothing to rewrite here")
	# refund a little air control after a gate move if Warp Jump is owned
	if Meta.has_tech("warp_jump"):
		_dash_cd = 0.0

func _near_gate_anchor(r: float) -> bool:
	if sector == null or sector.gen == null:
		return false
	var a: Vector3 = sector.gen.gate_pos
	return Vector2(global_position.x - a.x, global_position.z - a.z).length() < r

## ---- Combat ---------------------------------------------------------------

func _attack() -> void:
	var from := _cam.global_position
	var to := from + (-_cam.global_transform.basis.z) * REACH
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit and hit.has("collider"):
		var c = hit["collider"]
		if c.has_method("take_damage"):
			c.take_damage(24.0)
			Audio.play("strike", Util.lf(0.95, 1.1))
			emit_signal("notice", "Hit")
			return
	# grounded kinetic charge shatters laser barricades in range
	if Meta.has_gate("kinetic_charge") and is_on_floor():
		_shatter_lasers()

func _shatter_lasers() -> void:
	var broke := false
	if sector:
		for child in sector.hazards:
			if is_instance_valid(child) and child.type == "laser_grid":
				if child.global_position.distance_to(global_position) < 4.0:
					child.queue_free()
					broke = true
	if broke:
		emit_signal("notice", "Kinetic Charge — barricade shattered")

## ---- Interaction / pickups ------------------------------------------------

func _interact() -> void:
	if sector == null:
		return
	var best := {}
	var best_d := REACH
	for it in sector.interactables:
		var d: float = global_position.distance_to(it["pos"])
		if d < best_d:
			best_d = d
			best = it
	if best.is_empty():
		return
	match best.get("kind", ""):
		"gate":
			var gate := String(PROP_TO_GATE.get(best["name"], ""))
			if gate != "" and Meta.unlock_gate(gate):
				var g := Abilities.get_gate(gate)
				Audio.play("unlock", 1.0, -3.0)
				emit_signal("notice", "UNLOCKED: %s — %s" % [g["name"], g["desc"]])
			else:
				emit_signal("notice", "Already attuned")
		"pickup":
			_grant_pickup(String(best["name"]))
		"echo":
			var note := String(best["name"])
			emit_signal("notice", "ECHO: %s" % (note if note != "" else "...a past self died here."))
	sector.interactables.erase(best)

func _grant_pickup(name: String) -> void:
	match name:
		"health_cell":
			hp = minf(max_hp, hp + 35.0)
			emit_signal("health_changed", hp, max_hp)
			emit_signal("notice", "+35 integrity")
		"blueprint":
			var techs := Abilities.tech_ids()
			for t in techs:
				if not Meta.has_tech(t):
					Meta.unlock_tech(t)
					emit_signal("notice", "TECH: %s installed" % Abilities.name_of(t))
					return
			emit_signal("notice", "Blueprint archived")
		"tech_node":
			emit_signal("notice", "LOG: %s" % String(Sectors.get_def(current_sector)["log"]))

func _collect_walkover() -> void:
	for p in get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(p) and p.global_position.distance_to(global_position) < 1.6:
			hp = minf(max_hp, hp + 20.0)
			emit_signal("health_changed", hp, max_hp)
			emit_signal("notice", "+20 integrity")
			Audio.play("pickup")
			p.queue_free()

## ---- Damage / death -------------------------------------------------------

func take_damage(amount: float, source: String = "") -> void:
	if _invuln > 0.0:
		return
	hp -= amount
	if source != "":
		_last_hurt_by = source
	_invuln = 0.25
	Audio.play("hit")
	emit_signal("health_changed", hp, max_hp)
	_check_death()

func set_external_slow(v: float) -> void:
	_external_slow = maxf(_external_slow, v)

func _check_death() -> void:
	if hp <= 0.0:
		hp = 0.0
		Audio.play("death", 1.0, -3.0)
		var note := _death_note()
		emit_signal("died", global_position, note)
		set_physics_process(false)

func _death_note() -> String:
	var s := String(Sectors.get_def(current_sector)["name"])
	if _last_hurt_by == "the void":
		return "Fell into the void of %s. Watch the edges." % s
	if _last_hurt_by != "":
		return "%s got me in %s. It's not where it was." % [_pretty(_last_hurt_by), s]
	return "Died in %s. Keep moving." % s

func _pretty(id: String) -> String:
	return id.capitalize().replace("_", " ")
