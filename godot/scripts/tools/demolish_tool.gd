# ==========================================
# demolish_tool.gd — Инструмент сноса, поддержка сноса по линии
# ==========================================

class_name DemolishTool
extends BaseTool

var _hovered_building_tile: Vector2i = Vector2i(-9999, -9999)

# Снос по линии
var _dragging: bool = false
var _drag_start_tile: Vector2i = Vector2i(-9999, -9999)
var _drag_current_tile: Vector2i = Vector2i(-9999, -9999)
var _line_highlights: Array[Node2D] = []


func _on_activate() -> void:
	wall_system.demolish_mode = true


func _on_deactivate() -> void:
	_reset_building_hover()
	_clear_line_highlights()
	wall_system.clear_demolish_mode()


func _on_update() -> void:
	if _dragging:
		var bg = get_building_grid()
		if bg:
			var mouse_pos = wall_system.get_global_mouse_position()
			_drag_current_tile = bg.world_to_tile(mouse_pos)
			_update_line_highlights()
	else:
		_update_building_hover()
		wall_system._update_demolish_hover()


func _on_click() -> void:
	var bg = get_building_grid()
	if not bg:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = bg.world_to_tile(mouse_pos)

	_dragging = true
	_drag_start_tile = tile
	_drag_current_tile = tile


func on_release() -> void:
	if not _dragging:
		return
	_dragging = false

	var bg = get_building_grid()
	if not bg:
		_clear_line_highlights()
		return

	var tiles = _get_line_tiles(_drag_start_tile, _drag_current_tile)

	var demolished = 0
	for t in tiles:
		var building = bg.get_building(t)
		if building and building.can_demolish:
			building.modulate = Color.WHITE
			bg.remove_building(t)
			DustEffect.spawn(wall_system.get_tree(), bg.tile_to_world(t))
			building.queue_free()
			demolished += 1

	if demolished > 0:
		var am = wall_system.get_node_or_null("/root/AudioManager")
		if am:
			am.play("demolish")

	_clear_line_highlights()
	_hovered_building_tile = Vector2i(-9999, -9999)

	var main = wall_system.get_tree().current_scene
	if main.has_method("refresh_flat_view"):
		main.refresh_flat_view()


func _get_line_tiles(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var diff = to - from
	var steps = maxi(absi(diff.x), absi(diff.y))
	if steps == 0:
		result.append(from)
		return result
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var x = roundi(lerpf(from.x, to.x, t))
		var y = roundi(lerpf(from.y, to.y, t))
		var tile = Vector2i(x, y)
		if result.is_empty() or result[-1] != tile:
			result.append(tile)
	return result


func _update_line_highlights() -> void:
	_clear_line_highlights()
	var bg = get_building_grid()
	if not bg:
		return

	var tiles = _get_line_tiles(_drag_start_tile, _drag_current_tile)
	var ground = wall_system.get_tree().current_scene.get_node_or_null("Ground") as TileMapLayer
	var ysort = wall_system.get_tree().current_scene.get_node_or_null("YSort")
	if not ground or not ysort:
		return

	for t in tiles:
		var building = bg.get_building(t)
		var has_building = building and building.can_demolish

		var marker = Node2D.new()
		marker.position = ground.map_to_local(t) + ground.position
		marker.z_index = 80
		var color = Color(1.0, 0.2, 0.2, 0.35) if has_building else Color(0.5, 0.5, 0.5, 0.15)
		var draw_node = marker
		draw_node.draw.connect(func():
			var hw = 32.0
			var hh = 16.0
			var diamond = PackedVector2Array([
				Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
			])
			draw_node.draw_colored_polygon(diamond, color)
		)
		ysort.add_child(marker)
		marker.queue_redraw()
		_line_highlights.append(marker)

		# Подсвечиваем здание красным
		if has_building:
			building.modulate = Color(1.0, 0.3, 0.3)


func _clear_line_highlights() -> void:
	# Сбрасываем модуляцию зданий
	var bg = get_building_grid()
	if bg:
		for h in _line_highlights:
			pass
		# Сбрасываем все подсвеченные здания
		for tile in bg.buildings:
			var b = bg.get_building(tile)
			if b:
				b.modulate = Color.WHITE

	for h in _line_highlights:
		if is_instance_valid(h):
			h.queue_free()
	_line_highlights.clear()


func _update_building_hover() -> void:
	var bg = get_building_grid()
	if not bg:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = bg.find_nearest_building(mouse_pos, 30.0)

	if tile != Vector2i(-9999, -9999):
		var b = bg.get_building(tile)
		if not b or not b.can_demolish:
			tile = Vector2i(-9999, -9999)

	if tile != _hovered_building_tile:
		_reset_building_hover()
		_hovered_building_tile = tile
		if _hovered_building_tile != Vector2i(-9999, -9999):
			var b = bg.get_building(_hovered_building_tile)
			if b:
				b.modulate = Color(1.0, 0.3, 0.3)


func _reset_building_hover() -> void:
	var bg = get_building_grid()
	if _hovered_building_tile != Vector2i(-9999, -9999) and bg:
		var b = bg.get_building(_hovered_building_tile)
		if b:
			b.modulate = Color.WHITE
	_hovered_building_tile = Vector2i(-9999, -9999)
