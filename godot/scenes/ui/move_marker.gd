extends Node2D

var lifetime: float = 0.0
var max_lifetime: float = 2.0
var ring_radius: float = 12.0
var start_radius: float = 18.0


func _ready() -> void:
	ring_radius = start_radius


func _process(delta: float) -> void:
	lifetime += delta
	# Shrink ring
	ring_radius = lerpf(start_radius, 4.0, lifetime / max_lifetime)
	# Fade out
	modulate.a = 1.0 - (lifetime / max_lifetime)
	queue_redraw()
	if lifetime >= max_lifetime:
		queue_free()


func _draw() -> void:
	var segments = 20
	var color = Color(0.6, 0.2, 0.8, 0.8)
	var inner_color = Color(0.6, 0.2, 0.8, 0.3)

	# Ellipse: wide X, squashed Y for ~25° top-down
	var rx = ring_radius
	var ry = ring_radius * 0.55

	for i in range(segments):
		var a1 = TAU * i / segments
		var a2 = TAU * (i + 1) / segments
		var p1 = Vector2(cos(a1) * rx, sin(a1) * ry)
		var p2 = Vector2(cos(a2) * rx, sin(a2) * ry)
		draw_line(p1, p2, color, 1.5)

	# Inner cross
	var s = ring_radius * 0.3
	draw_line(Vector2(-s, 0), Vector2(s, 0), inner_color, 1.0)
	draw_line(Vector2(0, -s * 0.55), Vector2(0, s * 0.55), inner_color, 1.0)
