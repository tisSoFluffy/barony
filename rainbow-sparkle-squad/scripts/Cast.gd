class_name Cast
extends RefCounted

## The four playable characters, as plain data.
##
## No model here is rigged, so nothing refers to bones or animation clips - the
## difference between them is entirely movement feel plus the procedural squash
## in Player.gd. Each one owns a distinct way of getting about, so swapping is a
## real choice rather than a change of hat:
##
##   Bouncy Blue    floats, double jump
##   Spotty Doggy   sprints, ground dash
##   Little Boo     drifts - the most airtime of the four, no dash
##   Rattly Bones   snappy and grounded - quickest to start and stop, falls hard
##
## `tint` multiplies into the model's albedo (see Player._apply_character).
## Color.WHITE means "leave the texture alone" and is the right answer for a
## character whose own texture already reads clearly.

const BOUNCY_BLUE := {
	"name": "Bouncy Blue",
	"model": "res://assets/models/bouncy_blue.glb",
	"tint": Color.WHITE,
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
	"tint": Color.WHITE,
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

## Reuses the Haunted House's happy ghost rather than generating a sixth one.
##
## The tint is doing real work: the island's five are washed pale grey
## (HauntedHouse.TINTS) and this one is a saturated blue, so the ghost a child
## is DRIVING never looks like the ghost a round is asking them to find. Without
## it the player would be an exact copy of the answer to "who looks happy?".
##
## The floatiest character. Bouncy Blue already hovers, so this one goes further
## in the same direction rather than sideways: slowest across the ground, but
## two mid-air hops and barely any gravity, which makes it the one to pick for
## the bounce pads and the star trail's high loops.
const LITTLE_BOO := {
	"name": "Little Boo",
	"model": "res://assets/models/ghost_happy.glb",
	"tint": Color(0.46, 0.68, 1.0),
	"height": 0.85,
	"speed": 5.5,
	"accel": 30.0,
	"friction": 18.0,      # drifts to a stop instead of planting
	"jump": 10.0,
	"air_jumps": 2,
	"gravity_scale": 0.55,
	"can_dash": false,
	"hop_hz": 1.8,         # glides rather than bounces
	"hop_height": 0.05,
}

## The opposite of Little Boo, which is the point of having both. No hang time
## at all and the hardest fall of the four, but the quickest to reach full speed
## and to stop dead - the one that actually lands on the numbered stars instead
## of sailing past them. The dash stays Spotty's alone.
const RATTLY_BONES := {
	"name": "Rattly Bones",
	"model": "res://assets/models/skeleton.glb",
	# Warm ivory rather than the bone white it is generated as. Untinted it
	# clipped to near-white over the meadow's bright green and lost its ribs,
	# its face and most of its silhouette - trap 4, and worse for a character
	# the player is supposed to be looking at the whole time. The warmth is
	# what keeps it reading as BONE and not as grey plastic once it is darkened.
	"tint": Color(0.78, 0.73, 0.60),
	"height": 0.90,
	"speed": 7.5,
	"accel": 70.0,
	"friction": 46.0,
	"jump": 8.8,
	"air_jumps": 0,
	"gravity_scale": 1.15,
	"can_dash": false,
	"hop_hz": 5.0,         # a fast bony clatter
	"hop_height": 0.05,
}

const ALL := [BOUNCY_BLUE, SPOTTY_DOGGY, LITTLE_BOO, RATTLY_BONES]
