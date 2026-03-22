# ==========================================
# peasant_brain.gd — Мозг крестьянина
# ==========================================
# Тупой: идёт к трону кратчайшим путём
# Бьёт стены если мешают
# Не пытается обходить, просто ломает
# ==========================================

class_name PeasantBrain
extends EnemyBrain

## Крестьянин: тупо прёт напролом кратчайшим путём.
## Ломает всё что мешает. Не отвлекается на башни рядом.


func choose_path(detour_path: Array[Vector2i], straight_path: Array[Vector2i], _e: Node) -> Array[Vector2i]:
	# Всегда идёт прямо — никакого расчёта стоимости
	if straight_path.is_empty():
		return detour_path
	return straight_path


func on_wall_encountered(wall_key: String) -> void:
	# Тупо бьёт стену, не думает об обходе
	if enemy:
		enemy.start_wall_attack(wall_key)


func on_wall_destroyed() -> void:
	if enemy:
		enemy.repath()


func should_attack_adjacent_towers() -> bool:
	return false  # Крестьянин не отвлекается — только трон
