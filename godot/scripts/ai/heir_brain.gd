class_name HeirBrain
extends EnemyBrain

## Наследник: агрессивный босс. Всегда прёт напролом — обходы не для него.
## Сносит всё на пути: стены, башни, здания.
## Высокий wall_dps делает пролом быстрым.


func choose_path(detour_path: Array[Vector2i], straight_path: Array[Vector2i], _e: Node) -> Array[Vector2i]:
	# Наследник всегда идёт прямо как крестьянин, но осознанно
	if straight_path.is_empty():
		return detour_path
	return straight_path


func on_wall_encountered(wall_key: String) -> void:
	# Ломает без раздумий
	if enemy:
		enemy.start_wall_attack(wall_key)


func on_wall_destroyed() -> void:
	if enemy:
		enemy.repath()


func should_attack_adjacent_towers() -> bool:
	return true  # Наследник сносит всё что видит
