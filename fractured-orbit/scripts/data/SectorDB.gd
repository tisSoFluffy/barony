extends Node
## The five vertical tiers of the Aethelgard. Each entry is the fixed "skeleton"
## metadata for a sector: its palette (drives all low-poly materials), the
## hazards and enemies eligible to spawn, the traversal gate it houses, and its
## lore. SectorGen randomizes room *content* within these fixed bounds so the
## map is roguelike inside a metroidvania spine.
##
## Palette keys map directly to the design brief's colour language:
##   floor/wall/trim  — the brutalist slab materials
##   accent           — glowing strips, safe-zone amber, danger neon
##   fog              — volumetric/atmosphere tint
##   danger           — hazard emissive
## Colours are deliberately slightly desaturated ("Deep Rock" charm).

const COUNT := 5

var _sectors := [
	{
		"id": 0,
		"key": "docking_bays",
		"name": "The Docking Bays",
		"tagline": "Industrial, rusty, crowded with cargo.",
		"palette": {
			"floor": Color("3a2f28"), "wall": Color("4a3b30"), "trim": Color("6b5540"),
			"accent": Color("ffb347"), "fog": Color("2a1f18"), "danger": Color("2a9df4"),
			"safe": Color("d98a3a"),
		},
		"hazards": ["falling_crate", "crumbling_walkway"],
		"enemies": ["scrap_crawler"],
		"gate": "magnet_boots",
		"boss": "",
		"rooms": Vector2i(5, 7),
		"vertical": 0.2,   # how much of the layout is vertical (0..1)
		"log": "Gravity stabilizers failing... we need to reach the Core before the ship implodes.",
	},
	{
		"id": 1,
		"key": "hydroponics",
		"name": "Hydroponics & Living Quarters",
		"tagline": "Overgrown, humid, claustrophobic.",
		"palette": {
			"floor": Color("22301f"), "wall": Color("2b3a26"), "trim": Color("3f5233"),
			"accent": Color("3ad98a"), "fog": Color("18240f"), "danger": Color("6ad94a"),
			"safe": Color("cfe08a"),
		},
		"hazards": ["spore_cloud", "thorn_wall"],
		"enemies": ["silence_guard"],
		"gate": "wall_run",
		"boss": "",
		"rooms": Vector2i(6, 9),
		"vertical": 0.5,
		"log": "The garden ate the stairwell. Climb the growth or stay below with the Silence.",
	},
	{
		"id": 2,
		"key": "engineering",
		"name": "The Engineering Core",
		"tagline": "High-tech, metallic, intense heat distortion.",
		"palette": {
			"floor": Color("2e3238"), "wall": Color("3a3f47"), "trim": Color("5a5560"),
			"accent": Color("2a9df4"), "fog": Color("1a1418"), "danger": Color("ff5a3a"),
			"safe": Color("d98a3a"),
		},
		"hazards": ["laser_grid", "pressure_plate", "molten_floor"],
		"enemies": ["drone_swarm", "turret_spider"],
		"gate": "kinetic_charge",
		"boss": "core_guardian",
		"rooms": Vector2i(6, 9),
		"vertical": 0.45,
		"log": "Don't trust the turrets. He died here.",
	},
	{
		"id": 3,
		"key": "void_silo",
		"name": "The Void Silo",
		"tagline": "Abandoned zero-G chambers open to the void.",
		"palette": {
			"floor": Color("0a0c14"), "wall": Color("10131f"), "trim": Color("1a2033"),
			"accent": Color("b06ad9"), "fog": Color("05060c"), "danger": Color("d94a8a"),
			"safe": Color("6a8adf"),
		},
		"hazards": ["zero_g_pocket", "black_hole_pit"],
		"enemies": ["void_leaper"],
		"gate": "zero_g_anchor",
		"boss": "",
		"rooms": Vector2i(5, 8),
		"vertical": 0.8,
		"log": "It isn't a cure. The Event Horizon is a trap. Join us, Loop-Walker.",
	},
	{
		"id": 4,
		"key": "event_horizon",
		"name": "The Event Horizon",
		"tagline": "Surreal, impossible geometry. Physics breaks.",
		"palette": {
			"floor": Color("f2f2f2"), "wall": Color("d8d8d8"), "trim": Color("101010"),
			"accent": Color("101010"), "fog": Color("cfcfcf"), "danger": Color("ff2a5a"),
			"safe": Color("8a8a8a"),
		},
		"hazards": ["reality_rift", "mirror_room"],
		"enemies": ["memory_construct"],
		"gate": "reality_bender",
		"boss": "nexus",
		"rooms": Vector2i(5, 7),
		"vertical": 0.6,
		"log": "You are the glitch. The world is trying to reject you. Rewrite it first.",
	},
]

func count() -> int:
	return _sectors.size()

func get_def(id: int) -> Dictionary:
	return _sectors[clampi(id, 0, _sectors.size() - 1)]

func palette(id: int) -> Dictionary:
	return get_def(id)["palette"]

func name_of(id: int) -> String:
	return String(get_def(id)["name"])
