class_name StormZone
extends Node2D

# Полуразмеры изо-тайла (CELL_SIZE=64, ISO_RATIO=0.5)
const TILE_HW = 32.0  # half-width
const TILE_HH = 16.0  # half-height

var storm_tile: Vector2i = Vector2i(-1, -1)
var damage: float = 10.0
var duration: float = 5.0
var tick_interval: float = 0.5
var is_preview: bool = true

var _age: float = 0.0
var _tick_timer: float = 0.0
var _pulse: float = 0.0

# Угла изо-ромба (локальные координаты относительно центра тайла)
var _diamond: PackedVector2Array = PackedVector2Array([
	Vector2(0, -TILE_HH),       # верх
	Vector2(TILE_HW, 0),        # право
	Vector2(0, TILE_HH),        # низ
	Vector2(-TILE_HW, 0),       # лево
])


func activate() -> void:
	is_preview = false
	_age = 0.0
	_tick_timer = 0.0


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()

	if is_preview:
		return

	_age += delta
	_tick_timer += delta

	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_do_damage()

	if _age >= duration:
		queue_free()


func _do_damage() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			if e.get("current_tile") == storm_tile:
				e.take_damage(damage)


func _draw() -> void:
	var fade = 1.0 if is_preview else 1.0 - (_age / duration) * 0.4
	var base_a = 0.45 if is_preview else fade
	var pulse = sin(_pulse * 5.0) * 0.15 + 0.85

	# Ромб — граница тайла
	var border_col = Color(0.4, 0.65, 1.0, 0.55 * base_a)
	draw_colored_polygon(_diamond, Color(0.25, 0.5, 1.0, 0.1 * base_a))
	draw_polyline(_diamond + PackedVector2Array([_diamond[0]]), border_col, 1.5)

	# Облако в центре (пульсирует)
	var cloud_r = 10.0 * pulse
	draw_circle(Vector2.ZERO, cloud_r + 4.0, Color(0.4, 0.6, 1.0, 0.3 * base_a))
	draw_circle(Vector2.ZERO, cloud_r, Color(0.7, 0.85, 1.0, 0.7 * base_a))
	draw_circle(Vector2.ZERO, cloud_r * 0.4, Color(0.95, 0.98, 1.0, 0.9 * base_a))

	if is_preview:
		return

	# Молнии — меняются каждые несколько кадров
	var rng = RandomNumberGenerator.new()
	rng.seed = int(_pulse * 12.0)
	for i in range(4):
		var angle = rng.randf() * TAU
		# Ограничиваем длину молний размером тайла
		var max_len = rng.randf_range(8.0, TILE_HW * 0.8)
		var tip = Vector2(cos(angle) * max_len, sin(angle) * max_len * (TILE_HH / TILE_HW))
		var mid = tip * 0.5 + Vector2(
			rng.randf_range(-6.0, 6.0),
			rng.randf_range(-4.0, 4.0)
		)
		var lc = Color(0.85, 0.93, 1.0, 0.85 * fade)
		draw_line(Vector2.ZERO, mid, lc, 1.5)
		draw_line(mid, tip, lc, 1.5)
