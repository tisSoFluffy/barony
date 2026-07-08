extends Node3D
class_name Waterfall

const FRAMES := 6
const FPS    := 8.0
const WORLD_H := 3.8

static var _tex: ImageTexture = null

static func _build_tex() -> ImageTexture:
	var f := FileAccess.open("res://sprites/waterfall.png", FileAccess.READ)
	var img := Image.new()
	img.load_png_from_buffer(f.get_buffer(f.get_length()))
	f.close()
	img.convert(Image.FORMAT_RGBA8)
	# Strip the hot-pink (#FF00FF) background Gemini baked in.
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.r > 0.7 and c.b > 0.7 and c.g < 0.3:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func setup(ground_pos: Vector3) -> void:
	position = ground_pos
	if not _tex:
		_tex = _build_tex()

	var spr := Sprite3D.new()
	spr.name = "Sprite3D"
	spr.texture = _tex
	spr.hframes = FRAMES
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.shaded = false
	spr.pixel_size = WORLD_H / float(_tex.get_height())
	spr.position = Vector3(0, WORLD_H / 2.0, 0)
	add_child(spr)

	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 0.8, 1.0)
	light.omni_range = 5.0
	light.light_energy = 0.8
	light.position = Vector3(0, WORLD_H * 0.5, 0)
	add_child(light)

	# AnimationPlayer keyframes Sprite3D.frame 0 → FRAMES-1, looping.
	# root_node default ".." resolves to this Node3D, so the track path
	# "Sprite3D:frame" finds the sprite added above.
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = float(FRAMES) / FPS
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("Sprite3D:frame"))
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	for i in range(FRAMES):
		anim.track_insert_key(track, float(i) / FPS, i)

	var lib := AnimationLibrary.new()
	lib.add_animation("flow", anim)
	var ap := AnimationPlayer.new()
	ap.add_animation_library("", lib)
	add_child(ap)
	ap.play("flow")
