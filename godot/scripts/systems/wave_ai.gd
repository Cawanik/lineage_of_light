class_name WaveAI
extends RefCounted

## Phase 1 AI: selects spawn direction based on weakest defense side.
## Evaluates path cost from each perimeter side to the throne —
## lower cost means less walls/obstacles = weaker defense.


static func select_spawn_side(ps: Node) -> SpawnZone.Side:
	var best_side: SpawnZone.Side = SpawnZone.Side.NORTH
	var best_cost: float = INF

	for side in [SpawnZone.Side.NORTH, SpawnZone.Side.EAST,
				SpawnZone.Side.SOUTH, SpawnZone.Side.WEST]:
		var tiles = SpawnZone.get_side_tiles(side)
		var total_cost: float = 0.0
		var valid_count: int = 0
		# Sample every 3rd tile for performance
		for i in range(0, tiles.size(), 3):
			# Берём минимальное из: обходного и прямого пути
			# Прямой путь считаем через astar_full_open с длиной как приближение
			var open_path = ps.get_path_ignoring_walls(tiles[i])
			var detour_path = ps.get_path_to_throne(tiles[i])
			var open_cost = open_path.size() if not open_path.is_empty() else INF
			var detour_cost = detour_path.size() if not detour_path.is_empty() else INF
			var cost = minf(open_cost, detour_cost)
			if cost < INF:
				total_cost += cost
				valid_count += 1
		var avg = total_cost / maxf(valid_count, 1.0) if valid_count > 0 else INF
		if avg < best_cost:
			best_cost = avg
			best_side = side

	return best_side


static func select_spawn_sides_weighted(ps: Node) -> Array[SpawnZone.Side]:
	var primary = select_spawn_side(ps)
	var sides: Array[SpawnZone.Side] = [primary]
	# 30% chance to add a random second direction
	if randf() < 0.3:
		var all_sides: Array[SpawnZone.Side] = [
			SpawnZone.Side.NORTH, SpawnZone.Side.EAST,
			SpawnZone.Side.SOUTH, SpawnZone.Side.WEST,
		]
		all_sides.erase(primary)
		sides.append(all_sides[randi() % all_sides.size()])
	return sides
