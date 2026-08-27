class_name Cast
extends RefCounted

## The two playable characters, as plain data.
##
## Neither model is rigged, so nothing here refers to bones or animation
## clips - the difference between the two is entirely movement feel plus the
## procedural squash in Player.gd. Bouncy Blue floats, Spotty Doggy sprints.

const BOUNCY_BLUE := {
	"name": "Bouncy Blue",
	"model": "res://assets/models/bouncy_blue.glb",
	"tint": Color(0.42, 0.78, 0.95),
	"height": 0.85,
	"speed": 6.0,
	"accel": 40.0,
	"friction": 26.0,
	"jump": 9.5,
	"air_jumps": 1,        # the unicorn gets a second, floaty hop
	"gravity_scale": 0.72, # and falls slowly, so airtime reads as hovering
	"can_dash": false,
	"hop_hz": 2.6,         # bob frequency while running
	"hop_height": 0.10,
}

const SPOTTY_DOGGY := {
	"name": "Spotty Doggy",
	"model": "res://assets/models/spotty_doggy.glb",
	"tint": Color(0.98, 0.86, 0.66),
	"height": 0.80,
	"speed": 8.5,
	"accel": 55.0,
	"friction": 34.0,
	"jump": 8.0,
	"air_jumps": 0,
	"gravity_scale": 1.0,
	"can_dash": true,      # the dog trades hang time for a ground burst
	"hop_hz": 4.2,
	"hop_height": 0.07,
}

const ALL := [BOUNCY_BLUE, SPOTTY_DOGGY]
