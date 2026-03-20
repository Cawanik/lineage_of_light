# ==========================================
# base_tool.gd — Базовый класс инструментов
# ==========================================
# activate(ws) — включает инструмент
# deactivate() — вырубает
# update() — апдейт каждый кадр
# click() — клик мышой
# can_place_at(tile) — можно ли поставить/переместить на тайл
# is_tile_blocked(tile) — заблокирует ли путь
# flash_blocked_path() — подсветить путь красным
# get_building_grid() — найти BuildingGrid
# ==========================================

class_name BaseTool
extends RefCounted

var wall_system: WallSystem = null
var is_active: bool = false
var _building_grid: BuildingGrid = null
var _path_highlights: Array[Node2D] = []


func activate(ws: WallSystem) -> void:
	wall_system = ws
	is_active = true
	_building_grid = _find_building_grid()
	_on_activate()


func deactivate() -> void:
	if is_active:
		_on_deactivate()
	is_active = false
	_clear_path_highlights()


func update() -> void:
	if is_active:
		_on_update()


func click() -> void:
	if is_active:
		_on_click()


# === Общие проверки ===

func get_building_grid() -> BuildingGrid:
	if not _building_grid:
		_building_grid = _find_building_grid()
	return _building_grid


func can_place_at(tile: Vector2i, free_tile: Vector2i = Vector2i(-9999, -9999)) -> bool:
	var bg = get_building_grid()
	if not bg:
		return false
	if bg.is_occupied(tile) and tile != free_tile:
		return false
	if not PathChecker.can_place_building(bg, tile, free_tile):
		return false
	return true


func is_tile_blocked(tile: Vector2i) -> bool:
	var bg = get_building_grid()
	if not bg:
		return false
	return not PathChecker.can_place_building(bg, tile)


func get_preview_color(tile: Vector2i, from_tile: Vector2i = Vector2i(-9999, -9999)) -> Color:
	if not can_place_at(tile, from_tile):
		return Color(1.0, 0.3, 0.3, 0.5)
	return Color(0.4, 1.0, 0.4, 0.5)


func flash_blocked_path() -> void:
	_clear_path_highlights()
	var bg = get_building_grid()
	if not bg:
		return
	var path = PathChecker.get_path_to_border(bg)
	if path.is_empty():
		return

	var ground = wall_system.get_tree().current_scene.get_node_or_null("Ground") as TileMapLayer
	if not ground:
		return
	var ysort = wall_system.get_tree().current_scene.get_node_or_null("YSort")
	if not ysort:
		return

	var delay_per_tile = 0.04

	for i in range(path.size()):
		var tile = path[i]
		var marker = Node2D.new()
		marker.position = ground.map_to_local(tile) + ground.position
		marker.z_index = 90
		marker.modulate = Color(1, 1, 1, 0)

		var hw = 32.0
		var hh = 16.0
		var draw_node = marker
		draw_node.draw.connect(func():
			var diamond = PackedVector2Array([
				Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
			])
			draw_node.draw_colored_polygon(diamond, Color(1.0, 0.15, 0.15, 0.35))
		)
		ysort.add_child(marker)
		marker.queue_redraw()
		_path_highlights.append(marker)

		var appear_delay = i * delay_per_tile
		var tween = marker.create_tween()
		tween.tween_interval(appear_delay)
		tween.tween_property(marker, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_interval(1.0)
		tween.tween_property(marker, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
		tween.tween_callback(marker.queue_free)


func _clear_path_highlights() -> void:
	for h in _path_highlights:
		if is_instance_valid(h):
			h.queue_free()
	_path_highlights.clear()


func _find_building_grid() -> BuildingGrid:
	if not wall_system:
		return null
	var ysort = wall_system.get_parent()
	if ysort:
		return ysort.get_node_or_null("BuildingGrid")
	return null


# Override these in subclasses
func _on_activate() -> void:
	pass

func _on_deactivate() -> void:
	pass

func _on_update() -> void:
	pass

func _on_click() -> void:
	pass
