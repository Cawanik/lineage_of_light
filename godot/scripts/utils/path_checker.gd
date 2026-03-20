# ==========================================
# path_checker.gd — Проверка пути от трона до спавн-зон
# ==========================================
# can_place_building(tile) — проверяет, можно ли поставить здание
#   не заблокировав путь от трона до пшеницы
# has_path_to_border() — есть ли хоть один путь от трона до спавн-тайлов
# _bfs(from, targets, blocked) — BFS поиск пути на сетке
# ==========================================

class_name PathChecker
extends RefCounted


static func can_place_building(building_grid: BuildingGrid, tile: Vector2i, free_tile: Vector2i = Vector2i(-9999, -9999)) -> bool:
	# Если тайл уже занят — не наша проблема
	if building_grid.is_occupied(tile) and tile != free_tile:
		return false

	# Найдём трон
	var throne_tile = _find_throne(building_grid)
	if throne_tile == Vector2i(-9999, -9999):
		return true

	# Найдём спавн-тайлы (пшеница/бордюр)
	var border_tiles = _get_border_tiles()
	if border_tiles.is_empty():
		return true

	# Симулируем: добавляем tile в blocked, освобождаем free_tile
	var extra_blocked = {tile: true}
	var extra_free = {}
	if free_tile != Vector2i(-9999, -9999):
		extra_free[free_tile] = true
	return _bfs(throne_tile, border_tiles, building_grid, extra_blocked, extra_free)


static func has_path_to_border(building_grid: BuildingGrid) -> bool:
	var throne_tile = _find_throne(building_grid)
	if throne_tile == Vector2i(-9999, -9999):
		return true
	var border_tiles = _get_border_tiles()
	if border_tiles.is_empty():
		return true
	return _bfs(throne_tile, border_tiles, building_grid, {})


static func _find_throne(building_grid: BuildingGrid) -> Vector2i:
	for tile in building_grid.buildings:
		if is_instance_valid(building_grid.buildings[tile]):
			var b = building_grid.buildings[tile]
			if b.building_type == "throne":
				return tile
	return Vector2i(-9999, -9999)


static func _get_border_tiles() -> Array[Vector2i]:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.current_scene:
		return []
	var ground = tree.current_scene.get_node_or_null("Ground")
	if not ground or not ground is IsoGround:
		return []

	var result: Array[Vector2i] = []
	var cells = ground.get_used_cells()
	for cell in cells:
		if ground.is_border(cell.x, cell.y):
			result.append(cell)
	return result


static func get_path_to_border(building_grid: BuildingGrid, extra_blocked: Dictionary = {}) -> Array[Vector2i]:
	var throne_tile = _find_throne(building_grid)
	if throne_tile == Vector2i(-9999, -9999):
		return []
	var border_tiles = _get_border_tiles()
	if border_tiles.is_empty():
		return []
	return _bfs_path(throne_tile, border_tiles, building_grid, extra_blocked)


static func _bfs_path(from: Vector2i, targets: Array[Vector2i], building_grid: BuildingGrid, extra_blocked: Dictionary) -> Array[Vector2i]:
	var target_set: Dictionary = {}
	for t in targets:
		target_set[t] = true

	var visited: Dictionary = {}
	var parent_map: Dictionary = {}
	var queue: Array[Vector2i] = [from]
	visited[from] = true

	var cardinal = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var current = queue.pop_front()

		if target_set.has(current):
			# Восстанавливаем путь
			var path: Array[Vector2i] = []
			var node = current
			while node != from:
				path.append(node)
				node = parent_map[node]
			path.append(from)
			path.reverse()
			return path

		for dir in cardinal:
			var neighbor = current + dir
			if visited.has(neighbor):
				continue
			visited[neighbor] = true

			if extra_blocked.has(neighbor):
				continue
			if building_grid.buildings.has(neighbor):
				continue
			if building_grid.wall_system and building_grid.wall_system.nodes.has(neighbor):
				continue
			if not _is_on_ground(neighbor):
				continue

			parent_map[neighbor] = current
			queue.append(neighbor)

	return []


static func _bfs(from: Vector2i, targets: Array[Vector2i], building_grid: BuildingGrid, extra_blocked: Dictionary, extra_free: Dictionary = {}) -> bool:
	var target_set: Dictionary = {}
	for t in targets:
		target_set[t] = true

	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [from]
	visited[from] = true

	var cardinal = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var current = queue.pop_front()

		if target_set.has(current):
			return true

		for dir in cardinal:
			var neighbor = current + dir
			if visited.has(neighbor):
				continue
			visited[neighbor] = true

			# Проверяем проходимость
			if extra_blocked.has(neighbor):
				continue
			if not extra_free.has(neighbor):
				if building_grid.buildings.has(neighbor):
					continue
				if building_grid.wall_system and building_grid.wall_system.nodes.has(neighbor):
					continue

			if not _is_on_ground(neighbor):
				continue

			queue.append(neighbor)

	return false


static func _is_on_ground(tile: Vector2i) -> bool:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.current_scene:
		return false
	var ground = tree.current_scene.get_node_or_null("Ground")
	if ground and ground is IsoGround:
		return ground.get_cell_source_id(tile) != -1
	return false
