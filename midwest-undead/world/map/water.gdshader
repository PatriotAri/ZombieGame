// Water for ponds and creeks (world/map/pond.gd, world/map/creek.gd): see-through,
// shiny, with small moving ripples. Creeks also flow (along UV.y) and foam
// white over rapids and falls (vertex color red = how much foam).
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec4 shallow_color : source_color = vec4(0.22, 0.32, 0.26, 0.55);
uniform vec4 deep_color : source_color = vec4(0.06, 0.13, 0.12, 0.85);
uniform float flow_speed = 0.0; // meters per second along UV.y (creeks)
uniform float ripple_scale = 0.35;

varying float foam;

void vertex() {
	foam = COLOR.r;
}

float wave(vec2 p, vec2 dir, float freq, float speed) {
	return sin(dot(p, dir) * freq + TIME * speed);
}

void fragment() {
	vec2 p = UV * 8.0 + vec2(0.0, -TIME * flow_speed);
	float dx = wave(p, vec2(1.0, 0.3), 2.1, 1.3) + 0.6 * wave(p, vec2(-0.4, 1.0), 3.7, 1.9);
	float dz = wave(p, vec2(0.2, 1.0), 2.6, 1.1) + 0.5 * wave(p, vec2(1.0, -0.7), 4.3, 2.3);
	NORMAL_MAP = normalize(vec3(dx * ripple_scale, dz * ripple_scale, 2.0)) * 0.5 + 0.5;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec4 col = mix(shallow_color, deep_color, 0.5 + 0.5 * fresnel);
	float froth = foam * (0.7 + 0.3 * sin(p.y * 6.0 + p.x * 3.0));
	ALBEDO = mix(col.rgb, vec3(0.9, 0.92, 0.9), froth);
	ALPHA = clamp(col.a + froth, 0.0, 1.0);
	ROUGHNESS = mix(0.05, 0.6, froth);
	SPECULAR = 0.6;
}
