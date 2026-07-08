extends Sprite3D
## Paper-doll weapon overlay: a Sprite3D child of the player's AnimatedSprite3D,
## drawing the equipped weapon's texture and repositioning it per-frame to
## roughly track the hand through idle/walk/attack.
##
## Visibility rule: base warrior sheets (res://sprites/sliced/warrior-base/) don't
## exist yet — they'll carry an empty-handed rig once generated. Until then the
## "warrior" sprite frames ARE a sword baked into the art. Showing a second sword
## overlay on top of that looks fine (barely visible, roughly overlapping) but
## showing a SPEAR/GREATSWORD/etc overlay over a baked *sword* sheet would look
## worse than just leaving the overlay hidden. So: show the overlay whenever the
## equipped weapon isn't the sword (a mismatched weapon replacing the visual is
## still better than a sword-shaped baked sprite when the player picked a spear),
## OR whenever true base (weaponless) sheets exist on disk. Once base sheets land,
## this always shows and anchors get final tuning against the real hand pose.
const BASE_SHEET_PROBE := "res://sprites/sliced/warrior-base/idle_0.png"

# Local WORLD-SPACE (meters) offsets from the parent sprite's origin, rotation,
# and depth-order per anim+frame. Missing frame index re-uses the last defined
# one. World-space (not sprite-pixel-space) so anchors stay stable regardless
# of the weapon texture's source resolution — see TARGET_WORLD_HEIGHT below.
#
# PIVOT: the texture is tight-cropped to its content bbox at load time (see
# _load_cropped below) and `offset` is set so the GRIP point (not the texture
# center — Sprite3D's default pivot) sits at the node origin. That means `pos`
# below means "where the hand is" and `rot_deg` rotates the weapon around the
# grip like something actually held, not swinging the blade through the fist.
# Source art is drawn on its own diagonal (grip lower-left, tip upper-right,
# ~28deg above horizontal) rather than pre-rotated upright — anchors bake in
# that correction so "rot_deg: 0" reads as "blade held level, pointing right."
#
# `pos` values were measured directly off the BAKED sword pixels in the
# legacy warrior-*.png sheets (the ground truth for "where the hand actually
# is" until warrior-base lands) — grip pixel per frame converted to local
# meters via (px - W/2)*pixel_size, (H/2 - py)*pixel_size with the parent's
# pixel_size (0.0025). The baked sword hand sits on SCREEN-LEFT of the body
# (shield arm is screen-right) in the unflipped pose, hence negative x.
const ANCHORS: Dictionary = {
	"idle": [
		{"pos": Vector2(-0.17, -0.10), "rot_deg": -78.0, "behind": false},
	],
	"walk": [
		{"pos": Vector2(-0.50, 0.03),  "rot_deg": -64.0, "behind": false},
		{"pos": Vector2(-0.47, 0.07),  "rot_deg": -58.0, "behind": false},
		{"pos": Vector2(-0.50, 0.03),  "rot_deg": -64.0, "behind": false},
	],
	# Baked attack frames (verified by reading warrior-base/attack_{0,1,2}.png
	# directly, not assumed): 0 = fist cocked back high near the shoulder
	# (wind-up), 1 = arm swept down-forward across the body, weight lunging in
	# (extended strike — this is the downstroke that should carry the weapon's
	# reach and the deferred-hit damage moment), 2 = arms relaxed back at the
	# sides (recover, close to the idle pose). The OLD table below was
	# sequenced against a since-replaced warrior-attack.png whose frame order
	# was [strike, strike-follow, windup] — re-phased here to match the real
	# [windup, strike, recover] body order (2026-07-08 fix: "hand up sword
	# still, hand down sword rises").
	"attack": [
		{"pos": Vector2(-0.51, 0.34),  "rot_deg": 10.0,  "behind": false},  # wind-up: raised high overhead, matches cocked-back fist
		{"pos": Vector2(-0.50, -0.02), "rot_deg": -58.0, "behind": false},  # strike: low extended downswing, matches arm sweeping down-forward
		{"pos": Vector2(-0.17, -0.10), "rot_deg": -78.0, "behind": false},  # recover: back near idle grip, matches relaxed arms
	],
	"hurt": [
		{"pos": Vector2(-0.17, -0.10), "rot_deg": -78.0, "behind": true},
	],
}

# Target world-space height for the overlay, independent of the source PNG's
# resolution — raw generated weapon icons land at wildly different canvas
# sizes than the character sheet (e.g. a full 1408x768 icon frame vs the
# character's tightly-cropped ~260px frame), so pixel_size can't just be
# copied from the parent. We derive it per-texture instead, from the CROPPED
# content height (not the raw canvas height — the raw canvas is mostly empty
# corner triangles around the diagonal blade, so using it would make the
# blade read far too small).
const TARGET_WORLD_HEIGHT := 0.62  # roughly forearm-to-blade-tip on the player capsule

