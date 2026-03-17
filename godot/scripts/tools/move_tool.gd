class_name MoveTool
extends BaseTool


func _on_activate() -> void:
	wall_system.move_mode = true


func _on_deactivate() -> void:
	wall_system.clear_move_mode()


func _on_update() -> void:
	wall_system._update_move_preview()


func _on_click() -> void:
	if wall_system.move_phase == "select":
		wall_system.move_select()
	elif wall_system.move_phase == "place":
		wall_system.move_place()
