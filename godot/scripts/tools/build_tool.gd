class_name BuildTool
extends BaseTool

var preview_node: Vector2i = Vector2i(-9999, -9999)
var preview_draw: Node2D = null


func _on_activate() -> void:
	wall_system.build_mode = true


func _on_deactivate() -> void:
	wall_system.clear_build_mode()
	preview_node = Vector2i(-9999, -9999)


func _on_update() -> void:
	wall_system._update_build_preview()


func _on_click() -> void:
	wall_system.place_at_preview()
