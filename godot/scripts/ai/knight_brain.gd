# ==========================================
# knight_brain.gd — Мозг рыцаря
# ==========================================
# Умнее крестьянина: пытается обойти стены если путь не сильно длиннее
# Если обход слишком длинный — ломает стену
# Атакует здания на пути если они ближе трона
# ==========================================

class_name KnightBrain
extends EnemyBrain

const MAX_DETOUR_RATIO = 1.5  # обходит если путь не длиннее чем в 1.5 раза


func get_attack_priority() -> String:
	return "nearest_building"


func on_wall_encountered(wall_key: String) -> void:
	if not enemy:
		return
	# Пробуем найти обходной путь
	var alt_path = enemy.find_alternative_path()
	if alt_path.size() > 0:
		var direct_dist = enemy.tile_path.size() if not enemy.tile_path.is_empty() else 999
		if alt_path.size() <= direct_dist * MAX_DETOUR_RATIO:
			enemy.tile_path = alt_path
			enemy.path_index = 0
			return
	# Обход слишком длинный — ломаем
	enemy.start_wall_attack(wall_key)


func on_wall_destroyed() -> void:
	if enemy:
		enemy.repath()
