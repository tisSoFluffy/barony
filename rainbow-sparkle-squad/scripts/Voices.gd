class_name Voices
extends RefCounted

## The spoken numbers, shared by everything that counts.
##
## Rendered by tools/make_count_voices.ps1 with the built-in Windows voice.
## Both the star trail in the meadow and the Numberblocks in Blockland say the
## same "One!" .. "Ten!", so the clips live here rather than in either one.

const NUMBERS: Array[AudioStream] = [
	preload("res://assets/audio/count_01.wav"),
	preload("res://assets/audio/count_02.wav"),
	preload("res://assets/audio/count_03.wav"),
	preload("res://assets/audio/count_04.wav"),
	preload("res://assets/audio/count_05.wav"),
	preload("res://assets/audio/count_06.wav"),
	preload("res://assets/audio/count_07.wav"),
	preload("res://assets/audio/count_08.wav"),
	preload("res://assets/audio/count_09.wav"),
	preload("res://assets/audio/count_10.wav"),
]


## Say `n` (1..10) on `player`. Playing on one shared player means a quick run
## of numbers cuts to the newest rather than piling up into mush.
static func say(player: AudioStreamPlayer, n: int) -> void:
	if player == null:
		return
	player.stream = NUMBERS[clampi(n - 1, 0, NUMBERS.size() - 1)]
	player.play()
