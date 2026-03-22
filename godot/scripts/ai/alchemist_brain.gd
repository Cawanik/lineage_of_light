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
	var throne = ps.throne_tile
	var atk_range = get_attack_range()
	var best_tile = throne
	var best_dist = INF

	for dx in range(-atk_range, atk_range + 1):
		for dy in range(-atk_range, atk_range + 1):
			if maxi(absi(dx), absi(dy)) != atk_range:
				continue
			var tile = throne + Vector2i(dx, dy)
			if not ps.is_in_bounds(tile):
				continue
			if building_grid and building_grid.is_occupied(tile):
				continue
			var dist = float(from.distance_to(tile))
			if dist < best_dist:
				best_dist = dist
				best_tile = tile

	return best_tile


func get_projectile_type() -> String:
	return "poison_flask"


func on_first_hit() -> void:
	if enemy:
		enemy.activate_invincibility(3.0)
