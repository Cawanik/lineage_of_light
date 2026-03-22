# ==========================================
# move_tool.gd — Инструмент перемещения, тащи куда хочешь
# ==========================================
# _on_activate() — врубает режим перемещения, ищет BuildingGrid
# _on_deactivate() — сбрасывает всё на хуй, ховеры и превью
# _on_update() — обновляет превью перемещения или ховер зданий
# _on_click() — выбирает здание/стену или ставит на новое место
# _start_building_move(tile) — начинает перетаскивание здания, создаёт превью-спрайт
# _finish_building_move() — завершает перемещение, пихает здание на новый тайл
# _update_building_hover() — подсвечивает здание синим при наведении
# _update_building_preview() — двигает призрачный спрайт за мышкой, ёпта
# _clear_preview() — убирает превью-ноду нахуй
# _reset_building_move() — отменяет перемещение, сбрасывает состояние
# ==========================================

class_name MoveTool
extends BaseTool

var _moving_building_tile: Vector2i = Vector2i(-9999, -9999)
var _moving_building: bool = false
var _moving_building_type: String = ""
var _hovered_building_tile: Vector2i = Vector2i(-9999, -9999)
var _preview_node: Node2D = null  # container at tile position
var _preview_sprite: Sprite2D = null
var _last_preview_tile: Vector2i = Vector2i(-9999, -9999)


func _on_activate() -> void:
	wall_system.move_mode = true


func _on_deactivate() -> void:
	# Reset building hover
	if _hovered_building_tile != Vector2i(-9999, -9999) and get_building_grid():
		var b = get_building_grid().get_building(_hovered_building_tile)
		if b:
			b.modulate = Color.WHITE
	_hovered_building_tile = Vector2i(-9999, -9999)
	_reset_building_move()
	wall_system.clear_move_mode()


func _on_update() -> void:
	if _moving_building:
		_update_building_preview()
	else:
		_update_building_hover()
		wall_system._update_move_preview()


func _on_click() -> void:
	if _moving_building:
		_finish_building_move()
		return

	# Check if clicking on a building first
	if get_building_grid() and wall_system.move_phase == "select":
		var mouse_pos = wall_system.get_global_mouse_position()
		var tile = get_building_grid().find_nearest_building(mouse_pos, 30.0)
		if tile != Vector2i(-9999, -9999):
			var building = get_building_grid().get_building(tile)
			if building and building.can_move:
				_start_building_move(tile)
				return

	# Wall move
	if wall_system.move_phase == "select":
		wall_system.move_select()
	elif wall_system.move_phase == "place":
		wall_system.move_place()


func _start_building_move(tile: Vector2i) -> void:
	_moving_building = true
	_moving_building_tile = tile
	wall_system.move_mode = false

	var building = get_building_grid().get_building(tile)
	if building:
		building.modulate = Color(0.5, 0.7, 1.0)
		_moving_building_type = building.building_type

		# Create preview: container + sprite child
		var data = Config.buildings.get(building.building_type, {})
		var offset = data.get("sprite_offset", [0.0, 0.0])

		_preview_node = Node2D.new()
		_preview_node.z_index = 100
		_preview_sprite = Sprite2D.new()
		_preview_sprite.texture = building.sprite.texture
		_preview_sprite.position = Vector2(offset[0], offset[1])
		var sc = data.get("sprite_scale", [1.0, 1.0])
		_preview_sprite.scale = Vector2(sc[0], sc[1])
		_preview_sprite.modulate = Color(0.4, 0.8, 1.0, 0.5)
		_preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_preview_node.add_child(_preview_sprite)
		wall_system.get_tree().current_scene.add_child(_preview_node)


func _finish_building_move() -> void:
	var mouse_pos = wall_system.get_global_mouse_position()
	var target_tile = get_building_grid().world_to_tile(mouse_pos)

	# Проверяем не заблокирует ли перемещение путь
	if target_tile != _moving_building_tile:
		var bg = get_building_grid()
		# Тайл занят или за картой — просто не даём переместить
		if bg.is_occupied(target_tile) and target_tile != _moving_building_tile:
			return
		# Тайл свободный, но блокирует путь — рисуем путь
		if not can_place_at(target_tile, _moving_building_tile):
			flash_blocked_path()
			return

	var bg = get_building_grid()
	var building = bg.get_building(_moving_building_tile)
	if bg.move_building(_moving_building_tile, target_tile):
		DustEffect.spawn(wall_system.get_tree(), bg.tile_to_world(target_tile))
		building = bg.get_building(target_tile)
		if building:
			building.modulate = Color.WHITE
	else:
		if building:
			building.modulate = Color.WHITE

	_clear_preview()
	_clear_range_highlights()
	_moving_building = false
	_moving_building_tile = Vector2i(-9999, -9999)
	_moving_building_type = ""
	wall_system.move_mode = true

	var main = wall_system.get_tree().current_scene
	if main.has_method("refresh_flat_view"):
		main.refresh_flat_view()


func _update_building_hover() -> void:
	if not get_building_grid():
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = get_building_grid().find_nearest_building(mouse_pos, 30.0)

	if tile != _hovered_building_tile:
		# Reset old hover
		if _hovered_building_tile != Vector2i(-9999, -9999):
			var old_b = get_building_grid().get_building(_hovered_building_tile)
			if old_b and old_b.can_move:
				old_b.modulate = Color.WHITE
		_hovered_building_tile = tile
		# Set new hover
		if _hovered_building_tile != Vector2i(-9999, -9999):
			var new_b = get_building_grid().get_building(_hovered_building_tile)
			if new_b and new_b.can_move:
				new_b.modulate = Color(0.3, 0.5, 1.0)


func _update_building_preview() -> void:
	if not _preview_node:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = get_building_grid().world_to_tile(mouse_pos)
	if tile != _last_preview_tile:
		_last_preview_tile = tile
		_preview_node.position = get_building_grid().tile_to_world(tile)
		var placeable = can_place_at(tile, _moving_building_tile)
		_preview_sprite.modulate = Color(0.4, 0.8, 1.0, 0.5) if placeable else Color(1.0, 0.3, 0.3, 0.5)
		show_tile_highlight(tile, placeable)
		show_attack_range(tile, _moving_building_type)


func _clear_preview() -> void:
	if _preview_node and is_instance_valid(_preview_node):
		_preview_node.queue_free()
		_preview_node = null
	_preview_sprite = null
	_last_preview_tile = Vector2i(-9999, -9999)


func _reset_building_move() -> void:
	if _moving_building:
		var building = get_building_grid().get_building(_moving_building_tile)
		if building:
			building.modulate = Color.WHITE
	_clear_preview()
	_moving_building = false
	_moving_building_tile = Vector2i(-9999, -9999)
