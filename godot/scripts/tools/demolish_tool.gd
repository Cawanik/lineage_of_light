# ==========================================
# demolish_tool.gd — Инструмент сноса, ёбаный разрушитель
# ==========================================
# _on_activate() — включает режим демонтажа, находит BuildingGrid
# _on_deactivate() — сбрасывает ховер и вырубает снос нахуй
# _on_update() — обновляет подсветку зданий и стен под мышкой
# _on_click() — сносит здание или стену, пиздец им
# _update_building_hover() — подсвечивает здание красным, если можно снести
# _reset_building_hover() — убирает подсветку, возвращает цвет обратно
# ==========================================

class_name DemolishTool
extends BaseTool

var building_grid: BuildingGrid = null
var _hovered_building_tile: Vector2i = Vector2i(-9999, -9999)


func _on_activate() -> void:
	wall_system.demolish_mode = true
	var ysort = wall_system.get_parent()
	if ysort:
		building_grid = ysort.get_node_or_null("BuildingGrid")


func _on_deactivate() -> void:
	_reset_building_hover()
	wall_system.clear_demolish_mode()


func _on_update() -> void:
	_update_building_hover()
	wall_system._update_demolish_hover()


func _on_click() -> void:
	# Check building first
	if building_grid and _hovered_building_tile != Vector2i(-9999, -9999):
		var building = building_grid.get_building(_hovered_building_tile)
		if building and building.can_demolish:
			building.modulate = Color.WHITE
			building_grid.remove_building(_hovered_building_tile)
			building.queue_free()
			_hovered_building_tile = Vector2i(-9999, -9999)
			return

	# Wall demolish
	wall_system.demolish_hovered()


func _update_building_hover() -> void:
	if not building_grid:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = building_grid.find_nearest_building(mouse_pos, 30.0)

	# Filter out non-demolishable
	if tile != Vector2i(-9999, -9999):
		var b = building_grid.get_building(tile)
		if not b or not b.can_demolish:
			tile = Vector2i(-9999, -9999)

	if tile != _hovered_building_tile:
		_reset_building_hover()
		_hovered_building_tile = tile
		if _hovered_building_tile != Vector2i(-9999, -9999):
			var b = building_grid.get_building(_hovered_building_tile)
			if b:
				b.modulate = Color(1.0, 0.3, 0.3)


func _reset_building_hover() -> void:
	if _hovered_building_tile != Vector2i(-9999, -9999) and building_grid:
		var b = building_grid.get_building(_hovered_building_tile)
		if b:
			b.modulate = Color.WHITE
	_hovered_building_tile = Vector2i(-9999, -9999)
