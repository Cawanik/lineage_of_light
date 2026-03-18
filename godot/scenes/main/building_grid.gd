# ==========================================
# building_grid.gd — Сетка зданий, единственный источник правды, сука
# ==========================================
# _ready() — грузит размер клетки и iso_ratio из конфига, инициализирует нахуй
# tile_to_world(tile) — конвертит тайловые координаты в мировые (центр ромба), ёпт
# world_to_tile(world_pos) — обратная конвертация, из мировых в тайлы
# _get_ysort() — возвращает родительский YSort для сортировки по глубине
# place_building(tile, building) — ставит здание на тайл, добавляет в YSort
# remove_building(tile) — убирает здание с тайла, возвращает ноду
# get_building(tile) — возвращает здание по координатам тайла или null, хуле тут
# is_border(tile) — проверяет, находится ли тайл на границе карты
# is_occupied(tile) — проверяет занятость: здание, стена или граница — нехуй туда лезть
# move_building(from_tile, to_tile) — перемещает здание с одного тайла на другой
# find_nearest_building(world_pos, max_dist) — ищет ближайшее здание к мировой позиции
# _input(event) — G включает дебаг-сетку, стрелки двигают офсет сетки
# _draw() — рисует дебаг-оверлей сетки: жёлтые ромбы свободных, красные занятых тайлов
# ==========================================

class_name BuildingGrid
extends Node2D

## Single source of truth for the isometric tile grid
## Stores buildings, walls, and provides tile<->world conversion

var CELL_SIZE: int = 64
var ISO_RATIO: float = 0.5

# Buildings: Vector2i -> Building node
var buildings: Dictionary = {}
# Wall nodes: Vector2i -> true (tiles that have a wall pillar)
var wall_nodes: Dictionary = {}

# Debug: draw grid overlay
var show_grid: bool = false


func _ready() -> void:
	var iso = Config.game.get("iso", {})
	CELL_SIZE = iso.get("cell_size", 64)
	ISO_RATIO = iso.get("iso_ratio", 0.5)


func tile_to_world(tile: Vector2i) -> Vector2:
	## Returns the world-space CENTER of the isometric tile
	## This is where iso_ground draws the texture center
	var screen_x = float((tile.x - tile.y) * CELL_SIZE) * 0.5
	var screen_y = float((tile.x + tile.y) * CELL_SIZE) * ISO_RATIO * 0.5 + 15.0
	return Vector2(screen_x, screen_y)


func world_to_tile(world_pos: Vector2) -> Vector2i:
	var adjusted_y = world_pos.y - 15.0
	var fx = world_pos.x / (CELL_SIZE * 0.5)
	var fy = adjusted_y / (CELL_SIZE * ISO_RATIO * 0.5)
	return Vector2i(roundi((fx + fy) * 0.5), roundi((fy - fx) * 0.5))


func _get_ysort() -> Node2D:
	return get_parent()  # BuildingGrid is child of YSort


func place_building(tile: Vector2i, building: Node2D) -> void:
	if buildings.has(tile):
		return
	buildings[tile] = building
	building.position = tile_to_world(tile)
	
	# Add to YSort (not BuildingGrid) so it sorts with player
	var ysort = _get_ysort()
	if building.get_parent() == self:
		remove_child(building)
	if building.get_parent() != ysort:
		ysort.add_child(building)
	
	# Update pathfinding system
	var ps = get_node_or_null("/root/PathfindingSystem")
	if ps:
		ps.set_tile_solid(tile, true)


func remove_building(tile: Vector2i) -> Node2D:
	if not buildings.has(tile):
		return null
	var building = buildings[tile]
	buildings.erase(tile)
	var ps = get_node_or_null("/root/PathfindingSystem")
	if ps:
		ps.set_tile_solid(tile, false)
	return building


func get_building(tile: Vector2i) -> Node2D:
	return buildings.get(tile, null)


func is_border(tile: Vector2i) -> bool:
	var iso = Config.game.get("iso", {})
	var w = iso.get("grid_width", 32)
	var h = iso.get("grid_height", 32)
	return tile.x <= 1 or tile.y <= 1 or tile.x >= w - 2 or tile.y >= h - 2


func is_occupied(tile: Vector2i) -> bool:
	return buildings.has(tile) or wall_nodes.has(tile) or is_border(tile)


func move_building(from_tile: Vector2i, to_tile: Vector2i) -> bool:
	if not buildings.has(from_tile):
		return false
	if buildings.has(to_tile):
		return false
	var building = buildings[from_tile]
	if not building.can_move:
		return false
	buildings.erase(from_tile)
	buildings[to_tile] = building
	building.position = tile_to_world(to_tile)
	return true


func find_nearest_building(world_pos: Vector2, max_dist: float = 30.0) -> Vector2i:
	var closest = Vector2i(-9999, -9999)
	var closest_dist = max_dist
	for tile in buildings:
		var wpos = tile_to_world(tile)
		var dist = world_pos.distance_to(wpos)
		if dist < closest_dist:
			closest_dist = dist
			closest = tile
	return closest


var grid_offset: Vector2 = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		show_grid = not show_grid
		queue_redraw()
		return

	if show_grid and event is InputEventKey and event.pressed:
		var s = 1.0 if not event.shift_pressed else 5.0
		match event.keycode:
			KEY_UP:
				grid_offset.y -= s
			KEY_DOWN:
				grid_offset.y += s
			KEY_LEFT:
				grid_offset.x -= s
			KEY_RIGHT:
				grid_offset.x += s
			KEY_ENTER:
				print("[BuildingGrid] offset: ", grid_offset)
				return
			_:
				return
		queue_redraw()
		print("[BuildingGrid] offset: ", grid_offset)


func _draw() -> void:
	if not show_grid:
		return

	var hw = CELL_SIZE * 0.5
	var hh = CELL_SIZE * ISO_RATIO * 0.5

	for y in range(30):
		for x in range(30):
			var center = tile_to_world(Vector2i(x, y)) + grid_offset
			var diamond = [
				center + Vector2(0, -hh),
				center + Vector2(hw, 0),
				center + Vector2(0, hh),
				center + Vector2(-hw, 0),
			]
			var col = Color.YELLOW if not is_occupied(Vector2i(x, y)) else Color.RED
			for i in range(4):
				draw_line(diamond[i], diamond[(i + 1) % 4], Color(col, 0.3), 1.0)
