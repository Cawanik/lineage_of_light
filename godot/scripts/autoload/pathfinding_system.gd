extends Node

## Central pathfinding brain — uses AStar2D (not AStarGrid2D) to support
## per-edge wall blocking via disconnect_points/connect_points.
## 4-directional movement (no diagonals) for clean wall interaction.
## Operates in tile coordinates (Vector2i 0..29).

signal path_grid_changed

var astar: AStar2D
var astar_full_open: AStar2D  # Полностью открытый граф — игнорирует и стены, и здания

var grid_size: Vector2i = Vector2i(30, 30)
var throne_tile: Vector2i = Vector2i(14, 15)


func _ready() -> void:
	var iso = Config.game.get("iso", {})
	grid_size = Vector2i(iso.get("grid_width", 30), iso.get("grid_height", 30))

	astar = AStar2D.new()
	astar_full_open = AStar2D.new()
	_build_graph(astar)
	_build_graph(astar_full_open)


func _build_graph(graph: AStar2D) -> void:
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			graph.add_point(_to_id(Vector2i(x, y)), Vector2(x, y))
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if x + 1 < grid_size.x:
				graph.connect_points(_to_id(Vector2i(x, y)), _to_id(Vector2i(x + 1, y)))
			if y + 1 < grid_size.y:
				graph.connect_points(_to_id(Vector2i(x, y)), _to_id(Vector2i(x, y + 1)))


func _to_id(tile: Vector2i) -> int:
	return tile.y * grid_size.x + tile.x


func _to_tile(id: int) -> Vector2i:
	return Vector2i(id % grid_size.x, id / grid_size.x)


func disable_edge(a: Vector2i, b: Vector2i) -> void:
	var id_a = _to_id(a)
	var id_b = _to_id(b)
	if astar.are_points_connected(id_a, id_b):
		astar.disconnect_points(id_a, id_b)
		print("PathfindingSystem: Disabled edge %s-%s" % [a, b])
	else:
		print("PathfindingSystem: Edge %s-%s was already disabled" % [a, b])
	path_grid_changed.emit()


func enable_edge(a: Vector2i, b: Vector2i) -> void:
	var id_a = _to_id(a)
	var id_b = _to_id(b)
	if not astar.are_points_connected(id_a, id_b):
		astar.connect_points(id_a, id_b)
	path_grid_changed.emit()


func set_tile_solid(tile: Vector2i, solid: bool) -> void:
	astar.set_point_disabled(_to_id(tile), solid)
	# astar_full_open намеренно не меняем — он игнорирует здания
	path_grid_changed.emit()


func get_path_to_throne(from: Vector2i) -> Array[Vector2i]:
	# Check if throne still exists
	if not _throne_exists():
		print("PathfindingSystem: No throne found - returning empty path")
		return [] as Array[Vector2i]
	
	if from == throne_tile:
		return [throne_tile] as Array[Vector2i]

	var path_ids = astar.get_id_path(_to_id(from), _to_id(throne_tile))
	var result: Array[Vector2i] = []
	for id in path_ids:
		result.append(_to_tile(id))
	return result


func _throne_exists() -> bool:
	"""Check if throne building still exists in the game world"""
	if throne_tile == Vector2i(-1, -1):
		return false
		
	# Try to find building grid and check for throne
	var main_scene = get_tree().current_scene
	if not main_scene:
		return false
		
	var building_grid = main_scene.get_node_or_null("YSort/BuildingGrid")
	if not building_grid:
		return false
		
	var throne = building_grid.get_building(throne_tile)
	return throne != null and throne.building_type == "throne"


func get_path_ignoring_walls(from: Vector2i) -> Array[Vector2i]:
	# Используем astar_full_open — истинно прямой путь, игнорирует и стены и здания
	if from == throne_tile:
		return [throne_tile] as Array[Vector2i]
	var path_ids = astar_full_open.get_id_path(_to_id(from), _to_id(throne_tile))
	var result: Array[Vector2i] = []
	for id in path_ids:
		result.append(_to_tile(id))
	return result


func get_path_to_tile(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return [to] as Array[Vector2i]
	var path_ids = astar.get_id_path(_to_id(from), _to_id(to))
	var result: Array[Vector2i] = []
	for id in path_ids:
		result.append(_to_tile(id))
	return result


func get_path_to_tile_ignoring_walls(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return [to] as Array[Vector2i]
	var path_ids = astar_full_open.get_id_path(_to_id(from), _to_id(to))
	var result: Array[Vector2i] = []
	for id in path_ids:
		result.append(_to_tile(id))
	return result


func get_path_cost(from: Vector2i) -> float:
	var path = get_path_to_throne(from)
	if path.is_empty():
		return INF
	return float(path.size())


func is_in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < grid_size.x and tile.y >= 0 and tile.y < grid_size.y


func clear_throne() -> void:
	"""Called when throne is destroyed - invalidate throne pathfinding"""
	print("PathfindingSystem: Throne destroyed, clearing throne_tile")
	throne_tile = Vector2i(-1, -1)
	path_grid_changed.emit()
