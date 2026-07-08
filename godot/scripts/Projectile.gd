extends Node3D
class_name Projectile
## A flying bolt/arrow/fireball. team "player" hits enemies; "enemy" hits the
## player. Carries pierce + lifesteal (heals owner on hit).

var team := "player"
var kind := "fire"
var dir := Vector3.FORWARD
var speed := 9.0
var dmg := 10
var pierce := 0
var life := 0.0
var ttl := 2.4
var owner_player: Node = null  # untyped: Player has no class_name, avoid load-order coupling
var shooter: Node = null  # enemy that fired this (team "enemy") — never damages itself
var _hit := {}
var _anim_t := 0.0
var _fireball_spr: Sprite3D = null
var _shadowbolt_spr: Sprite3D = null
var _tumble_spr: AnimatedSprite3D = null  # axe/bolt: 3-frame sliced sheets

static var _fireball_tex: ImageTexture = null
static var _shadowbolt_tex: ImageTexture = null

static func _build_shadowbolt_tex() -> ImageTexture:
	var f := FileAccess.open("res://sprites/warlock-projectile.png", FileAccess.READ)
	var img := Image.new()
	img.load_png_from_buffer(f.get_buffer(f.get_length()))
	f.close()
	img.convert(Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			if mx - mn < 0.12 and c.r > 0.3 and c.r < 0.92:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

static func _build_fireball_tex() -> ImageTexture:
	var f := FileAccess.open("res://sprites/fireball.png", FileAccess.READ)
	var img := Image.new()
	img.load_png_from_buffer(f.get_buffer(f.get_length()))
	f.close()
	img.convert(Image.FORMAT_RGBA8)
	# Gemini baked the checkerboard as actual grey pixels instead of alpha=0.
	# Strip them: low saturation + mid-brightness = background grey.
	# Fire pixels are highly saturated (orange/red/yellow) so they survive.
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			if mx - mn < 0.12 and c.r > 0.3 and c.r < 0.92:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

static var _tumble_frames_cache: Dictionary = {}  # kind -> SpriteFrames

static func _build_tumble_frames(kind: String) -> SpriteFrames:
	if _tumble_frames_cache.has(kind):
		return _tumble_frames_cache[kind]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("spin")
	sf.set_animation_speed("spin", 12.0 if kind == "axe" else 10.0)
	sf.set_animation_loop("spin", true)
	for i in range(3):
		var tex: Texture2D = load("res://sprites/sliced/projectiles/%s_%d.png" % [kind, i])
		if tex != null:
			sf.add_frame("spin", tex)
	_tumble_frames_cache[kind] = sf
	return sf

## Classes (ClassDB.gd) is not a registered autoload — guard the lookup so
## headless -s tests (and any context without the full autoload set) don't crash.
func _proj_data(k: String) -> Dictionary:
	var cdb := get_node_or_null("/root/Classes")
	if cdb == null:
		return {}
	return cdb.proj.get(k, {})

func _ready() -> void:
	var d: Dictionary = _proj_data(kind)
	var default_c2 := "c8b088" if kind == "axe" else ("b060ff" if kind == "bolt" else "ffd040")
	var default_c1 := "8a7048" if kind == "axe" else ("5a1a70" if kind == "bolt" else "ff5810")
	var c2: Color = Painter.hex(d.get("c2", default_c2))
	var c1: Color = Painter.hex(d.get("c1", default_c1))
	if kind == "fire":
		if not _fireball_tex:
			_fireball_tex = _build_fireball_tex()
		var spr := Sprite3D.new()
		spr.texture = _fireball_tex
		spr.hframes = 7
		spr.pixel_size = 4.9 / float(_fireball_tex.get_width())
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		spr.alpha_scissor_threshold = 0.1
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(spr)
		_fireball_spr = spr
	elif kind == "shadow":
		if not _shadowbolt_tex:
			_shadowbolt_tex = _build_shadowbolt_tex()
		var spr := Sprite3D.new()
		spr.texture = _shadowbolt_tex
		spr.hframes = 8
		spr.pixel_size = 5.6 / float(_shadowbolt_tex.get_width())
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		spr.alpha_scissor_threshold = 0.1
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(spr)
		_shadowbolt_spr = spr
	elif kind == "axe" or kind == "bolt":
		var spr := AnimatedSprite3D.new()
		spr.sprite_frames = _build_tumble_frames(kind)
		spr.pixel_size = 0.004
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.shaded = false
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(spr)
		spr.play("spin")
		_tumble_spr = spr
	else:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.26
		m.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c2
		mat.emission_enabled = true
		mat.emission = c1
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mat
		add_child(m)
	var default_glow := 0.0 if kind == "axe" else (0.8 if kind == "bolt" else 1.2)
	var glow: float = d.get("glow", default_glow)
	if glow > 0.0:
		var light := OmniLight3D.new()
		light.light_color = c1
		light.omni_range = 3.0
		light.light_energy = glow
		add_child(light)

func _physics_process(dt: float) -> void:
	_anim_t += dt
	if _fireball_spr:
		var cam := get_viewport().get_camera_3d()
		_fireball_spr.frame = int(_anim_t * 12.0) % 7
		_fireball_spr.flip_h = cam != null and dir.dot(cam.global_transform.basis.x) > 0
	if _shadowbolt_spr:
		var cam := get_viewport().get_camera_3d()
		_shadowbolt_spr.frame = int(_anim_t * 12.0) % 8
		_shadowbolt_spr.flip_h = cam != null and dir.dot(cam.global_transform.basis.x) > 0
	global_position += dir * speed * dt
	ttl -= dt
	# `Game` bare identifier is ambiguous (autoload singleton vs. the legacy,
	# unused scripts/Game.gd class of the same name) — look up the autoload
	# node explicitly and null-guard so this degrades gracefully wherever the
	# legacy is_wall()-based collision system isn't present (e.g. this project's
	# live TileLevel map, and headless tests).
	var legacy_game := get_node_or_null("/root/Game")
	var hit_wall: bool = legacy_game != null and legacy_game.has_method("is_wall") and legacy_game.is_wall(global_position)
	if ttl <= 0.0 or hit_wall:
		queue_free()
		return
	var grp := "enemy" if team == "player" else "player"
	for t in get_tree().get_nodes_in_group(grp):
		if _hit.has(t) or t == shooter:
			continue
		var tc: Vector3 = t.body_center() if t.has_method("body_center") else t.global_position + Vector3(0, 0.7, 0)
		if global_position.distance_to(tc) < 0.85:
			if team == "player":
				t.take_damage(dmg, Painter.hex(_proj_data(kind).get("trail", "ff9020")))
				if life > 0.0 and owner_player and is_instance_valid(owner_player):
					owner_player.heal(int(round(dmg * life)))
				if kind == "fire" and t.has_method("apply_burn"):
					t.apply_burn(dmg)
				if kind == "power" and "slow_t" in t:
					t.slow_t = maxf(t.slow_t, 1.5)
			else:
				t.take_damage(dmg, kind)
				if t.has_method("_apply_knockback"):
					t._apply_knockback(dir * 2.5)
			_hit[t] = true
			if pierce <= 0:
				queue_free()
				return
