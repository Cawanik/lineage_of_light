shader_type canvas_item;

uniform vec4 deep_color : source_color = vec4(0.05, 0.15, 0.35, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.1, 0.35, 0.55, 1.0);
uniform vec4 foam_color : source_color = vec4(0.6, 0.8, 0.9, 1.0);
uniform float wave_speed : hint_range(0.01, 2.0) = 0.4;
uniform float wave_scale : hint_range(1.0, 50.0) = 8.0;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.3;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * wave_scale;
	float t = TIME * wave_speed;

	// Two wave layers moving in different directions
	float wave1 = fbm(uv + vec2(t * 0.6, t * 0.2));
	float wave2 = fbm(uv * 1.3 + vec2(-t * 0.3, t * 0.5));
	float wave3 = fbm(uv * 0.7 + vec2(t * 0.1, -t * 0.4));

	float waves = (wave1 + wave2 + wave3) / 3.0;

	// Broad rolling wave pattern
	float big_wave = sin(uv.x * 0.5 + uv.y * 0.3 + t * 1.5) * 0.5 + 0.5;
	big_wave = big_wave * 0.3 + 0.7;
	waves *= big_wave;

	// Color gradient: deep -> shallow based on wave height
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, waves);

	// Foam on wave crests
	float foam = smoothstep(0.5, 0.65, waves) * foam_amount;
	col = mix(col, foam_color.rgb, foam);

	// Subtle caustic sparkles
	float caustic = noise(uv * 4.0 + vec2(t * 1.2, t * 0.8));
	caustic = pow(caustic, 5.0) * 0.15;
	col += vec3(caustic * 0.5, caustic * 0.7, caustic);

	// Gentle brightness variation
	float brightness = sin(uv.y * 0.2 + t * 0.3) * 0.05 + 1.0;
	col *= brightness;

	COLOR = vec4(col, 1.0);
}
