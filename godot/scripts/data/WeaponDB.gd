extends Node
## Weapon data, static-lib style (mirrors ClassDB/EnemyDB). Autoload name: WeaponDB
##
## Each entry tunes the player's melee path (Player._melee / _resolve_melee_hit):
##   dmg_mult      - multiplies tot_dmg() (and whirlwind/charge damage)
##   cd            - attack cooldown / swing duration (replaces the hardcoded 0.45)
##   reach_bonus   - added on top of the per-enemy reach (MELEE_REACH_MARGIN baseline)
##   arc           - "normal" (120° soft-lock cone, existing behavior), "narrow" (tight
##                   cone, dot > 0.75 — spear-like poke), "wide" (dot > -0.2, hits up to
##                   3 nearest enemies in the cone — greatsword sweep)
##   stagger_mult  - multiplies the poise damage applied per hit (Enemy._poise_cur -= amt*0.8*mult)
##   knockback_mult- multiplies the knockback impulse magnitude
##   crit_bonus    - added to CRIT_CHANCE.war before rolling _pending_crit
##   stam_mult     - multiplies STAM_ATK (stamina cost per swing)
##   overlay       - texture path for the paper-doll WeaponOverlay Sprite3D

const DEFAULT_ID := "sword"

const defs: Dictionary = {
	"sword": {
		"name": "Longsword", "dmg_mult": 1.0, "cd": 0.45, "reach_bonus": 0.0, "arc": "normal",
		"stagger_mult": 1.0, "knockback_mult": 1.0, "crit_bonus": 0.0, "stam_mult": 1.0,
		"overlay": "res://sprites/weapon-sword.png",
	},
	"spear": {
		"name": "Spear", "dmg_mult": 0.9, "cd": 0.50, "reach_bonus": 0.8, "arc": "narrow",
		"stagger_mult": 1.0, "knockback_mult": 1.0, "crit_bonus": 0.0, "stam_mult": 1.0,
		"overlay": "res://sprites/weapon-spear.png", "trail": "thrust",
	},
	"mace": {
		"name": "Mace", "dmg_mult": 1.1, "cd": 0.55, "reach_bonus": 0.0, "arc": "normal",
		"stagger_mult": 2.0, "knockback_mult": 1.2, "crit_bonus": 0.0, "stam_mult": 1.1,
		"overlay": "res://sprites/weapon-mace.png", "trail": "arc",
	},
	"flail": {
		"name": "Flail", "dmg_mult": 1.05, "cd": 0.60, "reach_bonus": 0.15, "arc": "normal",
		"stagger_mult": 1.2, "knockback_mult": 1.8, "crit_bonus": 0.0, "stam_mult": 1.15,
		"overlay": "res://sprites/weapon-flail.png", "trail": "arc",
	},
	"greatsword": {
		"name": "Greatsword", "dmg_mult": 1.5, "cd": 0.80, "reach_bonus": 0.3, "arc": "wide",
		"stagger_mult": 1.5, "knockback_mult": 1.3, "crit_bonus": 0.0, "stam_mult": 1.5,
		"overlay": "res://sprites/weapon-greatsword.png", "trail": "arc",
	},
	"dagger": {
		"name": "Dagger", "dmg_mult": 0.6, "cd": 0.25, "reach_bonus": -0.3, "arc": "normal",
		"stagger_mult": 0.7, "knockback_mult": 0.6, "crit_bonus": 0.25, "stam_mult": 0.7,
		"overlay": "res://sprites/weapon-dagger.png", "trail": "thrust",
	},
}

