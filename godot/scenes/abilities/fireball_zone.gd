class_name FireballZone
extends Node2D

const TILE_HW = 32.0
const TILE_HH = 16.0

var base_tile: Vector2i = Vector2i(-1, -1)
var damage: float = 30.0
var fall_duration: float = 0.5
var is_preview: bool = true
var is_valid_placement: bool = true
var grid_size: int = 2  # 2 = 2x2 (4 тайла), 3 = 3x3 (9 тайлов)

var _orb_y: float = -200.0
var _pulse: float = 0.0
var _exploding: bool = false
var _explode_age: float = 0.0

const EXPLODE_DURATION = 0.75

var _tile_offsets: Array = []
var _tile_local_offsets: Array = []


func _ready() -> void:
	_rebuild_tile_data()


func _rebuild_tile_data() -> void:
	_tile_offsets.clear()
	_tile_local_offsets.clear()
	# Центр блока grid_size x grid_size в изо-пространстве
	var center_y = (grid_size - 1) * TILE_HH
	for y in range(grid_size):
		for x in range(grid_size):
			_tile_offsets.append(Vector2i(x, y))
			var world = Vector2((x - y) * TILE_HW, (x + y) * TILE_HH)
			_tile_local_offsets.append(world - Vector2(0.0, center_y))


func activate() -> void:
	is_preview = false
	_orb_y = -220.0
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "_orb_y", 0.0, fall_duration)
	tween.tween_callback(_on_land)


func _on_land() -> void:
	# Звук взрыва
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play("explosion")
	# Считаем центры 4 тайлов в мировых координатах (без ссылки на bg)
	var tile_centers: Array = []
	for offset in _tile_offsets:
		var t = base_tile + offset
		tile_centers.append(Vector2((t.x - t.y) * 32.0, (t.x + t.y) * 16.0 + 15.0))

	# Урон врагам по позиции
	const HIT_RADIUS_SQ = 38.0 * 38.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.has_method("take_damage"):
			continue
		for center in tile_centers:
			if e.global_position.distance_squared_to(center) <= HIT_RADIUS_SQ:
				e.take_damage(damage)
				break

	# Урон постройкам на 4 тайлах
	var bg = get_tree().current_scene.get_node_or_null("YSort/BuildingGrid")
	if bg:
		for offset in _tile_offsets:
			var building = bg.get_building(base_tile + offset)
			if is_instance_valid(building) and building.has_method("take_damage"):
				building.take_damage(damage)

	_exploding = true
	_explode_age = 0.0


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()

	if _exploding:
		_explode_age += delta
		if _explode_age >= EXPLODE_DURATION:
			queue_free()


func _draw() -> void:
	if _exploding:
		var t = _explode_age / EXPLODE_DURATION
		var a = 1.0 - t
		var ease_out = 1.0 - pow(1.0 - t, 2.0)

		# Тень на земле (расширяется и гаснет)
		draw_circle(Vector2.ZERO, 85.0 * ease_out, Color(0.15, 0.0, 0.0, 0.35 * a))

		# Внешняя волна (быстро расширяется и исчезает)
		var wave_r = 100.0 * ease_out
		draw_arc(Vector2.ZERO, wave_r, 0.0, TAU, 48, Color(1.0, 0.35, 0.0, 0.6 * (1.0 - ease_out)), 3.5)

		# Дым (тёмное кольцо снаружи, появляется после пика)
		if t > 0.3:
			var smoke_a = (t - 0.3) / 0.7
			draw_circle(Vector2.ZERO, 72.0 * ease_out, Color(0.12, 0.08, 0.05, 0.4 * smoke_a * a))

		# Основной огненный шар (расширяется потом схлопывается)
		var fire_r = 62.0 * (ease_out * (1.0 - t * 0.5))
		draw_circle(Vector2.ZERO, fire_r, Color(0.9, 0.2, 0.0, 0.75 * a))
		draw_circle(Vector2.ZERO, fire_r * 0.7, Color(1.0, 0.5, 0.05, 0.85 * a))
		draw_circle(Vector2.ZERO, fire_r * 0.4, Color(1.0, 0.82, 0.15, 0.95 * a))

		# Белое горячее ядро (быстро гаснет)
		var core_a = clampf(1.0 - t * 2.5, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 20.0 * (1.0 - t), Color(1.0, 1.0, 0.95, core_a))

		# Лучи взрыва (8 штук, фиксированный сид)
		var rng = RandomNumberGenerator.new()
		rng.seed = 77
		for i in range(8):
			var angle = rng.randf() * TAU
			var ray_len = rng.randf_range(28.0, 58.0) * (1.0 - t * 0.6)
			var tip = Vector2(cos(angle) * ray_len, sin(angle) * ray_len * 0.5)
			var ray_a = clampf(1.0 - t * 1.8, 0.0, 1.0)
			draw_line(Vector2.ZERO, tip, Color(1.0, 0.65, 0.1, ray_a), 2.5)
		return

	# Цвет подсветки — зелёный/красный в зависимости от валидности
	var border_col: Color
	var fill_col: Color
	if is_valid_placement:
		border_col = Color(1.0, 0.5, 0.1, 0.65)
		fill_col   = Color(1.0, 0.3, 0.0, 0.1)
	else:
		border_col = Color(1.0, 0.2, 0.2, 0.65)
		fill_col   = Color(1.0, 0.0, 0.0, 0.1)

	for offset in _tile_local_offsets:
		_draw_tile_diamond(offset, border_col, fill_col)

	# Падающий шар
	if not is_preview:
		var orb_pos = Vector2(0.0, _orb_y)
		var pulse = sin(_pulse * 8.0) * 0.12 + 0.88
		var r = 14.0 * pulse

		# Тень на земле (растёт по мере приближения шара)
		var shadow_t = clampf(1.0 - (-_orb_y / 220.0), 0.0, 1.0)
		draw_circle(Vector2.ZERO, 28.0 * shadow_t, Color(0.1, 0.0, 0.0, 0.35 * shadow_t))

		# Искры-хвост за шаром
		var rng2 = RandomNumberGenerator.new()
		rng2.seed = int(_pulse * 10.0)
		for i in range(7):
			var sy = _orb_y + rng2.randf_range(6.0, 35.0)
			var sx = rng2.randf_range(-9.0, 9.0)
			var sa = rng2.randf_range(0.25, 0.7)
			var sr = rng2.randf_range(1.5, 4.5)
			draw_circle(Vector2(sx, sy), sr, Color(1.0, rng2.randf_range(0.3, 0.7), 0.05, sa))

		# Внешнее свечение
		draw_circle(orb_pos, r + 11.0, Color(1.0, 0.25, 0.0, 0.18))
		draw_circle(orb_pos, r + 5.0,  Color(1.0, 0.45, 0.0, 0.35))
		# Основной шар
		draw_circle(orb_pos, r,         Color(1.0, 0.55, 0.1, 0.95))
		# Горячее ядро
		draw_circle(orb_pos, r * 0.42,  Color(1.0, 0.92, 0.65, 1.0))
		draw_circle(orb_pos, r * 0.15,  Color(1.0, 1.0, 1.0, 1.0))


func _draw_tile_diamond(center: Vector2, border: Color, fill: Color) -> void:
	var pts = PackedVector2Array([
		center + Vector2(0, -TILE_HH),
		center + Vector2(TILE_HW, 0),
		center + Vector2(0, TILE_HH),
		center + Vector2(-TILE_HW, 0),
	])
	draw_colored_polygon(pts, fill)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), border, 1.5)
