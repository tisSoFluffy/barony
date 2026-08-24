extends Node
## Global helpers + a seeded RNG so sector generation is deterministic from a
## run seed. Two streams: `rng` is seeded per (run, sector, run-index) so the
## "Procedural Glitch" is reproducible; `live` is always-random for cosmetics
## (particles, flicker) that must never affect layout.

var rng := RandomNumberGenerator.new()
var live := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	live.randomize()

## Seed the generation stream from the run seed, the sector id, and how many
## times the loop has reset (run_index). Later runs of the same sector generate
## harder/denser layouts — see SectorGen.difficulty().
func seed_sector(run_seed: String, sector_id: int, run_index: int) -> void:
	if run_seed == "":
		rng.randomize()
	else:
		var h := hash_str(run_seed)
		rng.seed = (h ^ (sector_id * 0x9E3779B1) ^ (run_index * 0x85EBCA77)) & 0x7fffffffffffffff

func rf(a: float, b: float) -> float:
	return a + rng.randf() * (b - a)

func ri(a: int, b: int) -> int:
	return rng.randi_range(a, b)

func chance(p: float) -> bool:
	return rng.randf() < p

func pick(arr: Array) -> Variant:
	return arr[rng.randi_range(0, arr.size() - 1)]

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

## FNV-1a string hash (stable across platforms; mirrors the web build).
func hash_str(s: String) -> int:
	var h := 2166136261
	for i in s.length():
		h = (h ^ s.unicode_at(i)) & 0xffffffff
		h = (h * 16777619) & 0xffffffff
	return h