# Per-anim paper-doll anchors, keyed by weapon id then anim name then frame index.
# Each anchor: {pos: Vector2 (local WORLD-SPACE meters offset), rot_deg: float, behind: bool}.
# Weapons without a specific anim fall back to WeaponOverlay's generic ANCHORS default
# (grip position measured off the baked warrior sword sheet — see WeaponOverlay.gd).
# Sword has none (it IS the shared ANCHORS default). Every other weapon gets its
# own idle/walk/attack/hurt profile so each weapon's motion silhouette reads
# distinctly: spear/dagger = straight-line thrust/jab, mace/flail = overhead-ish
# chop/diagonal swing, greatsword = shoulder-carry + huge horizontal sweep.
const ANCHOR_OVERRIDES: Dictionary = {
	"spear": {
		# Two-hand thrust, carried more upright than the sword.
		"idle": [
			{"pos": Vector2(-0.17, -0.02), "rot_deg": -85.0, "behind": false},
		],
		"walk": [
			{"pos": Vector2(-0.48, 0.10), "rot_deg": -82.0, "behind": false},
			{"pos": Vector2(-0.45, 0.14), "rot_deg": -80.0, "behind": false},
			{"pos": Vector2(-0.48, 0.10), "rot_deg": -82.0, "behind": false},
		],
		"attack": [
			{"pos": Vector2(-0.55, -0.05), "rot_deg": -15.0, "behind": false},  # cocked back at hip
			{"pos": Vector2(-0.10, 0.02),  "rot_deg": 0.0,   "behind": false},  # full thrust, far forward
			{"pos": Vector2(-0.35, -0.02), "rot_deg": -10.0, "behind": false},  # partial recover
		],
		"hurt": [
			{"pos": Vector2(-0.17, -0.02), "rot_deg": -85.0, "behind": true},
		],
	},
	"mace": {
		# Overhead chop.
		"idle": [
			{"pos": Vector2(-0.17, -0.10), "rot_deg": -70.0, "behind": false},
		],
		"walk": [
			{"pos": Vector2(-0.50, 0.03),  "rot_deg": -66.0, "behind": false},
			{"pos": Vector2(-0.47, 0.07),  "rot_deg": -60.0, "behind": false},
			{"pos": Vector2(-0.50, 0.03),  "rot_deg": -66.0, "behind": false},
		],
		"attack": [
			{"pos": Vector2(-0.45, 0.30),  "rot_deg": 35.0,  "behind": false},  # raised high overhead
			{"pos": Vector2(-0.40, -0.10), "rot_deg": -95.0, "behind": false},  # slammed down-forward
			{"pos": Vector2(-0.42, -0.14), "rot_deg": -80.0, "behind": false},  # low recover
		],
		"hurt": [
			{"pos": Vector2(-0.17, -0.10), "rot_deg": -70.0, "behind": true},
		],
	},
	"flail": {
		# Wide diagonal swing, slightly larger excursions (chain reach).
		"idle": [
			{"pos": Vector2(-0.19, -0.10), "rot_deg": -72.0, "behind": false},
		],
		"walk": [
			{"pos": Vector2(-0.54, 0.03),  "rot_deg": -66.0, "behind": false},
			{"pos": Vector2(-0.50, 0.08),  "rot_deg": -58.0, "behind": false},
			{"pos": Vector2(-0.54, 0.03),  "rot_deg": -66.0, "behind": false},
		],
		"attack": [
			{"pos": Vector2(-0.48, 0.32),  "rot_deg": 45.0,  "behind": false},  # cocked high-back
			{"pos": Vector2(-0.55, 0.05),  "rot_deg": -30.0, "behind": false},  # sweeping through mid
			{"pos": Vector2(-0.40, -0.16), "rot_deg": -110.0,"behind": false},  # follow-through low-forward
		],
		"hurt": [
			{"pos": Vector2(-0.19, -0.10), "rot_deg": -72.0, "behind": true},
		],
	},
	"greatsword": {
		# Slung on the shoulder at rest; huge horizontal sweep on attack.
		"idle": [
			{"pos": Vector2(-0.05, 0.18), "rot_deg": 25.0, "behind": true},
		],
		"walk": [
			{"pos": Vector2(-0.30, 0.28), "rot_deg": 28.0, "behind": true},
			{"pos": Vector2(-0.27, 0.32), "rot_deg": 22.0, "behind": true},
			{"pos": Vector2(-0.30, 0.28), "rot_deg": 28.0, "behind": true},
		],
		"attack": [
			{"pos": Vector2(-0.10, 0.30), "rot_deg": 60.0,  "behind": true},   # wound far back over shoulder
			{"pos": Vector2(-0.55, 0.05), "rot_deg": -20.0, "behind": false},  # full extension mid-sweep front
			{"pos": Vector2(-0.30, -0.15),"rot_deg": -120.0,"behind": false},  # wide follow-through opposite side
		],
		"hurt": [
			{"pos": Vector2(-0.05, 0.18), "rot_deg": 25.0, "behind": true},
		],
	},
	"dagger": {
		# Quick jab, tight/low, small excursions.
		"idle": [
			{"pos": Vector2(-0.15, -0.16), "rot_deg": -100.0, "behind": false},
		],
		"walk": [
			{"pos": Vector2(-0.42, -0.05), "rot_deg": -92.0, "behind": false},
			{"pos": Vector2(-0.40, -0.02), "rot_deg": -88.0, "behind": false},
			{"pos": Vector2(-0.42, -0.05), "rot_deg": -92.0, "behind": false},
		],
		"attack": [
			{"pos": Vector2(-0.30, -0.18), "rot_deg": -75.0, "behind": false},  # tiny pullback
			{"pos": Vector2(-0.10, -0.12), "rot_deg": -50.0, "behind": false},  # short fast extend
			{"pos": Vector2(-0.22, -0.16), "rot_deg": -85.0, "behind": false},  # near-instant recover
		],
		"hurt": [
			{"pos": Vector2(-0.15, -0.16), "rot_deg": -100.0, "behind": true},
		],
	},
}

func get_def(id: String) -> Dictionary:
	return defs.get(id, defs[DEFAULT_ID])

func ids() -> Array:
	return defs.keys()
