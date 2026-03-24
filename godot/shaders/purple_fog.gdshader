shader_type canvas_item;

uniform float speed : hint_range(0.01, 0.3) = 0.07;
uniform float scale : hint_range(1.0, 10.0) = 3.0;
uniform float intensity : hint_range(0.0, 0.5) = 0.25;
uniform vec4 fog_color : source_color = vec4(0.25, 0.08, 0.45, 1.0);
uniform vec4 bg_color : source_color = vec4(0.03, 0.02, 0.06, 1.0);

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
	vec2 uv = UV * scale;
	float t = TIME * speed;

	// Плавная дымка, сносимая ветром вправо
	float n1 = fbm(uv + vec2(t, t * 0.2));
	float n2 = fbm(uv * 0.8 + vec2(t * 0.6, -t * 0.15) + 50.0);

	float fog = (n1 + n2) * 0.5;
	fog = smoothstep(0.35, 0.65, fog);

	vec3 col = mix(bg_color.rgb, fog_color.rgb, fog * intensity);

	COLOR = vec4(col, 1.0);
}
