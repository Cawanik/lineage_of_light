# ==========================================
# iso_ground.gd — Изометрическая земля на TileMapLayer
# ==========================================
# Рисуешь тайлы сам кисточкой в редакторе, блять
# Скрипт только создаёт TileSet с палитрой
# is_border(x, y) — проверяет тайл на бордюрность по source_id
# _update_marker() — рисует маркер трона в редакторе поверх тайлов
# ==========================================

@tool
class_name IsoGround
extends TileMapLayer

@export_group("Маркеры")
@export var throne_tile: Vector2i = Vector2i(14, 15):
	set(v):
		throne_tile = v
		_update_marker()

@export_group("Тайлы земли")
@export var ground_tiles: Array[Texture2D] = []:
	set(v):
		ground_tiles = v
		_rebuild_tileset()

@export_group("Особые тайлы")
@export var special_tiles: Array[Texture2D] = []:
	set(v):
		special_tiles = v
		_rebuild_tileset()
@export var special_texture_offset: Vector2i = Vector2i(0, 0):
	set(v):
		special_texture_offset = v
		_rebuild_tileset()

@export_group("Смещение текстур")
@export var ground_texture_offset: Vector2i = Vector2i(0, 0):
	set(v):
		ground_texture_offset = v
		_rebuild_tileset()

var _initialized: bool = false
var _ground_count: int = 0
var _special_start_id: int = 0
var _special_count: int = 0
var _marker: Node2D = null


func _ready() -> void:
	_initialized = true
	_rebuild_tileset()
	_update_marker()
	if not Engine.is_editor_hint():
		call_deferred("_create_border_collision")


func _rebuild_tileset() -> void:
	if not _initialized:
		return

	var ts = TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL
	ts.tile_size = Vector2i(64, 32)

	var source_id = 0

	# Ground tiles
	_ground_count = 0
	for tex in ground_tiles:
		if tex == null:
			continue
		var src = TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(64, 64)
		src.create_tile(Vector2i(0, 0))
		ts.add_source(src, source_id)
		source_id += 1
		_ground_count += 1

	# Special tiles
	_special_start_id = source_id
	_special_count = 0
	for tex in special_tiles:
		if tex == null:
			continue
		var src = TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(64, 64)
		src.create_tile(Vector2i(0, 0))
		ts.add_source(src, source_id)
		source_id += 1
		_special_count += 1

	tile_set = ts

	# Применяем offsets
	for i in range(ts.get_source_count()):
		var sid = ts.get_source_id(i)
		var src = ts.get_source(sid) as TileSetAtlasSource
		if src:
			var td = src.get_tile_data(Vector2i(0, 0), 0)
			if td:
				if sid >= _special_start_id:
					td.texture_origin = special_texture_offset
				else:
					td.texture_origin = ground_texture_offset


func _update_marker() -> void:
	if not Engine.is_editor_hint():
		if _marker and is_instance_valid(_marker):
			_marker.queue_free()
			_marker = null
		return

	if not _initialized:
		return

	if not _marker or not is_instance_valid(_marker):
		_marker = Node2D.new()
		_marker.name = "ThroneMarker"
		_marker.z_index = 100
		add_child(_marker)

	var center = map_to_local(throne_tile)
	_marker.position = center

	_marker.queue_redraw()
	if not _marker.draw.is_connected(_draw_marker):
		_marker.draw.connect(_draw_marker)


func _draw_marker() -> void:
	if not _marker or not is_instance_valid(_marker):
		return
	var hw = 32.0
	var hh = 16.0
	var diamond = PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
	])
	_marker.draw_colored_polygon(diamond, Color(0.6, 0.0, 0.8, 0.4))
	for i in range(4):
		_marker.draw_line(diamond[i], diamond[(i + 1) % 4], Color(0.8, 0.0, 1.0, 0.8), 2.0)
	_marker.draw_string(ThemeDB.fallback_font, Vector2(-20, -22), "THRONE", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1, 1, 1, 0.9))


func _create_border_collision() -> void:
	# Создаём невидимые стенки по краю тайлмапа
	if not tile_set:
		return
	var cells = get_used_cells()
	var cell_set = {}
	for c in cells:
		cell_set[c] = true

	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var outside_cells: Dictionary = {}

	# Собираем пустые тайлы, граничащие с картой
	for cell in cells:
		for dir in dirs:
			var neighbor = cell + dir
			if not cell_set.has(neighbor):
				outside_cells[neighbor] = true

	# Ставим StaticBody на каждый пустой тайл за краем карты
	for cell in outside_cells:
		var world_pos = map_to_local(cell)
		var body = StaticBody2D.new()
		body.position = world_pos
		body.collision_layer = 1
		body.collision_mask = 0

		var shape = CollisionShape2D.new()
		var poly = ConvexPolygonShape2D.new()
		var hw = 32.0
		var hh = 16.0
		poly.points = PackedVector2Array([
			Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
		])
		shape.shape = poly
		body.add_child(shape)
		add_child(body)


func is_border(x: int, y: int) -> bool:
	var cell_source = get_cell_source_id(Vector2i(x, y))
	return cell_source >= _special_start_id and cell_source != -1
