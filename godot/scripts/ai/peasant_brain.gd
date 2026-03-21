# ==========================================
# peasant_brain.gd — Мозг крестьянина
# ==========================================
# Тупой: идёт к трону кратчайшим путём
# Бьёт стены если мешают
# Не пытается обходить, просто ломает
# ==========================================

class_name PeasantBrain
extends EnemyBrain


func get_attack_priority() -> String:
	return "throne"


func on_wall_encountered(wall_key: String) -> void:
	# Крестьянин тупо бьёт стену
	if enemy:
		enemy.start_wall_attack(wall_key)


func on_wall_destroyed() -> void:
	# Стена сломана — продолжаем идти
	if enemy:
		enemy.repath()
