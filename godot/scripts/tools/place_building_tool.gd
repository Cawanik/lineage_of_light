# ==========================================
# place_building_tool.gd — Инструмент размещения зданий
# ==========================================
# Поддерживает одиночную постройку и постройку по линии (зажать ЛКМ)
# ==========================================

class_name PlaceBuildingTool
extends BaseTool

var building_type: String = ""
var preview: Sprite2D = null
var building_scene: PackedScene = preload("res://scenes/buildings/building.tscn")

# Постройка по линии
var _dragging: bool = false
var _drag_start_tile: Vector2i = Vector2i(-9999, -9999)
var _drag_current_tile: Vector2i = Vector2i(-9999, -9999)
var _line_previews: Array[Node2D] = []
var _cost_label: Label = null
var _gold_icon: Sprite2D = null


func set_building_type(type: String) -> void:
	building_type = type


func _on_activate() -> void:
	_create_preview()
	_create_cost_label()


func _on_deactivate() -> void:
	_remove_preview()
	_clear_line_previews()
	_remove_cost_label()


func _on_update() -> void:
	var bg = get_building_grid()
	if not preview or not bg:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = bg.world_to_tile(mouse_pos)

	if _dragging:
		_drag_current_tile = tile
		_update_line_previews()
		# Скрываем основное превью при драге
		preview.visible = false
	else:
		preview.visible = true
		preview.position = bg.tile_to_world(tile)

		var data = Config.buildings.get(building_type, {})
		var offset = data.get("sprite_offset", [0.0, 0.0])
		preview.offset = Vector2(offset[0], offset[1])
		var sc = data.get("sprite_scale", [1.0, 1.0])
		preview.scale = Vector2(sc[0], sc[1])

		var placeable = can_place_at(tile)
		preview.modulate = Color(0.4, 1.0, 0.4, 0.5) if placeable else Color(1.0, 0.3, 0.3, 0.5)
		show_tile_highlight(tile, placeable)
		show_attack_range(tile, building_type)

	_update_cost_label()


func _on_click() -> void:
	var bg = get_building_grid()
	if not bg:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = bg.world_to_tile(mouse_pos)

	# Начинаем драг
	_dragging = true
	_drag_start_tile = tile
	_drag_current_tile = tile


func on_release() -> void:
	if not _dragging:
		return
	_dragging = false

	var bg = get_building_grid()
	if not bg:
		_clear_line_previews()
		return

	var tiles = _get_line_tiles(_drag_start_tile, _drag_current_tile)
	var data = Config.buildings.get(building_type, {})
	var cost_per = int(data.get("cost", 0))

	# Фильтруем только свободные тайлы
	var valid_tiles: Array[Vector2i] = []
	for t in tiles:
		if not bg.is_occupied(t) and bg.is_on_ground(t):
			valid_tiles.append(t)

	var total_cost = valid_tiles.size() * cost_per
	if valid_tiles.is_empty():
		_clear_line_previews()
		return
	if total_cost > GameManager.gold:
		var as_node = wall_system.get_node_or_null("/root/AlertSystem")
		if as_node:
			as_node.alert_error("Недостаточно золота!")
		_clear_line_previews()
		return

	# Проверяем что ВСЯ линия не заблокирует путь от трона до пшеницы
	var extra_blocked: Dictionary = {}
	for t in valid_tiles:
		extra_blocked[t] = true

	var throne_tile = PathChecker._find_throne(bg)
	if throne_tile != Vector2i(-9999, -9999):
		var border_tiles = PathChecker._get_border_tiles()
		if not border_tiles.is_empty():
			if not PathChecker._bfs(throne_tile, border_tiles, bg, extra_blocked):
				flash_blocked_path()
				var as_node = wall_system.get_node_or_null("/root/AlertSystem")
				if as_node:
					as_node.alert_error("Нельзя заблокировать путь к трону!")
				_clear_line_previews()
				return

	# Строим всё
	for t in valid_tiles:
		if not GameManager.spend_gold(cost_per):
			var as_node = wall_system.get_node_or_null("/root/AlertSystem")
			if as_node:
				as_node.alert_error("Недостаточно золота!")
			break
		var building = building_scene.instantiate()
		bg.place_building(t, building)
		building.setup(building_type)
		DustEffect.spawn(wall_system.get_tree(), bg.tile_to_world(t))

	# Обновляем flat view если включён
	var main = wall_system.get_tree().current_scene
	if main.has_method("refresh_flat_view"):
		main.refresh_flat_view()

	_clear_line_previews()


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


