extends Node
## Global helpers + a seeded RNG so dungeon generation can be made
## deterministic from a run seed (mirrors the web build's mulberry32 routing).

var rng := RandomNumberGenerator.new()
var live := RandomNumberGenerator.new()   # always-random stream for cosmetics

func _ready() -> void:
	rng.randomize()
	live.randomize()

## Seed the generation stream from a string + floor depth (stable per floor).
func seed_floor(run_seed: String, depth: int) -> void:
	if run_seed == "":
		rng.randomize()
	else:
		rng.seed = (hash_str(run_seed) ^ (depth * 0x9E3779B1)) & 0x7fffffffffffffff

func rf(a: float, b: float) -> float:
	return a + rng.randf() * (b - a)

func ri(a: int, b: int) -> int:
	return rng.randi_range(a, b)

func chance(p: float) -> bool:
	return rng.randf() < p

## Cosmetic randomness (never affects deterministic layout).
func lf(a: float, b: float) -> float:
	return a + live.randf() * (b - a)

func li(a: int, b: int) -> int:
	return live.randi_range(a, b)

## Weighted pick from [[value, weight], ...]
func weighted(pool: Array) -> Variant:
	var total := 0.0
	for e in pool:
		total += float(e[1])
	var r := rng.randf() * total
	for e in pool:
		r -= float(e[1])
		if r < 0.0:
			return e[0]
	return pool[0][0]

func hash_str(s: String) -> int:
	var h := 2166136261
	for i in s.length():
		h = (h ^ s.unicode_at(i)) & 0xffffffff
		h = (h * 16777619) & 0xffffffff
	return h
