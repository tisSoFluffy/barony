extends RefCounted
## Cheap ghost-copy swing trail for melee attacks: spawns 3-4 fading duplicate
## sprites of the player's CURRENT frame (body + weapon overlay if present)
## along the swing/thrust path, matching the same "duplicate the live texture,
## tween alpha to 0, queue_free" pattern as Player._spawn_charge_trail — no
## particle setup, no shape-specific art needed, and it automatically matches
## whatever weapon silhouette is equipped.
##
## Two shapes, chosen per-weapon via WeaponDB "trail":
##   "arc"    (default) — ghosts fan out across a rotation arc (mace/flail/
##            greatsword/sword-ish chop-and-sweep weapons).
##   "thrust" — ghosts step forward in a straight line along the facing
##            direction (spear/dagger pokes/jabs).
## Both are pure-visual, spawned from the RELEASE point in Player's deferred
## melee-hit flow (_resolve_melee_hit) — never touch damage/hit logic.

const GHOST_COUNT := 4
const FADE_TIME := 0.18
const GHOST_ALPHA := 0.4
const ARC_SPREAD_DEG := 50.0   # total rotation swept across the ghost fan
const THRUST_DIST := 0.5       # meters stepped forward across the ghost line

## Spawn ghost copies of `sprite`'s current frame fanning across a rotation
## arc, centered on the player's facing direction. `weapon_overlay` (may be
## null) additionally ghosts the equipped weapon's current texture so the
## trail reads as "the weapon swept through here," not just the body blurring.
static func spawn_arc(tree: SceneTree, sprite: AnimatedSprite3D, weapon_overlay: Node,
		origin: Vector3, facing: Vector3, color: Color = Color(1.0, 1.0, 1.0, 1.0),
		full_circle: bool = false) -> void:
	if sprite == null:
		return
	var parent: Node3D = tree.current_scene as Node3D
	if parent == null:
		return
	var spread := 360.0 if full_circle else ARC_SPREAD_DEG
	var start_deg := -spread * 0.5
	for i in range(GHOST_COUNT):
		var t := float(i) / float(maxi(GHOST_COUNT - 1, 1))
		var ang_deg := start_deg + spread * t
		var dir := facing.rotated(Vector3.UP, deg_to_rad(ang_deg))
		var pos := origin + dir * 0.35
		_spawn_ghost_pair(tree, parent, sprite, weapon_overlay, pos, color, i)

## Spawn ghost copies stepping forward along `facing` — reads as a straight
## poke/jab rather than a swept arc.
static func spawn_thrust(tree: SceneTree, sprite: AnimatedSprite3D, weapon_overlay: Node,
		origin: Vector3, facing: Vector3, color: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	if sprite == null:
		return
	var parent: Node3D = tree.current_scene as Node3D
	if parent == null:
		return
	var dir := facing.normalized() if facing.length_squared() > 0.001 else Vector3.FORWARD
	var count := 3
	for i in range(count):
		var t := float(i) / float(maxi(count - 1, 1))
		var pos := origin + dir * (THRUST_DIST * t)
		_spawn_ghost_pair(tree, parent, sprite, weapon_overlay, pos, color, i)

static func _spawn_ghost_pair(tree: SceneTree, parent: Node3D, sprite: AnimatedSprite3D,
		weapon_overlay: Node, pos: Vector3, color: Color, i: int) -> void:
	var delay := i * (FADE_TIME * 0.4 / maxf(1.0, float(GHOST_COUNT - 1)))
	tree.create_timer(delay).timeout.connect(func() -> void:
		if not is_instance_valid(sprite):
			return
		_ghost_body(parent, sprite, pos, color)
		if weapon_overlay != null and is_instance_valid(weapon_overlay) \
				and weapon_overlay.get("texture") != null:
			_ghost_weapon(parent, weapon_overlay, pos, color))

static func _ghost_body(parent: Node3D, sprite: AnimatedSprite3D, pos: Vector3, color: Color) -> void:
	if sprite.sprite_frames == null:
		return
	var ghost := Sprite3D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if ghost.texture == null:
		ghost.queue_free()
		return
	ghost.pixel_size = sprite.pixel_size
	ghost.billboard = sprite.billboard
	ghost.flip_h = sprite.flip_h
	ghost.shaded = false
	ghost.modulate = Color(color.r, color.g, color.b, GHOST_ALPHA)
	ghost.top_level = true
	parent.add_child(ghost)
	ghost.global_position = pos
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(ghost.queue_free)

static func _ghost_weapon(parent: Node3D, weapon_overlay: Node, pos: Vector3, color: Color) -> void:
	var ghost := Sprite3D.new()
	ghost.texture = weapon_overlay.get("texture")
	ghost.pixel_size = weapon_overlay.get("pixel_size")
	ghost.offset = weapon_overlay.get("offset")
	ghost.flip_h = weapon_overlay.get("flip_h")
	ghost.shaded = false
	ghost.modulate = Color(color.r, color.g, color.b, GHOST_ALPHA)
	ghost.top_level = true
	parent.add_child(ghost)
	# WeaponOverlay is itself top_level and places itself every frame via a
	# manually-built camera-plane global_transform (see WeaponOverlay._process)
	# rather than local position/rotation_degrees, so the ghost must copy that
	# basis directly — reading rotation_degrees off the overlay would be stale/
	# zero now. This keeps the ghost lying flat in the same camera plane as the
	# live weapon regardless of the player's body yaw.
	var overlay3d := weapon_overlay as Node3D
	if overlay3d != null:
		ghost.global_transform = Transform3D(overlay3d.global_transform.basis, pos + Vector3(0, 0, 0.02))
	else:
		ghost.global_position = pos + Vector3(0, 0, 0.02)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(ghost.queue_free)