# How far inside the content bbox's lower-left corner the actual grip sits,
# as a fraction of the bbox's diagonal extent. The blade art always leaves a
# few pixels of rounded pommel/guard past the true grip-center, so we inset
# slightly rather than pivoting on the very corner pixel.
const GRIP_INSET_FRAC := 0.10

# Per-weapon-id cache: {"tex": ImageTexture, "grip_px": Vector2 (in cropped-
# texture pixel space, Y-down)}. Cropping is deterministic per source file so
# caching by id (not by path) is safe and avoids re-scanning pixels every
# equip.
static var _crop_cache: Dictionary = {}

# Camera-plane axes for the manual "billboard" placement below. The body
# AnimatedSprite3D uses BILLBOARD_FIXED_Y, so its VISUAL always faces the
# fixed camera regardless of the parent CharacterBody3D's node yaw — but this
# Sprite3D is a plain (non-billboarded) child, so its world offset used to
# rotate WITH the parent's node rotation while the body's own visual didn't.
# Result: the weapon orbited the body as the player turned, detaching from
# the painted hand (and going edge-on / near-invisible at some headings)
# instead of tracking the camera-facing hand like the body billboard does.
# Fix: every frame we set our OWN global_transform directly from these fixed
# camera-space axes, completely bypassing the parent's node rotation — same
# trick BILLBOARD_FIXED_Y does internally, done by hand so we can also apply
# our own roll (the grip rotation) which `billboard` alone can't express.
# RIGHT matches the existing screen-space convention already used in
# Player._update_anim's flip_h check (`_facing_dir.dot(Vector3(0.707,0,-0.707))`)
# — verified empirically via yawed DevRigShot captures (rig-yaw 0.8/2.4) that
# this RIGHT/UP pair keeps the weapon's screen-space placement stable
# regardless of parent yaw.
const CAM_RIGHT := Vector3(0.707, 0.0, -0.707)
const CAM_UP := Vector3.UP
# Forward "into the screen" (toward the camera's look direction), used for the
# behind/in-front z_nudge so "behind" always means toward-camera-away, not a
# fixed world axis (which would flip meaning as the player turned). Camera
# yaw is 45°; its forward (from camera to scene) is -Basis(UP,45°).z, i.e.
# RIGHT rotated -90° about UP — verified against IsoCamera's fixed rig.
const CAM_FWD := Vector3(-0.707, 0.0, -0.707)
# The yaw the body's BILLBOARD_FIXED_Y visual settles into at this fixed
# camera (its quad turns to face the camera regardless of node yaw) — used so
# our manually-built basis matches the body's facing exactly. Verified via
# capture: a Basis(UP, 45°) frame (RIGHT/UP above) reproduces the same facing
# the billboard body renders at any parent rotation.y.
const CAM_FACING_YAW := deg_to_rad(45.0)

var _weapon_id: String = "sword"
var _parent_sprite: AnimatedSprite3D = null
var _base_offset := Vector2.ZERO  # unflipped grip-pivot offset; mirrored per flip state in _process

func _ready() -> void:
	top_level = true
	shaded = false
	no_depth_test = false
	centered = true
	_parent_sprite = get_parent() as AnimatedSprite3D

func set_weapon(id: String) -> void:
	_weapon_id = id
	var def: Dictionary = WeaponDB.get_def(id)
	var tex_path: String = def.get("overlay", "")
	var entry: Dictionary = _get_cropped(id, tex_path)
	if entry.is_empty():
		texture = null  # missing asset — guard lets everything else keep working
		return
	var tex: Texture2D = entry["tex"]
	texture = tex
	var h: int = tex.get_height()
	pixel_size = TARGET_WORLD_HEIGHT / float(h) if h > 0 else 0.0025
	# offset is in the sprite's own pixel space (pre pixel_size, pre rotation);
	# Sprite3D's local +Y is UP, but pixel space is Y-DOWN, so flip Y here to
	# move the pivot to the grip pixel rather than the texture center.
	var grip_px: Vector2 = entry["grip_px"]
	var center_px := Vector2(tex.get_width(), tex.get_height()) * 0.5
	var delta := grip_px - center_px
	_base_offset = Vector2(-delta.x, delta.y)
	offset = _base_offset

