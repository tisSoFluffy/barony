extends RefCounted
class_name EnemyAnim
## Sprite-sheet animation definitions for enemies with a real PNG sheet.
## Enemies without an entry here fall back to the procedural single-frame art.
##
## Clip layout: start/end are linear frame indices (row-major, 0-based).
##   frame = row * hf + col

static func get_def(type: String) -> Dictionary:
	match type:
		"kobold":
			# 784x1360 — 4 cols x 7 rows = 28 frames, 196x194 each
			# Rows 0-4: walk S/SW/W/NW/N  Row 5 (20-23): attack  Row 6 (24-27): hurt+dead
			return {
				"path": "res://sprites/kobold.png",
				"hf": 4, "vf": 7,
				"clips": {
					"idle":   {"start": 0,  "end": 1,  "fps": 2.0,  "loop": true},
					"walk":   {"start": 0,  "end": 3,  "fps": 6.0,  "loop": true,
					           "dir_starts": [0, 4, 8, 12, 16]},
					"attack": {"start": 20, "end": 23, "fps": 10.0, "loop": false},
					"hurt":   {"start": 24, "end": 24, "fps": 6.0,  "loop": false},
					"dead":   {"start": 25, "end": 27, "fps": 4.0,  "loop": false},
				}
			}
		"orc":
			# 1128x768 — 6 cols x 3 rows = 18 frames, 188x256 each
			# Row 0 (0-5): walk cycle  Row 1 (6-11): aggressive/attack  Row 2 (12-17): hit + hurt + dead
			return {
				"path": "res://sprites/orc.png",
				"hf": 6, "vf": 3,
				"clips": {
					"idle":   {"start": 0,  "end": 1,  "fps": 2.0,  "loop": true},
					"walk":   {"start": 0,  "end": 5,  "fps": 8.0,  "loop": true},
					"attack": {"start": 6,  "end": 11, "fps": 10.0, "loop": false},
					"hurt":   {"start": 12, "end": 12, "fps": 6.0,  "loop": false},
					"dead":   {"start": 13, "end": 17, "fps": 5.0,  "loop": false},
				}
			}
		"murloc":
			# 1408x768 — 4 cols x 2 rows = 8 frames, 352x384 each
			# Row 0: walk cycle  Row 1: attack lunge + hurt/dead
			return {
				"path": "res://sprites/murloc.png",
				"hf": 4, "vf": 2,
				"clips": {
					"idle":   {"start": 0, "end": 1, "fps": 2.0,  "loop": true},
					"walk":   {"start": 0, "end": 3, "fps": 8.0,  "loop": true},
					"attack": {"start": 4, "end": 6, "fps": 10.0, "loop": false},
					"hurt":   {"start": 7, "end": 7, "fps": 6.0,  "loop": false},
					"dead":   {"start": 6, "end": 7, "fps": 4.0,  "loop": false},
				}
			}
		"skeleton":
			# 1380x752 — 8 cols x 4 rows = 32 frames, ~172x188 each
			# Row 0 (0-7): walk S   Row 1 (8-15): walk W (side)
			# Row 2 (16-23): attack  Row 3 (24-31): hurt + dead
			# NW/N mirror W/S via flip_h
			return {
				"path": "res://sprites/skeleton.png",
				"hf": 8, "vf": 4,
				"clips": {
					"idle":   {"start": 0,  "end": 1,  "fps": 2.0,  "loop": true},
					"walk":   {"start": 0,  "end": 7,  "fps": 8.0,  "loop": true,
					           "dir_starts": [0, 8, 8, 8, 0]},
					"attack": {"start": 16, "end": 22, "fps": 10.0, "loop": false},
					"hurt":   {"start": 23, "end": 23, "fps": 6.0,  "loop": false},
					"dead":   {"start": 24, "end": 31, "fps": 4.0,  "loop": false},
				}
			}
		"necro":
			# 784x1360 — 4 cols x 7 rows = 28 frames, 196x194 each
			# Rows 0-4: walk S/SW/W/NW/N  Row 5 (20-23): attack  Row 6 (24-27): hurt+dead
			return {
				"path": "res://sprites/necro.png",
				"hf": 4, "vf": 7,
				"clips": {
					"idle":   {"start": 0,  "end": 1,  "fps": 2.0,  "loop": true},
					"walk":   {"start": 0,  "end": 3,  "fps": 6.0,  "loop": true,
					           "dir_starts": [0, 4, 8, 12, 16]},
					"attack": {"start": 20, "end": 23, "fps": 10.0, "loop": false},
					"hurt":   {"start": 24, "end": 24, "fps": 6.0,  "loop": false},
					"dead":   {"start": 25, "end": 27, "fps": 4.0,  "loop": false},
				}
			}
		"troll":
			# 1408x768 — 8 cols x 4 rows = 32 frames, 176x192 each
			# Row 0 (0-7): walk S  Row 1 (8-15): walk W (side view)
			# Row 2 (16-23): attack  Row 3 (24-31): hurt + dead
			# NW/N mirror W/S via flip_h; SW also uses W row
			return {
				"path": "res://sprites/troll.png",
				"hf": 8, "vf": 4,
				"clips": {
					"idle":   {"start": 0,  "end": 1,  "fps": 2.0,  "loop": true},
					"walk":   {"start": 0,  "end": 7,  "fps": 8.0,  "loop": true,
					           "dir_starts": [0, 8, 8, 8, 0]},
					"attack": {"start": 16, "end": 22, "fps": 10.0, "loop": false},
					"hurt":   {"start": 23, "end": 23, "fps": 6.0,  "loop": false},
					"dead":   {"start": 24, "end": 31, "fps": 4.0,  "loop": false},
				}
			}
		"ogre":
			# 1370x768 — 10 cols x 6 rows = 60 frames, 137x128 each
			# Rows 0-2: walk S/SW/W (10 frames each); SW mirrors for NW, S mirrors for N
			# Row 3 (30-39): attack  Row 4 (40-49): hurt  Row 5 (50-59): dead
			return {
				"path": "res://sprites/ogre.png",
				"hf": 10, "vf": 6,
				"clips": {
					"idle":   {"start": 0,  "end": 1,  "fps": 2.0,  "loop": true},
					"walk":   {"start": 0,  "end": 9,  "fps": 8.0,  "loop": true,
					           "dir_starts": [0, 10, 20, 10, 0]},
					"attack": {"start": 30, "end": 37, "fps": 10.0, "loop": false},
					"hurt":   {"start": 40, "end": 40, "fps": 6.0,  "loop": false},
					"dead":   {"start": 50, "end": 57, "fps": 5.0,  "loop": false},
				}
			}
	return {}
