shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float strength : hint_range(0.0, 0.15) = 0.03;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Trapezoid: top narrower, bottom wider
	// The higher on screen (smaller Y), the more we push X toward center
	float t = 1.0 - uv.y; // 0 at bottom, 1 at top
	float squeeze = t * strength;
	uv.x = 0.5 + (uv.x - 0.5) * (1.0 - squeeze);

	COLOR = texture(screen_texture, uv);
}
