class_name FireballZone
extends Node2D

const TILE_HW = 32.0
const TILE_HH = 16.0

# Смещения 4 центров тайлов 2x2 относительно центра блока (в изо-пространстве)
const TILE_LOCAL_OFFSETS: Array = [
	Vector2(0, -16),   # верх (0,0)
	Vector2(32, 0),    # право (1,0)
	Vector2(-32, 0),   # лево (0,1)
	Vector2(0, 16),    # низ (1,1)
]

var base_tile: Vector2i = Vector2i(-1, -1)
var damage: float = 30.0
var fall_duration: float = 0.5
var is_preview: bool = true
var is_valid_placement: bool = true

var _orb_y: float = -200.0
var _pulse: float = 0.0
var _exploding: bool = false
var _explode_age: float = 0.0

const EXPLODE_DURATION = 0.4

var _tile_offsets: Array = [
	Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(1, 1),
]


func activate() -> void:
	is_preview = false
	_orb_y = -220.0
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "_orb_y", 0.0, fall_duration)
	tween.tween_callback(_on_land)


func _on_land() -> void:
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
		draw_circle(Vector2.ZERO, 75.0 * (1.0 + t * 0.5), Color(1.0, 0.35, 0.0, 0.55 * a))
		draw_circle(Vector2.ZERO, 42.0 * (1.0 - t * 0.2), Color(1.0, 0.72, 0.1, 0.9 * a))
		draw_circle(Vector2.ZERO, 18.0, Color(1.0, 1.0, 0.88, a))
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

	# 4 тайла 2x2
	for offset in TILE_LOCAL_OFFSETS:
		_draw_tile_diamond(offset, border_col, fill_col)

	# Падающий шар (только в момент падения, не в preview)
	if not is_preview:
		var orb_pos = Vector2(0.0, _orb_y)
		var pulse = sin(_pulse * 8.0) * 0.12 + 0.88
		var r = 13.0 * pulse
		draw_circle(orb_pos, r + 7.0, Color(1.0, 0.4, 0.0, 0.3))
		draw_circle(orb_pos, r,        Color(1.0, 0.55, 0.1, 0.95))
		draw_circle(orb_pos, r * 0.38, Color(1.0, 0.95, 0.7, 1.0))


func _draw_tile_diamond(center: Vector2, border: Color, fill: Color) -> void:
	var pts = PackedVector2Array([
		center + Vector2(0, -TILE_HH),
		center + Vector2(TILE_HW, 0),
		center + Vector2(0, TILE_HH),
		center + Vector2(-TILE_HW, 0),
	])
	draw_colored_polygon(pts, fill)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), border, 1.5)
