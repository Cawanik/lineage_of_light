# ==========================================
# build_tool.gd — Инструмент постройки стен
# ==========================================

class_name BuildTool
extends BaseTool


func _on_activate() -> void:
	wall_system.build_mode = true


func _on_deactivate() -> void:
	wall_system.clear_build_mode()


func _on_update() -> void:
	wall_system._update_build_preview()


func _on_click() -> void:
	var bg = get_building_grid()
	if bg:
		var mouse_pos = wall_system.get_global_mouse_position()
		var tile = bg.world_to_tile(mouse_pos)
		if bg.is_occupied(tile):
			return

	wall_system.place_at_preview()
