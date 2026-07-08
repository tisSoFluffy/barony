# DevRigShot.gd — dev-only weapon paper-doll iteration rig.
# Run the game with:
#   godot --path godot -- --rig-shot=/tmp/rig --equip-weapon=sword
# Positions the camera ~4m from the player, drives idle -> walk -> attack
# (both facing directions, so flip_h mirroring can be checked), and captures
# one screenshot PER ANIMATION FRAME to <prefix>_<anim>_<frame>[_left].png,
# then quits. No-op in normal play (no --rig-shot arg). Kept permanently —
# future weapon art needs the same fast iteration loop.
#
# Frames are captured by directly driving Player state (bypassing Input),
# same pattern the headless test suite uses (tools/test_weapons.gd _mk_player
# / _step_until_hit) — real input timing isn't reliable frame-by-frame, and
# we want a screenshot at EVERY sprite frame, not just whenever real-time
# animation happens to land on one.

extends Node

var _prefix := ""
var _player: CharacterBody3D = null
var _camera: Camera3D = null
var _steps: Array = []  # queue of Callable, drained one per _process call
var _active := false
# Optional forced player body yaw (radians), set via --rig-yaw=<rad>. Lets
# captures probe the camera-plane weapon placement bug at headings other than
# the default 0 — the original rig-shot tuning never varied player rotation.y,
# which is why the orbit-with-yaw bug went unnoticed until user reports.
var _rig_yaw: float = 0.0
var _has_rig_yaw := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rig-shot="):
			_prefix = arg.trim_prefix("--rig-shot=")
		elif arg.begins_with("--rig-yaw="):
			_rig_yaw = arg.trim_prefix("--rig-yaw=").to_float()
			_has_rig_yaw = true
	if _prefix.is_empty():
		return
	_active = true
	# Wait a few frames for Main/World/Player to finish spawning.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_find_nodes()
	if _player == null or _camera == null:
		print("DevRigShot: player or camera not found, aborting")
		get_tree().quit(1)
		return
	if _has_rig_yaw:
		_player.rotation.y = _rig_yaw
	_setup_camera()
	_build_steps()
	_run_next()

func _find_nodes() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]
	_camera = get_viewport().get_camera_3d()

func _setup_camera() -> void:
	# Detach from IsoCamera's follow target so we can frame a tight close-up;
	# ~4m out, slightly elevated, looking at the player — enough to read hand
	# and blade detail at zoom, matching how the bug reports were framed.
	_camera.set_script(null)
	_camera.global_position = _player.global_position + Vector3(2.8, 2.2, 2.8)
	_camera.look_at(_player.global_position + Vector3(0, 1.1, 0), Vector3.UP)
	_camera.fov = 38.0

func _build_steps() -> void:
	_steps.clear()
	_steps.append(func(): _capture_anim("idle", false))
	_steps.append(func(): _capture_anim("walk", false))
	_steps.append(func(): _capture_anim("attack", false))
	_steps.append(func(): _capture_anim("walk", true))  # walking-left set for flip verification
	_steps.append(func(): _finish())

func _run_next() -> void:
	if _steps.is_empty():
		return
	var step: Callable = _steps.pop_front()
	step.call()

# Force the parent sprite into `anim` and step through every one of its
# frames, capturing a screenshot at each. `face_left` sets `_facing_dir`
# directly (the actual flip source since the 2026-07-02 fix — flip_h is
# driven by last movement INTENT, not instantaneous velocity) so flip_h
# latches true, then holds still while attacking/idling so the anim doesn't
# fight our forced frame index.
func _capture_anim(anim: String, face_left: bool) -> void:
	var sprite: AnimatedSprite3D = _player._sprite
	if sprite == null:
		_run_next()
		return
	if face_left:
		_player._facing_dir = Vector3(-1.0, 0, 0)
		_player.velocity = Vector3.ZERO
		_player._update_anim()
	else:
		_player._facing_dir = Vector3(1.0, 0, 0)
		_player.velocity = Vector3.ZERO
		_player._update_anim()
	if anim == "attack":
		_player.atk_t = _player.atk_cd if _player.atk_cd > 0.0 else 0.45
		var wdef: Dictionary = _player._weapon_def()
		_player.atk_cd = wdef.get("cd", 0.45)
		_player.atk_t = _player.atk_cd
	sprite.animation = anim
	sprite.play(anim)
	sprite.stop()  # stop autoplay advance; we drive `frame` manually below
	var frame_count: int = sprite.sprite_frames.get_frame_count(anim)
	var suffix := "_left" if face_left else ""
	_capture_frames(sprite, anim, frame_count, 0, suffix)

func _capture_frames(sprite: AnimatedSprite3D, anim: String, count: int, i: int, suffix: String) -> void:
	if i >= count:
		_run_next()
		return
	# Re-assert this frame's full state EVERY real engine frame we await through
	# (not just once): Player._physics_process runs regardless of what we're
	# driving here and calls _update_anim(), which (a) reverts `sprite.animation`
	# back to idle/walk/attack based on live state each tick, and (b) switches
	# off "attack" entirely the instant atk_t hits 0 — so atk_t must stay > 0
	# through the LAST attack frame too. Using `count` (not `count - 1`) as the
	# divisor keeps a small positive remainder on the final frame instead of
	# landing exactly on zero. This exact interaction (frame index landing on
	# the last frame at the same moment atk_t/anim state lapses back to idle)
	# is the live-game root cause of "attack never shows the weapon" — Player's
	# real per-frame timer can reach 0 on the same tick the last attack frame
	# is meant to render, so the overlay reads a stale "idle" anchor right when
	# the swing should be most visible.
	for _tick in range(2):
		if anim == "attack" and _player.atk_cd > 0.0:
			_player.atk_t = _player.atk_cd * (1.0 - float(i) / float(count))
		sprite.animation = anim
		sprite.frame = i
		if _player._weapon_overlay != null:
			_player._weapon_overlay._process(0.0)
		await get_tree().process_frame
	var path := "%s_%s_%d%s.png" % [_prefix, anim, i, suffix]
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("DevRigShot: saved ", path)
	_capture_frames(sprite, anim, count, i + 1, suffix)

func _finish() -> void:
	print("DevRigShot: done")
	get_tree().quit()
