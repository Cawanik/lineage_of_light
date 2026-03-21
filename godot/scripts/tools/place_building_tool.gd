# ==========================================
# place_building_tool.gd — Инструмент размещения зданий
# ==========================================

class_name PlaceBuildingTool
extends BaseTool

var building_type: String = ""
var preview: Sprite2D = null
var building_scene: PackedScene = preload("res://scenes/buildings/building.tscn")


func set_building_type(type: String) -> void:
	building_type = type


func _on_activate() -> void:
	_create_preview()


func _on_deactivate() -> void:
	_remove_preview()


func _on_update() -> void:
	var bg = get_building_grid()
	if not preview or not bg:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = bg.world_to_tile(mouse_pos)
	preview.position = bg.tile_to_world(tile)

	var data = Config.buildings.get(building_type, {})
	var offset = data.get("sprite_offset", [0.0, 0.0])
	preview.offset = Vector2(offset[0], offset[1])
	var sc = data.get("sprite_scale", [1.0, 1.0])
	preview.scale = Vector2(sc[0], sc[1])

	preview.modulate = get_preview_color(tile)
	show_attack_range(tile, building_type)


func _on_click() -> void:
	var bg = get_building_grid()
	if not bg:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = bg.world_to_tile(mouse_pos)

	if not can_place_at(tile):
		if not bg.is_occupied(tile):
			flash_blocked_path()
		return

	var data = Config.buildings.get(building_type, {})
	var cost = int(data.get("cost", 0))
	if not GameManager.spend_gold(cost):
		return

	var building = building_scene.instantiate()
	bg.place_building(tile, building)
	building.setup(building_type)

	DustEffect.spawn(wall_system.get_tree(), bg.tile_to_world(tile))


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
