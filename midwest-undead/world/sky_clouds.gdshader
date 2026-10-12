// The sky: a color gradient, the sun, drifting clouds, and stars at night.
// Procedural (no textures). world/day_night.gd sets the colors and `light` every
// frame; the clouds move on their own.
shader_type sky;

// Set by day_night.gd.
uniform vec3 sky_top_color : source_color = vec3(0.3, 0.45, 0.72);
uniform vec3 sky_horizon_color : source_color = vec3(0.68, 0.74, 0.8);
uniform vec3 ground_horizon_color : source_color = vec3(0.47, 0.52, 0.56);
uniform vec3 ground_bottom_color : source_color = vec3(0.14, 0.15, 0.16);
uniform float light : hint_range(0.0, 1.0) = 1.0; // 0 = darkest night, 1 = full day
uniform vec3 sun_tint : source_color = vec3(1.0); // the sunlight's color: warm at dawn and dusk

// Tuning (in the Inspector: select the WorldEnvironment's Sky, then its material).
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.55; // 0 = clear, 1 = overcast
uniform float cloud_scale = 1.4; // bigger = smaller, busier clouds
uniform float cloud_softness : hint_range(0.02, 0.5) = 0.16; // how fuzzy the edges are
uniform vec2 wind = vec2(0.006, 0.002); // drift, in cloud-texture units per second
uniform vec3 day_cloud_color : source_color = vec3(0.96, 0.96, 0.97);
uniform vec3 day_cloud_shade : source_color = vec3(0.55, 0.57, 0.63); // undersides
uniform vec3 night_cloud_color : source_color = vec3(0.07, 0.08, 0.11);
uniform float star_density : hint_range(0.0, 0.01) = 0.0025;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Smooth value noise, 0..1.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Layered noise: big soft shapes with finer detail on top.
float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		total += noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return total;
}

void sky() {
	vec3 dir = EYEDIR;

	// Below the horizon (only seen past the edge of the world): plain ground colors.
	if (dir.y < 0.0) {
		COLOR = mix(ground_horizon_color, ground_bottom_color, clamp(-dir.y * 3.0, 0.0, 1.0));
	} else {
		vec3 col = mix(sky_horizon_color, sky_top_color, pow(dir.y, 0.5));

		// The sun disk with a soft glow, like Godot's built-in procedural sky.
		float sun_glow = 0.0;
		if (LIGHT0_ENABLED) {
			float angle = acos(clamp(dot(LIGHT0_DIRECTION, dir), -1.0, 1.0));
			vec3 sun_col = LIGHT0_COLOR * LIGHT0_ENERGY;
			if (angle < LIGHT0_SIZE) {
				col = sun_col;
			} else if (angle < 0.5) {
				sun_glow = 1.0 - (angle - LIGHT0_SIZE) / (0.5 - LIGHT0_SIZE);
				col = mix(col, sun_col, pow(sun_glow, 6.0) * 0.6);
			}
		}

		// Stars once it's properly dark (not while dusk is still glowing), hidden
		// behind clouds.
		float night = 1.0 - smoothstep(0.0, 0.1, light);
		float stars = 0.0;
		if (night > 0.0 && !AT_CUBEMAP_PASS) {
			vec2 cell = floor(dir.xz / (dir.y + 0.4) * 300.0);
			stars = step(1.0 - star_density, hash(cell)) * night * smoothstep(0.05, 0.3, dir.y);
		}

		// Clouds: noise on a flat layer overhead, seen in perspective (so they bunch
		// up toward the horizon), drifting with the wind, faded out right at the horizon.
		vec2 uv = dir.xz / (dir.y + 0.12) * cloud_scale + wind * TIME;
		float n = fbm(uv);
		float density = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + cloud_softness, n);
		density *= smoothstep(0.0, 0.15, dir.y);
		// Thicker parts are darker underneath; the edges catch the light.
		float thickness = smoothstep(0.45, 0.9, n);
		vec3 day_col = mix(day_cloud_color, day_cloud_shade, thickness * 0.7) * sun_tint;
		day_col += sun_tint * sun_glow * 0.35 * (1.0 - thickness); // lit edges near the sun
		// sqrt: clouds stay lit (in the sunset's color) well into dusk.
		vec3 cloud_col = mix(night_cloud_color, day_col, sqrt(light));

		col += vec3(0.85, 0.88, 1.0) * stars * (1.0 - density);
		COLOR = mix(col, cloud_col, density * 0.92);
	}
}
