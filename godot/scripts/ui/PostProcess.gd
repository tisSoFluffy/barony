extends CanvasLayer
## Fullscreen post-process: vignette + animated film grain.
## Sits above all world and UI layers. Built entirely in code.

const _SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.26;
uniform float grain_strength    : hint_range(0.0, 0.2) = 0.034;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;

    // Vignette — smooth radial darken from center to edges
    vec2  vc  = (uv - 0.5) * 2.0;
    float vig = pow(clamp(1.0 - dot(vc, vc) * 0.38, 0.0, 1.0), 1.8);
    float vig_alpha = (1.0 - vig) * vignette_strength;

    // Film grain — per-frame noise keyed on uv + time
    float noise = hash(uv + fract(TIME * 17.3));
    float grain = (noise - 0.5) * grain_strength;

    // Output: dark vignette + grain additive tint, no solid color
    COLOR = vec4(grain, grain, grain, vig_alpha + abs(grain) * 0.35);
}
"""


func _ready() -> void:
	layer = 20   # above HUD (10) and Inventory (15)

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = _SHADER

	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat

	add_child(rect)
