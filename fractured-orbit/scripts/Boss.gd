class_name Boss
extends CharacterBody3D
## The Original NEXUS — the Event Horizon boss. It fights the way the design
## demands: you cannot brute-force it. NEXUS is SHIELDED while an attack pattern
## runs; the **Reality Bender** gate (F, near the boss) deletes the active
## pattern permanently, opening a short vulnerability window in which your kinetic
## strikes (LMB) reach the core. Strip all three patterns to break it.
##
## So the intended loop chains the abilities: dodge the pattern → Reality Bender
## to strip it → strike the exposed core → repeat for the next, harder pattern.

signal defeated
signal boss_notice(text: String)
signal boss_health(frac: float)

const PATTERNS := 3

var pal := {}
var max_hp := 300.0
var hp := 300.0
var _player
var _shielded := true
var _vuln_t := 0.0
var _pattern := 0
var _stripped := 0
var _atk_cd := 1.6
var _spin := 0.0
var _dead := false

func setup(p: Dictionary) -> void:
	pal = p

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	var vis := Forge.model("nexus")
	add_child(vis)
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.4
	col.shape = sph
	col.position = Vector3(0, 1.4, 0)
	add_child(col)
	emit_signal("boss_notice", "THE ORIGINAL NEXUS — \"Join us, Loop-Walker. Stop dying.\"")

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_spin += delta
	rotation.y = _spin * 0.6
	_vuln_t = maxf(0.0, _vuln_t - delta)
	if _vuln_t <= 0.0 and not _shielded:
		# vulnerability window closed without a kill: re-shield, harder pattern
		_shielded = true
		emit_signal("boss_notice", "NEXUS re-forms its logic. Strip the next pattern.")

	_player = get_tree().get_first_node_in_group("player")
	if _player == null or not is_instance_valid(_player):
		return

	if _shielded:
		_atk_cd -= delta
		if _atk_cd <= 0.0:
			_atk_cd = [1.6, 1.2, 0.8][_pattern]
			_fire_pattern()

func _fire_pattern() -> void:
	var origin: Vector3 = global_position + Vector3(0, 1.4, 0)
	var col: Color = pal.get("danger", Color("ff2a5a"))
	match _pattern:
		0:  # aimed volley
			var to: Vector3 = (_player.global_position + Vector3(0, 1, 0)) - origin
			_spawn_bolt(origin, to, 13.0, 16.0, col)
		1:  # radial ring
			for i in 10:
				var a := TAU * float(i) / 10.0
				_spawn_bolt(origin, Vector3(cos(a), 0.0, sin(a)), 10.0, 14.0, col)
		2:  # fast aimed triple
			var base: Vector3 = (_player.global_position + Vector3(0, 1, 0)) - origin
			for off in [-0.25, 0.0, 0.25]:
				var d := base.rotated(Vector3.UP, off)
				_spawn_bolt(origin, d, 17.0, 18.0, col)

func _spawn_bolt(from: Vector3, direction: Vector3, spd: float, dmg: float, col: Color) -> void:
	var p := Projectile.new()
	get_parent().add_child(p)
	p.launch(from, direction, spd, dmg, col)

## Reality Bender hook: called by the Sector when the player rewrites near NEXUS.
func strip_pattern() -> bool:
	if _dead or not _shielded:
		return false
	_shielded = false
	_vuln_t = 4.0
	_stripped += 1
	emit_signal("boss_notice", "Pattern %d deleted. The core is exposed — STRIKE." % _stripped)
	return true

func take_damage(amount: float, _source: String = "") -> void:
	if _dead:
		return
	if _shielded:
		emit_signal("boss_notice", "SHIELDED — rewrite its pattern first (F)")
		return
	hp -= amount
	emit_signal("boss_health", clampf(hp / max_hp, 0.0, 1.0))
	if hp <= 0.0:
		_die()
		return
	# the fight escalates: each stripped pattern moves NEXUS toward its fastest one
	_pattern = mini(PATTERNS - 1, _stripped)

func _die() -> void:
	_dead = true
	emit_signal("boss_notice", "NEXUS dissolves into data.")
	emit_signal("defeated")
	queue_free()
