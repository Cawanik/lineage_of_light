shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 8.0) = 3.0;
uniform vec2 world_size = vec2(960.0, 960.0);

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec2 voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float min_dist = 1.0;
	float second_dist = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash(i + neighbor) * vec2(0.8) + vec2(0.1);
			float d = length(neighbor + point - f);
			if (d < min_dist) {
				second_dist = min_dist;
				min_dist = d;
			} else if (d < second_dist) {
				second_dist = d;
			}
		}
	}
	return vec2(min_dist, second_dist);
}

void fragment() {
	vec2 world_px = UV * world_size;
	vec2 px = floor(world_px / pixel_size);

	// === Palette ===
	// Stone - light grey
	vec3 stone_darkest = vec3(0.35, 0.34, 0.38);
	vec3 stone_dark = vec3(0.45, 0.44, 0.48);
	vec3 stone_mid = vec3(0.55, 0.54, 0.58);
	vec3 stone_light = vec3(0.65, 0.63, 0.68);
	vec3 stone_crack = vec3(0.25, 0.24, 0.28);

	// Grass - lively green with slight purple warmth
	vec3 grass_dark = vec3(0.30, 0.42, 0.28);
	vec3 grass_mid = vec3(0.40, 0.55, 0.36);
	vec3 grass_light = vec3(0.50, 0.64, 0.48);
	vec3 grass_bright = vec3(0.62, 0.70, 0.62);

	// Accents
	vec3 moss = vec3(0.35, 0.48, 0.35);
	vec3 flower_purple = vec3(0.60, 0.35, 0.65);
	vec3 flower_lavender = vec3(0.72, 0.55, 0.78);

	// === Pseudo-3D: squash Y by ~25° tilt ===
	vec2 iso_px = vec2(px.x, px.y * 1.5);

	// === Large zones: grass vs dirt/stone patches ===
	float zone = noise(iso_px * 0.015);
	float zone2 = noise(iso_px * 0.025 + 300.0);
	float grass_amount = smoothstep(0.30, 0.60, zone); // 0 = stone, 1 = grass

	vec3 base;

	// === Stone areas ===
	if (grass_amount < 0.5) {
		// Voronoi stones - bigger, greyer
		vec2 v = voronoi(iso_px * 0.07);
		float edge = v.y - v.x;
		float cell_id = hash(floor(iso_px * 0.07 + 0.5));

		base = mix(stone_dark, stone_mid, cell_id);
		base = mix(base, stone_light, noise(iso_px * 0.2) * 0.25);

		// Per-stone color shift
		if (cell_id > 0.7) {
			base = mix(base, stone_light, 0.3);
		} else if (cell_id < 0.3) {
			base = mix(base, stone_darkest, 0.3);
		}

		// Cracks between stones
		if (edge < 0.06) {
			base = mix(stone_crack, base, smoothstep(0.02, 0.06, edge));
		}

		// Grass creeping into stone cracks
		float creep = noise(iso_px * 0.06 + 500.0);
		if (creep > 0.55) {
			float ci = smoothstep(0.55, 0.8, creep);
			base = mix(base, grass_dark, ci * 0.5);
		}
	}
	// === Grass areas (sunset purple tint) ===
	else {
		float g1 = noise(iso_px * 0.06);
		float g2 = noise(iso_px * 0.15);
		float g3 = hash(px);

		base = mix(grass_dark, grass_mid, g1);
		base = mix(base, grass_light, g2 * 0.4);

		// Grass blade highlights
		if (g3 > 0.85) {
			base = mix(base, grass_bright, 0.5);
		}
		// Dark gaps
		if (g3 < 0.1) {
			base *= 0.7;
		}

		// Scattered stones poking through grass
		float stone_patch = noise(iso_px * 0.04 + 100.0);
		if (stone_patch < 0.25) {
			float si = smoothstep(0.25, 0.10, stone_patch);
			base = mix(base, stone_mid, si * 0.6);
		}

		// Moss
		if (g1 > 0.6 && g2 > 0.5) {
			base = mix(base, moss, 0.3);
		}
	}

	// === Transition zone: scattered stones ===
	if (grass_amount > 0.3 && grass_amount < 0.7) {
		float scatter = hash(px * 1.3 + 200.0);
		if (scatter > 0.93) {
			base = mix(base, stone_mid, 0.6);
		}
	}

	// === Small flowers (purple/lavender in grassy areas) ===
	float fc = hash(px * 1.7 + 50.0);
	if (fc > 0.992 && grass_amount > 0.4) {
		float ft = hash(px + 999.0);
		if (ft > 0.5) {
			base = flower_purple;
		} else {
			base = flower_lavender;
		}
	}

	// === Top-left lighting (pseudo-3D) ===
	float lx = noise((iso_px + vec2(-3.0, 0.0)) * 0.05);
	float rx = noise((iso_px + vec2(3.0, 0.0)) * 0.05);
	float ty = noise((iso_px + vec2(0.0, -3.0)) * 0.05);
	float by = noise((iso_px + vec2(0.0, 3.0)) * 0.05);
	float light = ((lx - rx) + (ty - by)) * 0.3;
	base *= 1.0 + light;

	// === Per-pixel grain ===
	base += (hash(px) - 0.5) * 0.03;

	// === Subtle brightness variation (no darkening) ===
	float bright = noise(iso_px * 0.01 + 700.0);
	base *= 0.95 + bright * 0.1;

	COLOR = vec4(clamp(base, 0.0, 1.0), 1.0);
}
