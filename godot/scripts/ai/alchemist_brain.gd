class_name AlchemistBrain
extends EnemyBrain

## Алхимик: быстрый оппортунист. Выбирает путь по стоимости как рыцарь,
## но с уклоном к обходу (не любит тратить время на пролом).
## Не атакует башни — слишком занят бегом к трону.


func choose_path(detour_path: Array[Vector2i], straight_path: Array[Vector2i], e: Node) -> Array[Vector2i]:
	var detour_cost = e._calculate_path_cost(detour_path)
	var straight_cost = e._calculate_path_cost(straight_path)
	# Алхимик обходит если это не сильно длиннее (коэффициент 0.8 — скорее обойдёт)
	if detour_path.is_empty():
		return straight_path
	if straight_cost <= detour_cost * 0.8:
		return straight_path
	return detour_path


func on_wall_encountered(wall_key: String) -> void:
	if not enemy:
		return
	# Пробует обойти первым делом
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
	# Нет обхода — ломает
	enemy.start_wall_attack(wall_key)


func on_wall_destroyed() -> void:
	if enemy:
		enemy.repath()


func should_attack_adjacent_towers() -> bool:
	return false  # Алхимик не отвлекается


func should_abandon_wall_attack(detour_cost: float, remaining_time: float) -> bool:
	# Уходит если обход хоть немного быстрее
	return detour_cost < remaining_time
