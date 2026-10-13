// The kit's starter surfaces (world/kit/materials/): bricks, siding, tiles,
// floorboards, stone blocks, shingles, or plain, drawn from numbers instead of
// an image. Laid out in world space ("triplanar"): each face picks the axis it
// faces most and the pattern runs across it in meters, so it tiles evenly on a
// wall of any size and lines up across neighbouring pieces.
//
// To make a new look, duplicate one of the .tres files next to this and change
// its colors and sizes in the Inspector. To use a real texture instead, see
// world/kit/materials/your_texture_template.tres.
shader_type spatial;

// 0 plain, 1 bricks, 2 siding, 3 tiles, 4 floorboards, 5 stone blocks, 6 shingles
uniform int pattern : hint_range(0, 6) = 0;
// The main color, and the color of the joints (mortar, grooves, gaps).
uniform vec3 color : source_color = vec3(0.6);
uniform vec3 joint_color : source_color = vec3(0.4);
// One brick / board / tile, in meters (across, up).
uniform vec2 cell = vec2(0.25, 0.075);
// Joint width, in meters.
uniform float joint = 0.01;
// How much each brick / board differs in brightness from the next (0 = none).
uniform float variation : hint_range(0.0, 1.0) = 0.15;
// Dirt and weathering: large soft blotches (0 = clean).
uniform float grime : hint_range(0.0, 1.0) = 0.25;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
// Multiplies the final color: a searched container darkens with this.
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1, 0, 0));
	float n010 = hash13(i + vec3(0, 1, 0));
	float n110 = hash13(i + vec3(1, 1, 0));
	float n001 = hash13(i + vec3(0, 0, 1));
	float n101 = hash13(i + vec3(1, 0, 1));
	float n011 = hash13(i + vec3(0, 1, 1));
	float n111 = hash13(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
			mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// 1 inside a cell, 0 on a joint, softened by the pixel's footprint so distant
// joints fade instead of shimmering.
float joint_mask(vec2 in_cell, vec2 size) {
	vec2 w = max(fwidth(in_cell), vec2(1e-4));
	vec2 d = min(in_cell, size - in_cell); // distance to the nearest edge, each way
	vec2 m = smoothstep(vec2(joint * 0.5) - w, vec2(joint * 0.5) + w, d);
	return m.x * m.y;
}

void fragment() {
	// Which plane this face lies in: floors and ceilings use (x, z), walls use
	// (along the wall, up).
	vec3 n = abs(world_normal);
	vec2 uv;
	if (n.y > n.x && n.y > n.z) {
		uv = world_pos.xz;
	} else if (n.x > n.z) {
		uv = vec2(world_pos.z, world_pos.y);
	} else {
		uv = vec2(world_pos.x, world_pos.y);
	}

	vec3 base = color;
	float solid = 1.0; // 0 on a joint
	float shade = 1.0;
	vec2 id = vec2(0.0);
	if (pattern == 1 || pattern == 5 || pattern == 6) {
		// Bricks, blocks and shingles: rows, every other one shifted half a cell.
		float row = floor(uv.y / cell.y);
		float u = uv.x / cell.x + 0.5 * mod(row, 2.0);
		id = vec2(floor(u), row);
		vec2 in_cell = vec2(fract(u) * cell.x, fract(uv.y / cell.y) * cell.y);
		solid = joint_mask(in_cell, cell);
		if (pattern == 6) {
			shade = mix(0.7, 1.0, smoothstep(0.0, 0.5, in_cell.y / cell.y)); // each row's lower edge in shadow
		}
	} else if (pattern == 2) {
		// Siding: horizontal boards, each overlapping the one below.
		float row = floor(uv.y / cell.y);
		float f = fract(uv.y / cell.y);
		id = vec2(0.0, row);
		shade = mix(0.82, 1.0, f);
		float w = max(fwidth(f), 1e-4);
		solid = smoothstep(0.0, joint / cell.y + w, f);
	} else if (pattern == 3) {
		// Tiles: a plain grid.
		id = floor(uv / cell);
		solid = joint_mask(mod(uv, cell), cell);
	} else if (pattern == 4) {
		// Floorboards: long boards, each row's joints at a random place.
		float row = floor(uv.y / cell.y);
		float u = uv.x / cell.x + hash12(vec2(row, 7.0));
		id = vec2(floor(u), row);
		vec2 in_cell = vec2(fract(u) * cell.x, fract(uv.y / cell.y) * cell.y);
		solid = joint_mask(in_cell, cell);
		shade = 0.92 + 0.08 * noise3(vec3(uv.x * 6.0, row * 3.0, 0.0)); // a hint of grain
	}
	if (pattern != 0) {
		base *= 1.0 + variation * (hash12(id + vec2(13.0, 3.0)) - 0.5) * 2.0;
	}
	base *= shade;
	base = mix(joint_color, base, solid);
	// Grime: big soft blotches, darker toward the ground.
	float blotch = noise3(world_pos * 0.6) * 0.6 + noise3(world_pos * 2.3) * 0.4;
	float low = 1.0 - smoothstep(0.0, 1.2, world_pos.y);
	base *= 1.0 - grime * (0.5 * blotch + 0.25 * low);
	ALBEDO = clamp(base * tint, 0.0, 1.0);
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
}
