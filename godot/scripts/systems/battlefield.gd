# ==========================================
# battlefield.gd — Анализ поля боя
# ==========================================
# Читает TileMap и BuildingGrid, строит карту проходимости
# Вызывается перед началом боевой фазы
# Выдаёт информацию для планировщика врагов
# ==========================================

class_name Battlefield
extends RefCounted

# Типы тайлов для навигации
enum TileType { EMPTY, GROUND, BORDER, BUILDING, WALL, THRONE, UNKNOWN }

var _tile_map: Dictionary = {}  # Vector2i -> TileType
var _buildings: Dictionary = {}  # Vector2i -> Building reference
var _throne_tile: Vector2i = Vector2i(-9999, -9999)
var _spawn_tiles: Array[Vector2i] = []
var _ground: TileMapLayer = null
var _building_grid: BuildingGrid = null


func scan(tree: SceneTree) -> void:
	_tile_map.clear()
	_buildings.clear()
	_spawn_tiles.clear()

	var scene = tree.current_scene
	if not scene:
		return

	_ground = scene.get_node_or_null("Ground") as TileMapLayer
	_building_grid = scene.get_node_or_null("YSort/BuildingGrid") as BuildingGrid

	if not _ground or not _building_grid:
		return

	_scan_tiles()
	_scan_buildings()
	_scan_spawn_zones()


func _scan_tiles() -> void:
	var cells = _ground.get_used_cells()
	for cell in cells:
		if _ground is IsoGround and _ground.is_border(cell.x, cell.y):
			_tile_map[cell] = TileType.BORDER
		else:
			_tile_map[cell] = TileType.GROUND


func _scan_buildings() -> void:
	for tile in _building_grid.buildings:
		var b = _building_grid.get_building(tile)
		if not b:
			continue
		_buildings[tile] = b
		if b.building_type == "throne":
			_tile_map[tile] = TileType.THRONE
			_throne_tile = tile
		else:
			_tile_map[tile] = TileType.BUILDING

	# Стены
	if _building_grid.wall_system:
		for node_pos in _building_grid.wall_system.nodes:
			_tile_map[node_pos] = TileType.WALL


func _scan_spawn_zones() -> void:
	for tile in _tile_map:
		if _tile_map[tile] == TileType.BORDER:
			_spawn_tiles.append(tile)


# === Запросы к полю ===

func get_tile_type(tile: Vector2i) -> TileType:
	return _tile_map.get(tile, TileType.UNKNOWN)


func is_walkable(tile: Vector2i) -> bool:
	var t = get_tile_type(tile)
	return t == TileType.GROUND or t == TileType.BORDER or t == TileType.THRONE


func is_blocked(tile: Vector2i) -> bool:
	var t = get_tile_type(tile)
	return t == TileType.BUILDING or t == TileType.WALL


func get_throne_tile() -> Vector2i:
	return _throne_tile


func get_spawn_tiles() -> Array[Vector2i]:
	return _spawn_tiles


func get_building_at(tile: Vector2i) -> Node:
	return _buildings.get(tile, null)


func get_neighbors(tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var n = tile + d
		if _tile_map.has(n):
			result.append(n)
	return result


func get_walkable_neighbors(tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for n in get_neighbors(tile):
		if is_walkable(n):
			result.append(n)
	return result


## BFS путь от start до end, только по проходимым тайлам
func find_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var visited: Dictionary = {}
	var parent: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true

	while not queue.is_empty():
		var current = queue.pop_front()
		if current == end:
			var path: Array[Vector2i] = []
			var node = current
			while node != start:
				path.append(node)
				node = parent[node]
			path.append(start)
			path.reverse()
			return path

		for n in get_walkable_neighbors(current):
			if not visited.has(n):
				visited[n] = true
				parent[n] = current
				queue.append(n)

	return []


## Находит ближайший блокирующий тайл на пути
func find_first_blocker(path: Array[Vector2i]) -> Dictionary:
	for i in range(path.size()):
		var tile = path[i]
		if is_blocked(tile):
			return {"tile": tile, "type": get_tile_type(tile), "index": i}
	return {}


## Все здания в радиусе от тайла
func get_buildings_in_radius(center: Vector2i, radius: int) -> Array:
	var result: Array = []
	for tile in _buildings:
		var dx = absi(tile.x - center.x)
		var dy = absi(tile.y - center.y)
		if sqrt(float(dx * dx + dy * dy)) <= float(radius) + 0.5:
			result.append({"tile": tile, "building": _buildings[tile]})
	return result