# Tight-crop the source texture to its non-transparent content bbox and
# locate the grip pixel (lower-left corner of that bbox, inset toward the
# content centroid by GRIP_INSET_FRAC of the bbox diagonal — the weapon art
# is drawn corner-to-corner, grip lower-left / tip upper-right, so the bbox's
# own lower-left corner IS approximately the grip before inset). Cached per
# weapon id so this only runs once per weapon per process lifetime.
func _get_cropped(id: String, tex_path: String) -> Dictionary:
	if _crop_cache.has(id):
		return _crop_cache[id]
	if tex_path == "" or not ResourceLoader.exists(tex_path):
		return {}
	var src_tex: Texture2D = load(tex_path)
	if src_tex == null:
		return {}
	var img: Image = src_tex.get_image()
	if img == null:
		return {}
	if img.is_compressed():
		img.decompress()
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return {}
	var cropped := Image.create(used.size.x, used.size.y, false, img.get_format())
	cropped.blit_rect(img, used, Vector2i.ZERO)
	var tex := ImageTexture.create_from_image(cropped)
	# Grip = bbox lower-left corner, inset along the diagonal toward the
	# content centroid so the pivot sits just inside the pommel, not on the
	# outermost edge pixel.
	var grip_local := Vector2(0.0, float(used.size.y - 1))
	var centroid := Vector2(used.size) * 0.5
	grip_local = grip_local.lerp(centroid, GRIP_INSET_FRAC)
	var entry := {"tex": tex, "grip_px": grip_local}
	_crop_cache[id] = entry
	return entry

func _process(_dt: float) -> void:
	if _parent_sprite == null:
		return
	visible = _should_show()
	if not visible:
		return
	var anchor := _current_anchor()
	var flip := _parent_sprite.flip_h
	var m := anchor.get("pos", Vector2.ZERO) as Vector2
	var rot: float = anchor.get("rot_deg", 0.0)
	# flip_h mirrors the TEXTURE but Godot does NOT mirror `offset`, so the
	# grip-pivot correction must be re-mirrored by hand; and the mirror of a
	# rotation across the vertical axis on a flipped texture is -rot (NOT
	# 180-rot, which points the blade down and was the "sword at his feet /
	# invisible when walking left" bug).
	if flip:
		m.x = -m.x
		rot = -rot
		offset = Vector2(-_base_offset.x, _base_offset.y)
	else:
		offset = _base_offset
	flip_h = flip
	var behind: bool = anchor.get("behind", false)
	# Sprite3D has no show_behind_parent (that's a Node2D thing) — instead nudge
	# along the camera-facing axis and use sorting_offset so the weapon draws
	# behind/in-front of the body billboard at the same world position. Both
	# flip states use the SAME sign convention (z_nudge/sorting_offset are not
	# mirrored) — "behind" means behind the body regardless of which hand the
	# sprite is flipped to, so flipping must never silently push the weapon
	# fully behind the body and out of view.
	var z_nudge := -0.01 if behind else 0.01
	# --- Camera-plane manual billboard (global transform, parent-yaw-independent) ---
	# top_level == true so we own our full world transform; build it from the
	# fixed camera-space axes (CAM_RIGHT/CAM_UP/CAM_FWD) rather than the local
	# position/rotation the parent's node rotation would otherwise skew. This
	# is what keeps the weapon glued to the body's BILLBOARD_FIXED_Y visual —
	# which itself ignores parent yaw — instead of orbiting the body as the
	# player turns (the "floating"/"disappearing" bug).
	var anchor_origin: Vector3 = _parent_sprite.global_position
	var facing_basis := Basis(CAM_UP, CAM_FACING_YAW)
	var roll_basis := Basis(Vector3(0, 0, 1), deg_to_rad(rot))
	global_transform = Transform3D(
		facing_basis * roll_basis,
		anchor_origin + CAM_RIGHT * m.x + CAM_UP * m.y + CAM_FWD * z_nudge
	)
	sorting_offset = -1.0 if behind else 1.0

func _should_show() -> bool:
	if _parent_sprite == null or _parent_sprite.animation == "death":
		return false
	if texture == null:
		return false
	return _weapon_id != "sword" or ResourceLoader.exists(BASE_SHEET_PROBE)

func _current_anchor() -> Dictionary:
	var anim: String = _parent_sprite.animation
	var frame: int = _parent_sprite.frame
	# Per-weapon anim override (e.g. spear/greatsword idle carried lower/further out).
	var overrides: Dictionary = WeaponDB.ANCHOR_OVERRIDES.get(_weapon_id, {})
	var list: Array = overrides.get(anim, ANCHORS.get(anim, ANCHORS["idle"]))
	if list.is_empty():
		list = ANCHORS["idle"]
	var idx: int = clampi(frame, 0, list.size() - 1)
	return list[idx]
