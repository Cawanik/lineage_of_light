# ==========================================
# knight_brain.gd — Мозг рыцаря
# ==========================================
# Умнее крестьянина: пытается обойти стены если путь не сильно длиннее
# Если обход слишком длинный — ломает стену
# Атакует здания на пути если они ближе трона
# ==========================================

class_name KnightBrain
extends EnemyBrain

## Рыцарь: тактический. Выбирает путь по реальной стоимости (время).
## Атакует башни на пути. Ломает стены если обход невыгоден.


func choose_path(detour_path: Array[Vector2i], straight_path: Array[Vector2i], e: Node) -> Array[Vector2i]:
	# Честный расчёт стоимости: движение + пролом
	var detour_cost = e._calculate_path_cost(detour_path)
	var straight_cost = e._calculate_path_cost(straight_path)
	if straight_cost <= detour_cost or detour_path.is_empty():
		return straight_path
	return detour_path


func on_wall_encountered(wall_key: String) -> void:
	if not enemy:
		return
	# Проверяем: есть ли обходной путь и выгоднее ли он
	var ps = enemy.get_node_or_null("/root/PathfindingSystem")
	if ps:
		var detour = ps.get_path_to_throne(enemy.current_tile)
		if not detour.is_empty():
			var straight = ps.get_path_ignoring_walls(enemy.current_tile)
			var detour_cost = enemy._calculate_path_cost(detour)
			var straight_cost = enemy._calculate_path_cost(straight)
			if detour_cost < straight_cost:
				# Обход выгоднее — идём в обход
				enemy.tile_path = detour
				enemy.path_index = 0
				enemy.move_progress = 0.0
				if enemy.tile_path.size() > 1 and enemy.tile_path[0] == enemy.current_tile:
					enemy.path_index = 1
				if enemy.path_index < enemy.tile_path.size():
					enemy.target_tile = enemy.tile_path[enemy.path_index]
				enemy.state = enemy.State.MOVING
				return
	# Обхода нет или он хуже — атакуем стену
	enemy.start_wall_attack(wall_key)


func on_wall_destroyed() -> void:
	if enemy:
		enemy.repath()


func should_attack_adjacent_towers() -> bool:
	return true  # Рыцарь сносит башни на пути


func should_abandon_wall_attack(detour_cost: float, remaining_time: float) -> bool:
	# Уходит если обход заметно быстрее (20% выгода)
	return detour_cost < remaining_time * 0.8
