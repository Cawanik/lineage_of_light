class_name BuildTool
extends BaseTool

var building_grid: BuildingGrid = null


func _on_activate() -> void:
	wall_system.build_mode = true
	var ysort = wall_system.get_parent()
	if ysort:
		building_grid = ysort.get_node_or_null("BuildingGrid")


func _on_deactivate() -> void:
	wall_system.clear_build_mode()


func _on_update() -> void:
	wall_system._update_build_preview()


func _on_click() -> void:
	# Check if tile is occupied by a building
	if building_grid:
		var mouse_pos = wall_system.get_global_mouse_position()
		var tile = building_grid.world_to_tile(mouse_pos)
		if building_grid.is_occupied(tile):
			return  # can't build on occupied tile

	wall_system.place_at_preview()
