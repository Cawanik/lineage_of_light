class_name MoveTool
extends BaseTool

var building_grid: BuildingGrid = null
var _moving_building_tile: Vector2i = Vector2i(-9999, -9999)
var _moving_building: bool = false
var _hovered_building_tile: Vector2i = Vector2i(-9999, -9999)
var _preview_node: Node2D = null  # container at tile position
var _preview_sprite: Sprite2D = null
var _last_preview_tile: Vector2i = Vector2i(-9999, -9999)


func _on_activate() -> void:
	wall_system.move_mode = true
	var ysort = wall_system.get_parent()
	if ysort:
		building_grid = ysort.get_node_or_null("BuildingGrid")


func _on_deactivate() -> void:
	# Reset building hover
	if _hovered_building_tile != Vector2i(-9999, -9999) and building_grid:
		var b = building_grid.get_building(_hovered_building_tile)
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
	if building_grid and wall_system.move_phase == "select":
		var mouse_pos = wall_system.get_global_mouse_position()
		var tile = building_grid.find_nearest_building(mouse_pos, 30.0)
		if tile != Vector2i(-9999, -9999):
			var building = building_grid.get_building(tile)
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

	var building = building_grid.get_building(tile)
	if building:
		building.modulate = Color(0.5, 0.7, 1.0)

		# Create preview: container + sprite child
		var data = Config.buildings.get(building.building_type, {})
		var offset = data.get("sprite_offset", [0.0, 0.0])

		_preview_node = Node2D.new()
		_preview_node.z_index = 100
		_preview_sprite = Sprite2D.new()
		_preview_sprite.texture = building.sprite.texture
		_preview_sprite.position = Vector2(offset[0], offset[1])
		_preview_sprite.modulate = Color(0.4, 0.8, 1.0, 0.5)
		_preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_preview_node.add_child(_preview_sprite)
		wall_system.get_tree().current_scene.add_child(_preview_node)


func _finish_building_move() -> void:
	var mouse_pos = wall_system.get_global_mouse_position()
	var target_tile = building_grid.world_to_tile(mouse_pos)

	var building = building_grid.get_building(_moving_building_tile)
	if building_grid.move_building(_moving_building_tile, target_tile):
		building = building_grid.get_building(target_tile)
		if building:
			building.modulate = Color.WHITE
	else:
		if building:
			building.modulate = Color.WHITE

	_clear_preview()
	_moving_building = false
	_moving_building_tile = Vector2i(-9999, -9999)
	wall_system.move_mode = true


func _update_building_hover() -> void:
	if not building_grid:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = building_grid.find_nearest_building(mouse_pos, 30.0)

	if tile != _hovered_building_tile:
		# Reset old hover
		if _hovered_building_tile != Vector2i(-9999, -9999):
			var old_b = building_grid.get_building(_hovered_building_tile)
			if old_b and old_b.can_move:
				old_b.modulate = Color.WHITE
		_hovered_building_tile = tile
		# Set new hover
		if _hovered_building_tile != Vector2i(-9999, -9999):
			var new_b = building_grid.get_building(_hovered_building_tile)
			if new_b and new_b.can_move:
				new_b.modulate = Color(0.3, 0.5, 1.0)


func _update_building_preview() -> void:
	if not _preview_node:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = building_grid.world_to_tile(mouse_pos)
	if tile != _last_preview_tile:
		_last_preview_tile = tile
		_preview_node.position = building_grid.tile_to_world(tile)
		var occupied = building_grid.is_occupied(tile) and tile != _moving_building_tile
		_preview_sprite.modulate = Color(1.0, 0.3, 0.3, 0.5) if occupied else Color(0.4, 0.8, 1.0, 0.5)


func _clear_preview() -> void:
	if _preview_node and is_instance_valid(_preview_node):
		_preview_node.queue_free()
		_preview_node = null
	_preview_sprite = null
	_last_preview_tile = Vector2i(-9999, -9999)


func _reset_building_move() -> void:
	if _moving_building:
		var building = building_grid.get_building(_moving_building_tile)
		if building:
			building.modulate = Color.WHITE
	_clear_preview()
	_moving_building = false
	_moving_building_tile = Vector2i(-9999, -9999)
