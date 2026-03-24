class_name AlchemistBrain
extends EnemyBrain

## Алхимик: оппортунист с дальней атакой (бросает зелья).
## Предпочитает обход, но ломает если прямой путь значительно короче.
## При первом ударе получает 3 секунды неуязвимости.


func choose_path(detour_path: Array[Vector2i], straight_path: Array[Vector2i], e: Node) -> Array[Vector2i]:
	var detour_cost = e._calculate_path_cost(detour_path)
	var straight_cost = e._calculate_path_cost(straight_path)
	if detour_path.is_empty():
		return straight_path
	if straight_cost <= detour_cost * 0.8:
		return straight_path
	return detour_path


func on_wall_encountered(wall_key: String) -> void:
	if not enemy:
		return
	var ps = enemy.get_node_or_null("/root/PathfindingSystem")
	if ps:
		var alt = ps.get_path_to_throne(enemy.current_tile)
		if alt.size() > 1:
			enemy.tile_path = alt
			enemy.path_index = 0
			if enemy.tile_path[0] == enemy.current_tile:
				enemy.path_index = 1
			if enemy.path_index < enemy.tile_path.size():
				enemy.target_tile = enemy.tile_path[enemy.path_index]
			enemy.state = enemy.State.MOVING
			return
	enemy.start_wall_attack(wall_key)


func on_wall_destroyed() -> void:
	if enemy:
		enemy.repath()


func should_attack_adjacent_towers() -> bool:
	return false


func should_abandon_wall_attack(detour_cost: float, remaining_time: float) -> bool:
	return detour_cost < remaining_time


func get_attack_range() -> int:
	return 2


func get_path_target(ps: Node, from: Vector2i, building_grid: Node) -> Vector2i:
	var atk_range = get_attack_range()
	var best_tile = ps.throne_tile
	var best_path_len = INF

	# Кандидаты: трон + все production здания
	var targets: Array[Vector2i] = [ps.throne_tile]
	if building_grid:
		for tile in building_grid.buildings.keys():
			var bld = building_grid.get_building(tile)
			if is_instance_valid(bld) and Config.buildings.get(bld.building_type, {}).get("type", "") == "production":
				targets.append(tile)

	for target_tile in targets:
		for dx in range(-atk_range, atk_range + 1):
			for dy in range(-atk_range, atk_range + 1):
				if maxi(absi(dx), absi(dy)) != atk_range:
					continue
				var candidate = target_tile + Vector2i(dx, dy)
				if not ps.is_in_bounds(candidate):
					continue
				if building_grid and building_grid.is_occupied(candidate):
					continue
				var path = ps.get_path_to_tile(from, candidate)
				if path.is_empty():
					continue
				if path.size() < best_path_len:
					best_path_len = path.size()
					best_tile = candidate

	return best_tile


func get_projectile_type() -> String:
	return "poison_flask"


func get_priority_attack_target(building_grid: Node, current_tile: Vector2i, attack_range: int) -> Building:
	if not building_grid:
		return null
	var best: Building = null
	var best_dist = INF
	for tile in building_grid.buildings.keys():
		var bld = building_grid.get_building(tile)
		if not is_instance_valid(bld) or Config.buildings.get(bld.building_type, {}).get("type", "") != "production":
			continue
		var dist = maxi(absi(tile.x - current_tile.x), absi(tile.y - current_tile.y))
		if dist <= attack_range and dist < best_dist:
			best_dist = dist
			best = bld
	return best


func on_first_hit() -> void:
	if enemy:
		enemy.activate_invincibility(3.0)
