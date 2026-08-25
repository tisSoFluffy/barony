shader_type spatial;
// Brutalist wall surface, generated rather than textured.
//
// Wall slabs are BoxMeshes built at runtime sizes, and a BoxMesh maps UV 0..1
// per face — so a bitmap would stretch to fit each segment and a 3 m stub would
// show it at four times the density of a 12 m run. Everything here is driven by
// WORLD position instead, so a stub and a long wall carry the same surface, and
// the sector palette tints it rather than needing one texture set per sector.
render_mode cull_back;

uniform vec4 wall_color   : source_color = vec4(0.29, 0.23, 0.19, 1.0);
uniform vec4 trim_color   : source_color = vec4(0.42, 0.33, 0.25, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.70, 0.28, 1.0);
uniform float panel_h    = 1.55;   // metres between horizontal panel seams
uniform float panel_w    = 2.40;   // metres between vertical panel seams
uniform float seam_width = 0.035;  // half-thickness of a seam, in metres
uniform float grime      = 1.0;    // 0 disables the mottling
uniform float foot_shade = 0.55;   // metres of grubby darkening at floor level

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash13(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Value noise in 3D. Being volumetric, it needs no triplanar blend: it is
// already continuous across every face of every slab, so wall corners meet
// without a seam.
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

// 1.0 on a seam line, falling off over ~3 cm.
float seam(float v, float period, float width) {
	float d = abs(fract(v / period) - 0.5) * period;
	return 1.0 - smoothstep(width, width + 0.03, d);
}

void fragment() {
	// In-plane horizontal axis, chosen from the face normal: a wall facing X
	// runs along Z and vice versa. Cheaper than a full triplanar blend and
	// exact for axis-aligned slabs, which is all this game builds.
	float horiz = mix(w_pos.x, w_pos.z, step(abs(w_nrm.z), abs(w_nrm.x)));

	float n = vnoise(w_pos * 1.7) * 0.62 + vnoise(w_pos * 5.3) * 0.38;
	float lines = max(seam(w_pos.y, panel_h, seam_width),
	                  seam(horiz, panel_w, seam_width));
	float foot = 1.0 - smoothstep(0.0, foot_shade, w_pos.y);
	float fleck = smoothstep(0.87, 0.99, vnoise(w_pos * 11.0));

	vec3 col = wall_color.rgb;
	col *= mix(1.0, mix(0.84, 1.12, n), grime);
	col = mix(col, trim_color.rgb * 0.40, lines * 0.85);   // recessed seams
	col = mix(col, col * 0.55, foot * 0.85);               // grime at the base
	col = mix(col, accent_color.rgb, fleck * 0.10);

	ALBEDO = col;
	ROUGHNESS = mix(0.74, 0.98, n);
	SPECULAR = 0.0;                 // matches mat()'s SPECULAR_DISABLED look
	EMISSION = accent_color.rgb * fleck * 0.12;
}
