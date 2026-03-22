# ==========================================
# mage_brain.gd — Мозг мага
# ==========================================
# Хитрый: избегает стен, ищет самый открытый путь
# Слабый DPS по стенам, предпочитает обход
# Атакует здания издалека (в будущем — рейнж атака)
# ==========================================

class_name MageBrain
extends EnemyBrain

## Маг: трусливый хитрец. Всегда предпочитает обход.
## Ломает стены только если вообще нет другого пути.
## Не отвлекается на башни рядом — скользит мимо.


func choose_path(detour_path: Array[Vector2i], straight_path: Array[Vector2i], _e: Node) -> Array[Vector2i]:
	# Маг ВСЕГДА предпочитает обходной путь если он существует
	if not detour_path.is_empty():
		return detour_path
	return straight_path


func on_wall_encountered(wall_key: String) -> void:
	if not enemy:
		return
	# Маг пробует найти обход через PathfindingSystem
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
	# Нет обхода — бьёт стену нехотя
	enemy.start_wall_attack(wall_key)


func on_wall_destroyed() -> void:
	if enemy:
		enemy.repath()


func should_attack_adjacent_towers() -> bool:
	return false  # Маг не связывается с башнями


func should_abandon_wall_attack(detour_cost: float, remaining_time: float) -> bool:
	# Маг уходит при первой возможности — даже если обход чуть длиннее
	return detour_cost < remaining_time * 1.5