func _update_line_previews() -> void:
	_clear_line_previews()
	var bg = get_building_grid()
	if not bg:
		return

	var tiles = _get_line_tiles(_drag_start_tile, _drag_current_tile)
	var data = Config.buildings.get(building_type, {})
	var sprite_path = data.get("sprite", "")
	var offset = data.get("sprite_offset", [0.0, 0.0])
	var sc = data.get("sprite_scale", [1.0, 1.0])

	var ground = wall_system.get_tree().current_scene.get_node_or_null("Ground") as TileMapLayer

	# Проверяем всю линию на блокировку пути
	var line_blocks_path = false
	var valid_in_line: Dictionary = {}
	for t in tiles:
		if not bg.is_occupied(t) and bg.is_on_ground(t):
			valid_in_line[t] = true

	if not valid_in_line.is_empty():
		var throne_tile = PathChecker._find_throne(bg)
		if throne_tile != Vector2i(-9999, -9999):
			var border_tiles = PathChecker._get_border_tiles()
			if not border_tiles.is_empty():
				if not PathChecker._bfs(throne_tile, border_tiles, bg, valid_in_line):
					line_blocks_path = true

	for t in tiles:
		var tile_free = valid_in_line.has(t)
		var placeable = tile_free and not line_blocks_path

		# Превью спрайт
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			var s = Sprite2D.new()
			s.texture = load(sprite_path)
			s.position = bg.tile_to_world(t)
			s.offset = Vector2(offset[0], offset[1])
			s.scale = Vector2(sc[0], sc[1])
			s.modulate = Color(0.4, 1.0, 0.4, 0.4) if placeable else Color(1.0, 0.3, 0.3, 0.4)
			s.z_index = 100
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			wall_system.get_tree().current_scene.add_child(s)
			_line_previews.append(s)

		# Подсветка тайла
		if ground:
			var marker = Node2D.new()
			marker.position = ground.map_to_local(t) + ground.position
			marker.z_index = 80
			var color = Color(0.3, 1.0, 0.3, 0.25) if placeable else Color(1.0, 0.2, 0.2, 0.25)
			var draw_node = marker
			draw_node.draw.connect(func():
				var hw = 32.0
				var hh = 16.0
				var diamond = PackedVector2Array([
					Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
				])
				draw_node.draw_colored_polygon(diamond, color)
			)
			wall_system.get_tree().current_scene.get_node("YSort").add_child(marker)
			marker.queue_redraw()
			_line_previews.append(marker)


func _clear_line_previews() -> void:
	for p in _line_previews:
		if is_instance_valid(p):
			p.queue_free()
	_line_previews.clear()


func _create_cost_label() -> void:
	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 14)
	_cost_label.add_theme_color_override("font_color", Color("#f0d060"))
	_cost_label.z_index = 200
	_cost_label.visible = false

	var ui_layer = wall_system.get_tree().current_scene.get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(_cost_label)


func _remove_cost_label() -> void:
	if is_instance_valid(_cost_label):
		_cost_label.queue_free()
		_cost_label = null


func _update_cost_label() -> void:
	if not is_instance_valid(_cost_label):
		return

	var data = Config.buildings.get(building_type, {})
	var cost_per = int(data.get("cost", 0))
	var count = 1

	if _dragging:
		var tiles = _get_line_tiles(_drag_start_tile, _drag_current_tile)
		count = 0
		for t in tiles:
			if can_place_at(t):
				count += 1

	var total = count * cost_per
	_cost_label.text = "-%d" % total
	_cost_label.visible = true

	if total > GameManager.gold:
		_cost_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		_cost_label.add_theme_color_override("font_color", Color("#f0d060"))

	# Позиция рядом с курсором (экранные координаты)
	var viewport = wall_system.get_viewport()
	var mouse_screen = viewport.get_mouse_position()
	_cost_label.position = mouse_screen + Vector2(20, -10)


func _create_preview() -> void:
	var data = Config.buildings.get(building_type, {})
	var sprite_path = data.get("sprite", "")
	if sprite_path == "" or not ResourceLoader.exists(sprite_path):
		return
	preview = Sprite2D.new()
	preview.texture = load(sprite_path)
	preview.modulate = Color(0.4, 1.0, 0.4, 0.5)
	preview.z_index = 100
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wall_system.get_tree().current_scene.add_child(preview)


func _remove_preview() -> void:
	if is_instance_valid(preview):
		preview.queue_free()
		preview = null
