extends Node
## Procedural audio — every sound is synthesized to a PCM buffer at boot, so the
## game ships with zero audio files (matching the all-procedural ethos). SFX play
## through a small round-robin pool; a per-sector ambient drone loops underneath.
##
## Call from anywhere: `Audio.play("jump")`, `Audio.ambient(sector_id)`.

const RATE := 22050
const POOL := 8

var _sfx := {}                    # name -> AudioStreamWAV
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _amb: AudioStreamPlayer
var _amb_sector := -1

func _ready() -> void:
	_build_sfx()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "Master"
	_amb.volume_db = -14.0
	add_child(_amb)

## ---- Playback -------------------------------------------------------------

func play(name: String, pitch: float = 1.0, volume_db: float = -6.0) -> void:
	var s = _sfx.get(name, null)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = volume_db
	p.play()

func ambient(sector: int) -> void:
	if sector == _amb_sector:
		return
	_amb_sector = sector
	var key := "amb_%d" % sector
	var s = _sfx.get(key, null)
	if s == null:
		return
	_amb.stream = s
	_amb.play()

## ---- Synthesis ------------------------------------------------------------

func _build_sfx() -> void:
	# short one-shots
	_sfx["jump"] = _tone(0.12, func(t): return _blip(t, 320.0, 520.0))
	_sfx["dash"] = _tone(0.18, func(t): return _noise_swoosh(t))
	_sfx["strike"] = _tone(0.09, func(t): return _thud(t, 140.0))
	_sfx["hit"] = _tone(0.12, func(t): return _noise_env(t, 6.0))
	_sfx["pickup"] = _tone(0.16, func(t): return _blip(t, 660.0, 990.0))
	_sfx["unlock"] = _tone(0.42, func(t): return _chime(t))
	_sfx["explosion"] = _tone(0.36, func(t): return _boom(t))
	_sfx["strip"] = _tone(0.30, func(t): return _glitch_down(t))
	_sfx["death"] = _tone(0.60, func(t): return _down(t, 220.0, 60.0))
	# looping ambient drones, one per sector (pitched roots)
	var roots := [55.0, 62.0, 49.0, 41.0, 58.0]
	for i in roots.size():
		_sfx["amb_%d" % i] = _drone(1.6, roots[i])

## Build a 16-bit mono AudioStreamWAV from a per-sample function fn(t)->[-1,1].
func _tone(dur: float, fn: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(fn.call(t), -1.0, 1.0)
		_put_sample(bytes, i, v)
	return _wav(bytes, false, 0, 0)

## Looping drone with a smooth wrap so no click at the loop point.
func _drone(dur: float, root: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		# loopable: use integer harmonic cycles across the buffer
		var ph := TAU * t
		var v := 0.5 * sin(ph * root) + 0.3 * sin(ph * root * 2.0) + 0.14 * sin(ph * root * 0.5)
		v *= 0.5
		_put_sample(bytes, i, v)
	return _wav(bytes, true, 0, n - 1)

func _wav(bytes: PackedByteArray, loop: bool, loop_begin: int, loop_end: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = loop_begin
		w.loop_end = loop_end
	return w

func _put_sample(bytes: PackedByteArray, i: int, v: float) -> void:
	var s := int(clampf(v, -1.0, 1.0) * 32767.0)
	bytes[i * 2] = s & 0xff
	bytes[i * 2 + 1] = (s >> 8) & 0xff

## ---- Waveform recipes -----------------------------------------------------

func _env(t: float, dur: float) -> float:
	# quick attack, exponential-ish decay
	var a := clampf(t / 0.008, 0.0, 1.0)
	var d := clampf(1.0 - (t / dur), 0.0, 1.0)
	return a * d

func _blip(t: float, f0: float, f1: float) -> float:
	var f := lerpf(f0, f1, clampf(t / 0.12, 0.0, 1.0))
	return sin(TAU * f * t) * _env(t, 0.12)

func _thud(t: float, f: float) -> float:
	var sq := 1.0 if sin(TAU * f * t) >= 0.0 else -1.0
	return sq * _env(t, 0.09) * 0.9

func _noise_env(t: float, k: float) -> float:
	return (randf() * 2.0 - 1.0) * exp(-t * k)

func _noise_swoosh(t: float) -> float:
	var n := randf() * 2.0 - 1.0
	var band := sin(TAU * lerpf(180.0, 900.0, t / 0.18) * t)
	return (n * 0.6 + band * 0.4) * _env(t, 0.18)

func _chime(t: float) -> float:
	# two-note rising confirm
	var a := sin(TAU * 523.0 * t) * clampf(1.0 - t / 0.22, 0.0, 1.0)
	var b := 0.0
	if t > 0.16:
		b = sin(TAU * 784.0 * (t - 0.16)) * clampf(1.0 - (t - 0.16) / 0.26, 0.0, 1.0)
	return (a + b) * 0.6

func _boom(t: float) -> float:
	var low := sin(TAU * lerpf(120.0, 40.0, t / 0.36) * t)
	var n := (randf() * 2.0 - 1.0)
	return (low * 0.6 + n * 0.5) * exp(-t * 7.0)

func _glitch_down(t: float) -> float:
	var f := lerpf(700.0, 90.0, t / 0.30)
	var sq := 1.0 if sin(TAU * f * t) >= 0.0 else -1.0
	var bit := 1.0 if fmod(t * 60.0, 1.0) < 0.5 else 0.3
	return sq * bit * _env(t, 0.30)

func _down(t: float, f0: float, f1: float) -> float:
	var f := lerpf(f0, f1, clampf(t / 0.60, 0.0, 1.0))
	return sin(TAU * f * t) * clampf(1.0 - t / 0.60, 0.0, 1.0)
