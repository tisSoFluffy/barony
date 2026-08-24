shader_type spatial;
// Event Horizon "reality break" look: geometry flickers between a solid
// negative-space slab and a black wireframe grid, with occasional glitch
// displacement — the design's 3D<->2D wireframe flicker in one material.
render_mode cull_back, unshaded;

uniform vec4 solid_color : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform vec4 wire_color  : source_color = vec4(0.06, 0.06, 0.06, 1.0);
uniform vec4 fault_color : source_color = vec4(1.0, 0.16, 0.35, 1.0);
uniform float grid_scale = 6.0;     // wireframe cells per face
uniform float line_width = 0.045;   // wireframe line thickness
uniform float glitch_rate = 0.7;    // negative-space flip speed
uniform float jitter_amt  = 0.06;   // vertex displacement strength

float hash(float n) { return fract(sin(n) * 43758.5453123); }

void vertex() {
	// intermittent glitch: shear a band of the mesh sideways for a few frames
	float t = TIME;
	float band = step(0.93, hash(floor(VERTEX.y * 8.0) + floor(t * 6.0)));
	VERTEX.x += band * jitter_amt * sin(t * 40.0 + VERTEX.y);
}

void fragment() {
	// wireframe grid from UVs
	vec2 g = abs(fract(UV * grid_scale) - 0.5);
	float d = min(g.x, g.y);
	float line = 1.0 - smoothstep(line_width, line_width + 0.02, d);

	// negative-space flip: solid<->inverted on a slow flicker
	float flip = step(0.5, fract(TIME * glitch_rate));
	vec3 fill = mix(solid_color.rgb, wire_color.rgb, flip);
	vec3 wire = mix(wire_color.rgb, solid_color.rgb, flip);

	vec3 col = mix(fill, wire, line);

	// rare scanline fault in danger red
	float fault = step(0.985, fract(UV.y * 3.0 + TIME * 1.7));
	col = mix(col, fault_color.rgb, fault * 0.8);

	ALBEDO = col;
	EMISSION = col * (0.35 + line * 0.4 + fault * 0.6);
}
