shader_type spatial;
// Deck plating, generated rather than textured.
//
// Two coordinate spaces on purpose:
//   * WORLD position drives the plate seams and grime, so plating runs unbroken
//     from a room out into its corridors instead of restarting per slab.
//   * MODEL position drives the painted markings, because those are meant to be
//     room-relative — one border per room whatever its size, and hazard
//     chevrons across each doorway threshold. `room_extent` is the room
//     footprint in metres; left at zero, the markings are skipped entirely.
render_mode cull_back;

uniform vec4 floor_color  : source_color = vec4(0.23, 0.18, 0.16, 1.0);
uniform vec4 trim_color   : source_color = vec4(0.42, 0.33, 0.25, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.70, 0.28, 1.0);
uniform vec2 room_extent  = vec2(0.0);
uniform float plate      = 3.2;    // metres between plate seams
uniform float seam_width = 0.045;
uniform float wear       = 1.0;
uniform float paint      = 0.75;   // marking opacity

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec3 l_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	l_pos = VERTEX;
}

float hash13(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
	           mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float seam(float v, float period, float width) {
	float d = abs(fract(v / period) - 0.5) * period;
	return 1.0 - smoothstep(width, width + 0.03, d);
}

void fragment() {
	float up = step(0.7, w_nrm.y);          // markings belong on the top face only

	float n = vnoise(w_pos * 1.4) * 0.6 + vnoise(w_pos * 4.6) * 0.4;
	float plates = max(seam(w_pos.x, plate, seam_width), seam(w_pos.z, plate, seam_width));
	// a finer tread grid inside each plate
	float tread = max(seam(w_pos.x, plate * 0.25, 0.012), seam(w_pos.z, plate * 0.25, 0.012));

	vec3 col = floor_color.rgb;
	col *= mix(1.0, mix(0.82, 1.14, n), wear);
	col = mix(col, trim_color.rgb * 0.45, plates * 0.8);
	col = mix(col, col * 1.12, tread * 0.5 * up);

	// ---- room-relative painted markings ----
	if (room_extent.x > 0.01) {
		vec2 ex = room_extent * 0.5;
		vec2 dv = ex - abs(l_pos.xz);
		float d = min(dv.x, dv.y);                       // distance to nearest wall
		float along = dv.x < dv.y ? l_pos.z : l_pos.x;   // run along that wall
		float door = 1.0 - step(1.5, abs(along));        // doorways are the central 3 m

		// safety border, broken where a doorway interrupts it
		float border = step(0.35, d) * (1.0 - step(0.55, d)) * (1.0 - door);
		// hazard chevrons across the threshold
		float bars = step(0.5, fract((l_pos.x + l_pos.z) * 1.4));
		float chevron = door * step(0.10, d) * (1.0 - step(0.75, d)) * bars;

		float mark = clamp(border + chevron, 0.0, 1.0) * up;
		// paint is scuffed by the same wear noise, so it does not look decal-clean
		col = mix(col, accent_color.rgb, mark * paint * mix(0.65, 1.0, n));
	}

	ALBEDO = col;
	ROUGHNESS = mix(0.72, 0.97, n);
	SPECULAR = 0.0;
}
