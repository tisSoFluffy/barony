extends SceneTree
## Generates editor-editable SpriteFrames .tres resources from SpriteFactory.CHAR_CONFIG,
## mirroring _build_frames() EXACTLY (same anim names, frame order, FPS, loop flags) so
## runtime playback via a loaded .tres is indistinguishable from the code-built path.
##
## Run after (re-)slicing sprite sheets:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s tools/gen_spriteframes.gd
##
## Re-runnable/idempotent — always overwrites res://frames/<character>.tres from current
## CHAR_CONFIG + sliced PNGs. Skips a character gracefully (prints a warning) if its
## sliced PNGs are missing.

const ANIM_FPS := 8.0  # must match SpriteFactory.ANIM_FPS

const OUT_DIR := "res://frames"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var factory_script: GDScript = load("res://scripts/autoload/SpriteFactory.gd")
	var char_config: Dictionary = factory_script.CHAR_CONFIG

	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var saved := 0
	var skipped := 0

	for character: String in char_config.keys():
		var cfg: Dictionary = char_config[character]
		var anims: Dictionary = cfg["anims"]

		# Verify sliced PNGs exist before building — check idle_0 as the canary.
		var canary := "res://sprites/sliced/%s/idle_0.png" % character
		if not ResourceLoader.exists(canary):
			push_warning("gen_spriteframes: skipping '%s' — missing %s" % [character, canary])
			skipped += 1
			continue

		var sf := SpriteFrames.new()
		sf.remove_animation("default")

		var missing_any := false
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
					push_warning("gen_spriteframes: missing %s" % path)
					missing_any = true

		var out_path := "%s/%s.tres" % [OUT_DIR, character]
		var err := ResourceSaver.save(sf, out_path)
		if err == OK:
			var frame_counts: Array = []
			for anim_name: String in anims.keys():
				frame_counts.append("%s=%d" % [anim_name, sf.get_frame_count(anim_name)])
			print("Saved %s  (%s)%s" % [out_path, ", ".join(frame_counts), " [warnings: missing frames]" if missing_any else ""])
			saved += 1
		else:
			push_error("gen_spriteframes: failed to save %s (err %d)" % [out_path, err])

	print("\ngen_spriteframes: %d saved, %d skipped." % [saved, skipped])
	print("Re-run this after re-slicing sprite sheets: Godot --headless --path godot -s tools/gen_spriteframes.gd")
	quit()
