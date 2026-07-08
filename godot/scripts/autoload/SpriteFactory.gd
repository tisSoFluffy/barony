extends Node
## Builds AnimatedSprite3D nodes from pre-sliced frame PNGs.
## Frames live at res://sprites/sliced/<character>/<anim>_<N>.png

const ANIM_FPS := 8.0

const CHAR_CONFIG: Dictionary = {
	"warrior": {
		"pixel_size": 0.0025,
		"anims": {
			"idle":   {"frames": 3, "loop": true},
			"walk":   {"frames": 3, "loop": true},
			"attack": {"frames": 3, "loop": false},
			"hurt":   {"frames": 2, "loop": false},
			"death":  {"frames": 5, "loop": false},
		},
	},
	# Weaponless rig for the paper-doll weapon overlay (WeaponOverlay.gd). Same
	# anim/frame layout and sliced proportions as "warrior" by construction
	# (see DEVLOG 2026-07-02 sprite entry) so pixel_size matches 1:1.
	"warrior-base": {
		"pixel_size": 0.0025,
		"anims": {
			"idle":   {"frames": 3, "loop": true},
			"walk":   {"frames": 3, "loop": true},
			"attack": {"frames": 3, "loop": false},
			"hurt":   {"frames": 2, "loop": false},
			"death":  {"frames": 5, "loop": false},
		},
	},
	"kobold": {
		"pixel_size": 0.002,
		"anims": {
			"idle":   {"frames": 3, "loop": true},
			"walk":   {"frames": 3, "loop": true},
			"attack": {"frames": 3, "loop": false},
			"hurt":   {"frames": 2, "loop": false},
			"death":  {"frames": 5, "loop": false},
		},
	},
	"murloc": {
		"pixel_size": 0.002,
		"anims": {
			"idle":   {"frames": 3, "loop": true},
			"walk":   {"frames": 3, "loop": true},
			"attack": {"frames": 3, "loop": false},
			"hurt":   {"frames": 2, "loop": false},
			"death":  {"frames": 5, "loop": false},
		},
	},
	"skeleton": {
		"pixel_size": 0.0015,
		"anims": {
			"idle":   {"frames": 3, "loop": true},
			"walk":   {"frames": 3, "loop": true},
			"attack": {"frames": 3, "loop": false},
			"hurt":   {"frames": 2, "loop": false},
			"death":  {"frames": 5, "loop": false},
		},
	},
	"orc": {
		"pixel_size": 0.0015,
		"anims": {
			"idle":   {"frames": 3, "loop": true},
			"walk":   {"frames": 3, "loop": true},
			"attack": {"frames": 3, "loop": false},
			"hurt":   {"frames": 2, "loop": false},
			"death":  {"frames": 5, "loop": false},
		},
	},
	"troll": {
		"pixel_size": 0.0015,
		"anims": {
			"idle":   {"frames": 3, "loop": true},
			"walk":   {"frames": 3, "loop": true},
			"attack": {"frames": 3, "loop": false},
			"hurt":   {"frames": 2, "loop": false},
			"death":  {"frames": 5, "loop": false},
		},
	},
	"necro": {
		"pixel_size": 0.0015,
		"anims": {
			"idle":   {"frames": 3, "loop": true},
			"walk":   {"frames": 3, "loop": true},
			"attack": {"frames": 3, "loop": false},
			"hurt":   {"frames": 2, "loop": false},
			"death":  {"frames": 5, "loop": false},
		},
	},
	"gormaul": {
		"pixel_size": 0.0008,
		"anims": {
			"idle":   {"frames": 3, "loop": true},
			"walk":   {"frames": 3, "loop": true},
			"attack": {"frames": 3, "loop": false},
			"hurt":   {"frames": 2, "loop": false},
			"death":  {"frames": 5, "loop": false},
		},
	},
}


func make_sprite(character: String) -> AnimatedSprite3D:
	var cfg: Dictionary = CHAR_CONFIG.get(character, {})
	if cfg.is_empty():
		push_warning("SpriteFactory: no config for '%s' — returning blank sprite" % character)
		return AnimatedSprite3D.new()

	var sprite := AnimatedSprite3D.new()
	configure_sprite(sprite, character)
	return sprite


# Applies all runtime sprite config to an EXISTING AnimatedSprite3D. Used both by
# make_sprite (code-built path — enemies, and the player when `.new()`'d in tests)
# and by scene-instantiated sprites: Player.tscn ships an editable AnimatedSprite3D
# node (so animations preview in the editor); Player.gd calls this to bring its
# runtime state in line with the code path. Single source of truth either way.
func configure_sprite(sprite: AnimatedSprite3D, character: String) -> void:
	var cfg: Dictionary = CHAR_CONFIG.get(character, {})
	if cfg.is_empty():
		push_warning("SpriteFactory: no config for '%s'" % character)
		return
	var ps: float = cfg["pixel_size"]
	sprite.pixel_size = ps
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false          # HD 2D: sprites are pre-lit 2D art, not scene-lit
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Dual-mode: prefer the editor-editable .tres (tools/gen_spriteframes.gd output) so
	# animations are inspectable/previewable in the editor; fall back to the code-built
	# path if a character hasn't been generated yet (or its .tres was deleted).
	var frames_path := "res://frames/%s.tres" % character
	if ResourceLoader.exists(frames_path):
		sprite.sprite_frames = load(frames_path)
	else:
		sprite.sprite_frames = _build_frames(character, cfg["anims"])

	# Lift sprite so feet rest on y=0. Use first idle frame height as reference.
	var idle_tex: Texture2D = sprite.sprite_frames.get_frame_texture("idle", 0)
	if idle_tex != null:
		sprite.position.y = idle_tex.get_height() * ps * 0.5

	sprite.play("idle")


func _build_frames(character: String, anims: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	for anim_name: String in anims.keys():
		var a: Dictionary = anims[anim_name]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, ANIM_FPS)
		sf.set_animation_loop(anim_name, a["loop"])

		for i: int in a["frames"]:
			var path := "res://sprites/sliced/%s/%s_%d.png" % [character, anim_name, i]
			var tex: Texture2D = load(path)
			if tex != null:
				sf.add_frame(anim_name, tex)
			else:
				push_warning("SpriteFactory: missing %s" % path)

	return sf
