extends Node3D

@export var base_energy: float = 3.5

var _omni_light: OmniLight3D

func _ready() -> void:
	_omni_light = OmniLight3D.new()
	add_child(_omni_light)
	_omni_light.light_color = Color(1.0, 0.55, 0.15)
	_omni_light.light_energy = base_energy
	_omni_light.omni_range = 6.0
	_omni_light.omni_attenuation = 2.0
	_omni_light.shadow_enabled = true

func _process(_delta: float) -> void:
	# Cast ticks to float before multiplying to avoid integer truncation
	var t: float = float(Time.get_ticks_msec()) * 0.003
	var flicker_factor: float = sin(t) + randf_range(-0.08, 0.08)
	_omni_light.light_energy = clamp(base_energy + flicker_factor * 0.7, 2.8, 4.2)
	# Colors are immutable structs in GDScript 4 — rebuild rather than assign .g in place
	var green: float = clamp(0.55 + flicker_factor * 0.05, 0.50, 0.60)
	_omni_light.light_color = Color(1.0, green, 0.15)
