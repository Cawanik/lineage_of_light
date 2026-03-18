# ==========================================
# place_building_tool.gd — Инструмент размещения зданий
# ==========================================
# set_building_type(type) — задаёт тип здания, которое будем хуярить
# _on_activate() — находит BuildingGrid и создаёт превью
# _on_deactivate() — убирает превью нахуй
# _on_update() — таскает превью за мышкой, красит в красный если занято
# _on_click() — ставит здание на тайл, списывает золото, блять
# _create_preview() — создаёт полупрозрачный спрайт-призрак
# _remove_preview() — удаляет превью из сцены
# ==========================================

class_name PlaceBuildingTool
extends BaseTool

var building_grid: BuildingGrid = null
var building_type: String = ""
var preview: Sprite2D = null
var building_scene: PackedScene = preload("res://scenes/buildings/building.tscn")


func set_building_type(type: String) -> void:
	building_type = type


func _on_activate() -> void:
	OcclusionFade.build_mode_active = true
	var ysort = wall_system.get_parent()
	if ysort:
		building_grid = ysort.get_node_or_null("BuildingGrid")
	_create_preview()


func _on_deactivate() -> void:
	_remove_preview()
	OcclusionFade.build_mode_active = false


func _on_update() -> void:
	if not preview or not building_grid:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	OcclusionFade.build_mode_cursor = mouse_pos
	var tile = building_grid.world_to_tile(mouse_pos)
	var world_pos = building_grid.tile_to_world(tile)
	preview.position = world_pos

	var data = Config.buildings.get(building_type, {})
	var offset = data.get("sprite_offset", [0.0, 0.0])
	preview.offset = Vector2(offset[0], offset[1])

	if building_grid.is_occupied(tile):
		preview.modulate = Color(1.0, 0.3, 0.3, 0.5)
	else:
		preview.modulate = Color(0.4, 1.0, 0.4, 0.5)


func _on_click() -> void:
	if not building_grid:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = building_grid.world_to_tile(mouse_pos)
	if building_grid.is_occupied(tile):
		return

	var data = Config.buildings.get(building_type, {})
	var cost = int(data.get("cost", 0))
	if not GameManager.spend_gold(cost):
		return

	var building = building_scene.instantiate()
	building_grid.place_building(tile, building)
	building.setup(building_type)


func _create_preview() -> void:
	var data = Config.buildings.get(building_type, {})
	var sprite_path = data.get("sprite", "")
	if sprite_path == "" or not ResourceLoader.exists(sprite_path):
		return

	preview = Sprite2D.new()
	preview.texture = load(sprite_path)
	preview.modulate = Color(0.4, 1.0, 0.4, 0.5)
	preview.z_index = 100
	wall_system.get_tree().current_scene.add_child(preview)


func _remove_preview() -> void:
	if is_instance_valid(preview):
		preview.queue_free()
		preview = null
