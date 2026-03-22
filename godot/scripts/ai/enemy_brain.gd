# ==========================================
# enemy_brain.gd — Базовый мозг врага
# ==========================================
# Абстрактный класс. Наследники определяют поведение:
# - как враг выбирает цель
# - как реагирует на стены
# - приоритеты атаки
# ==========================================

class_name EnemyBrain
extends RefCounted

var enemy: Node = null


func setup(e: Node) -> void:
	enemy = e


## Вызывается каждый кадр — hook для динамического поведения
func process(_delta: float) -> void:
	pass


## Выбирает путь из двух вариантов: detour (обход) и straight (напролом)
## Возвращает выбранный path
func choose_path(detour_path: Array[Vector2i], straight_path: Array[Vector2i], e: Node) -> Array[Vector2i]:
	# Базовая реализация: по стоимости
	var detour_cost = e._calculate_path_cost(detour_path)
	var straight_cost = e._calculate_path_cost(straight_path)
	if straight_cost <= detour_cost or detour_path.is_empty():
		return straight_path
	return detour_path


## Реакция на стену на пути — brain решает: ломать или обходить
func on_wall_encountered(wall_key: String) -> void:
	if enemy:
		enemy.start_wall_attack(wall_key)


## Реакция на разрушение стены — обычно перепрокладываем путь
func on_wall_destroyed() -> void:
	if enemy:
		enemy.repath()


## Должен ли враг атаковать башни рядом при движении
func should_attack_adjacent_towers() -> bool:
	return false


## Дальность атаки в тайлах (1 = вплотную, 2 = через клетку)
func get_attack_range() -> int:
	return 1


## Возвращает тайл к которому нужно идти (обычно сам трон)
func get_path_target(ps: Node, _from: Vector2i, _building_grid: Node) -> Vector2i:
	return ps.throne_tile


## Стоит ли бросить атаку стены если открылся более быстрый путь
## detour_cost — время обходного пути, remaining_time — оставшееся время пролома
func should_abandon_wall_attack(_detour_cost: float, _remaining_time: float) -> bool:
	return false


## Тип проджектайла при атаке здания. "" = нет проджектайла (ближняя атака)
func get_projectile_type() -> String:
	return ""


## Вызывается при первом уроне (HP было полным). Brain может активировать баффы.
func on_first_hit() -> void:
	pass


## Возвращает здания рядом с целью которые тоже получают урон (клив).
## Пустой массив = нет клива (по умолчанию).
func get_cleave_targets(_attacking_building: Building, _attacker_tile: Vector2i, _building_grid: Node) -> Array[Building]:
	return [] as Array[Building]
