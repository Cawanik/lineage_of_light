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


func get_cleave_targets(attacking_building: Building, attacker_tile: Vector2i, building_grid: Node) -> Array[Building]:
	if not building_grid:
		return [] as Array[Building]

	# Определяем направление атаки: от атакующего к цели
	var target_tile = building_grid.world_to_tile(attacking_building.global_position)
	var dir = target_tile - attacker_tile

	# Перпендикуляр к направлению атаки — линия клива
	var perp: Vector2i
	if abs(dir.x) >= abs(dir.y):
		perp = Vector2i(0, 1)  # атака по горизонтали → клив по вертикали
	else:
		perp = Vector2i(1, 0)  # атака по вертикали → клив по горизонтали

	var result: Array[Building] = []
	for offset in [perp, -perp]:
		var check_tile = target_tile + offset
		var bld = building_grid.get_building(check_tile)
		if bld and bld is Building and bld != attacking_building:
			result.append(bld)
	return result
