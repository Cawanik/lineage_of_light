class_name EnemyData
extends RefCounted

# Данные врагов теперь в config/enemies.json
# Этот класс оставлен для обратной совместимости
static var ENEMIES: Dictionary:
	get:
		return Config.enemies
