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


## Вызывается каждый кадр для обработки AI
func process(delta: float) -> void:
	pass


## Выбирает следующую цель для движения/атаки
func choose_target() -> void:
	pass


## Реакция на стену на пути
func on_wall_encountered(wall_key: String) -> void:
	pass


## Реакция на разрушение стены
func on_wall_destroyed() -> void:
	pass


## Приоритет цели: что атаковать первым
func get_attack_priority() -> String:
	return "throne"  # по умолчанию — идём к трону
