# ==========================================
# mage_brain.gd — Мозг мага
# ==========================================
# Хитрый: избегает стен, ищет самый открытый путь
# Слабый DPS по стенам, предпочитает обход
# Атакует здания издалека (в будущем — рейнж атака)
# ==========================================

class_name MageBrain
extends EnemyBrain

const MAX_DETOUR_RATIO = 3.0  # маг готов идти в 3 раза дальше чтобы обойти


func get_attack_priority() -> String:
	return "throne"


func on_wall_encountered(wall_key: String) -> void:
	if not enemy:
		return
	# Маг сильно предпочитает обход
	var alt_path = enemy.find_alternative_path()
	if alt_path.size() > 0:
		enemy.tile_path = alt_path
		enemy.path_index = 0
		return
	# Крайний случай — бьёт стену (медленно)
	enemy.start_wall_attack(wall_key)


func on_wall_destroyed() -> void:
	if enemy:
		enemy.repath()
