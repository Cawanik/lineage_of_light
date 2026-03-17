class_name DemolishTool
extends BaseTool


func _on_activate() -> void:
	wall_system.demolish_mode = true


func _on_deactivate() -> void:
	wall_system.clear_demolish_mode()


func _on_update() -> void:
	wall_system._update_demolish_hover()


func _on_click() -> void:
	wall_system.demolish_hovered()
