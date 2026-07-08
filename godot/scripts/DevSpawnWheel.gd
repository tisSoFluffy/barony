extends CanvasLayer
class_name DevSpawnWheel
## Press T in-game to open a radial enemy-spawn menu (dev tool).

const ENEMIES: Array[String] = ["kobold", "orc", "murloc", "skeleton", "necro", "troll", "ogre"]
const COLORS: Array[Color] = [
	Color("8a5a30"),  # kobold
	Color("4e8f3a"),  # orc
	Color("2fa48f"),  # murloc
	Color("d8d2c0"),  # skeleton
	Color("3a2060"),  # necro
	Color("3a6030"),  # troll
	Color("8a6840"),  # ogre
]

const R_IN  := 60.0
const R_OUT := 195.0

var is_open := false
var _prev_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _ctrl: Control

func _ready() -> void:
	layer   = 90
	visible = false
	_ctrl = Control.new()
	_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctrl.draw.connect(_draw_wheel)
	_ctrl.gui_input.connect(_on_input)
	add_child(_ctrl)

func toggle() -> void:
	if is_open: _close()
	else:        _open()

func _open() -> void:
	is_open = true
	visible = true
	_ctrl.mouse_filter  = Control.MOUSE_FILTER_STOP
	_prev_mouse_mode    = Input.mouse_mode
	Input.mouse_mode    = Input.MOUSE_MODE_VISIBLE

func _close() -> void:
	is_open = false
	visible = false
	_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode   = _prev_mouse_mode

func _process(_dt: float) -> void:
	if is_open:
		_ctrl.queue_redraw()

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var idx := _hovered_idx()
		if idx >= 0:
			_spawn(ENEMIES[idx])
		# Defer so ui_open stays true through this frame's _physics_process,
		# preventing the click from also triggering an attack.
		call_deferred("_close")
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		_close()

func _hovered_idx() -> int:
	var diff := _ctrl.get_local_mouse_position() - _ctrl.size / 2.0
	var dist := diff.length()
	if dist < R_IN or dist > R_OUT:
		return -1
	# +PI/2 aligns the 0-angle to north (top), matching how segments are drawn
	var angle := fmod(atan2(diff.y, diff.x) + PI / 2.0 + TAU, TAU)
	return int(angle / (TAU / ENEMIES.size()))

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw_wheel() -> void:
	if not is_open:
		return
	var center := _ctrl.size / 2.0
	var n      := ENEMIES.size()
	var slice  := TAU / n
	var hov    := _hovered_idx()
	var font   := ThemeDB.fallback_font

	_ctrl.draw_rect(Rect2(Vector2.ZERO, _ctrl.size), Color(0, 0, 0, 0.55))

	for i in range(n):
		var a0  := slice * i - PI / 2.0
		var a1  := a0 + slice
		var col := COLORS[i].lightened(0.35 if i == hov else 0.0)

		var pts := _slice_poly(center, R_IN, R_OUT, a0, a1)
		_ctrl.draw_colored_polygon(pts, col)

		# radial divider at leading edge of each slice
		_ctrl.draw_line(
				center + Vector2(cos(a0), sin(a0)) * R_IN,
				center + Vector2(cos(a0), sin(a0)) * R_OUT,
				Color(0, 0, 0, 0.4), 1.5)

		# enemy name
		var mid_a  := (a0 + a1) / 2.0
		var label  := ENEMIES[i].capitalize()
		var lsz    := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		var lpos   := center + Vector2(cos(mid_a), sin(mid_a)) * ((R_IN + R_OUT) / 2.0)
		_ctrl.draw_string(font, lpos - lsz / 2.0, label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
				Color("ffce42") if i == hov else Color.WHITE)

	# centre disk
	_ctrl.draw_circle(center, R_IN - 3.0, Color(0.07, 0.05, 0.13, 0.93))
	var lines: Array = (("[DEV SPAWN]" if hov < 0 else "SPAWN\n" + ENEMIES[hov].to_upper())).split("\n")
	var lh: float = font.get_height(13)
	for li in range(lines.size()):
		var lsz := font.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var yo  := (li - lines.size() / 2.0 + 0.5) * lh
		_ctrl.draw_string(font, center + Vector2(-lsz.x / 2.0, yo + lh * 0.35),
				lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffce42"))

func _slice_poly(center: Vector2, r_in: float, r_out: float,
		a0: float, a1: float, steps: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for s in range(steps + 1):
		var a := lerpf(a0, a1, float(s) / steps)
		pts.append(center + Vector2(cos(a), sin(a)) * r_in)
	for s in range(steps, -1, -1):
		var a := lerpf(a0, a1, float(s) / steps)
		pts.append(center + Vector2(cos(a), sin(a)) * r_out)
	return pts

# ── Spawning ──────────────────────────────────────────────────────────────────

const EnemyScene := preload("res://scenes/Enemy.tscn")

## Set by Main.gd on creation — the live Node3D that holds the player/enemies
## and the camera, since there is no running "Game" singleton in this build.
var host: Node

func _spawn(type: String) -> void:
	if not host or not host.player or not is_instance_valid(host.player):
		return
	var p: CharacterBody3D = host.player
	var cam := p.get_viewport().get_camera_3d()
	var fwd := Vector3.FORWARD
	if cam:
		fwd = -cam.global_transform.basis.z
		fwd.y = 0.0
		if fwd.length_squared() > 0.001:
			fwd = fwd.normalized()
	var en: CharacterBody3D = EnemyScene.instantiate()
	en.type = type
	host.world_level.add_child(en)
	en.global_position = p.global_position + fwd * 3.0
	en.awake = true
	SignalBus.hud_message.emit("[DEV] Spawned %s" % type.capitalize(), 2.0)
