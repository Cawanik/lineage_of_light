# ==========================================
# base_tool.gd — Базовый класс инструментов
# ==========================================
# activate(ws) — включает инструмент, пихает ему wall_system
# deactivate() — вырубает инструмент нахуй
# update() — обновляет состояние, если активен, блять
# click() — обрабатывает клик мыши
# _on_activate() — виртуалка, переопределяй в наследниках
# _on_deactivate() — виртуалка для деактивации
# _on_update() — виртуалка для апдейта
# _on_click() — виртуалка для клика
# ==========================================

class_name BaseTool
extends RefCounted

## Base interface for all building tools (Build, Demolish, Move)

var wall_system: WallSystem = null
var is_active: bool = false


func activate(ws: WallSystem) -> void:
	wall_system = ws
	is_active = true
	_on_activate()


func deactivate() -> void:
	if is_active:
		_on_deactivate()
	is_active = false


func update() -> void:
	if is_active:
		_on_update()


func click() -> void:
	if is_active:
		_on_click()


# Override these in subclasses
func _on_activate() -> void:
	pass


func _on_deactivate() -> void:
	pass


func _on_update() -> void:
	pass


func _on_click() -> void:
	pass
