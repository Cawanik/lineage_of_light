# ==========================================
# upgrade_tool.gd — Инструмент апгрейда зданий по клику/линии
# ==========================================

class_name UpgradeTool
extends BaseTool

var _hovered_building_tile: Vector2i = Vector2i(-9999, -9999)

# Апгрейд по линии
var _dragging: bool = false
var _drag_start_tile: Vector2i = Vector2i(-9999, -9999)
var _drag_current_tile: Vector2i = Vector2i(-9999, -9999)
var _line_highlights: Array[Node2D] = []
var _cost_label: Label = null


func _on_activate() -> void:
	_create_cost_label()


func _on_deactivate() -> void:
	_reset_hover()
	_clear_line_highlights()
	_remove_cost_label()


func _on_update() -> void:
	if _dragging:
		var bg = get_building_grid()
		if bg:
			var mouse_pos = wall_system.get_global_mouse_position()
			_drag_current_tile = bg.world_to_tile(mouse_pos)
			_update_line_highlights()
	else:
		_update_hover()
	_update_cost_label()


func _on_click() -> void:
	var bg = get_building_grid()
	if not bg:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = bg.world_to_tile(mouse_pos)

	_dragging = true
	_drag_start_tile = tile
	_drag_current_tile = tile


func on_release() -> void:
	if not _dragging:
		return
	_dragging = false

	var bg = get_building_grid()
	if not bg:
		_clear_line_highlights()
		return

	var tiles = _get_line_tiles(_drag_start_tile, _drag_current_tile)
	var upgraded_count = 0

	for t in tiles:
		var building = bg.get_building(t)
		if not building or not building is Building:
			continue
		if _try_upgrade(building):
			upgraded_count += 1
			DustEffect.spawn(wall_system.get_tree(), bg.tile_to_world(t))

	_clear_line_highlights()
	_hovered_building_tile = Vector2i(-9999, -9999)


func _try_upgrade(building: Building) -> bool:
	var data = Config.buildings.get(building.building_type, {})
	var upgrades = data.get("upgrades", [])
	if building.upgrade_level >= upgrades.size():
		return false
	# Проверяем навык дерева
	var sm = wall_system.get_node_or_null("/root/SkillManager")
	if sm and building.upgrade_level >= sm.get_max_upgrade_level(building.building_type):
		return false

	var upgrade = upgrades[building.upgrade_level]
	var cost = int(upgrade.get("cost", 0))
	if not GameManager.spend_gold(cost):
		return false

	# HP бонус
	var hp_bonus = upgrade.get("hp_bonus", 0)
	if hp_bonus > 0:
		building.max_hp += hp_bonus
		building.hp += hp_bonus

	# Смена спрайта
	var new_sprite = upgrade.get("sprite", "")
	if new_sprite != "" and ResourceLoader.exists(new_sprite):
		building.sprite.texture = load(new_sprite)

	# Урон при контакте (шипы)
	var dmg_bonus = upgrade.get("damage_bonus", 0)
	if dmg_bonus > 0:
		building.contact_damage += dmg_bonus

	# Доп юниты
	var extra_units = int(upgrade.get("extra_units", 0))
	if extra_units > 0:
		for i in range(extra_units):
			building._setup_unit(data)

	building.upgrade_level += 1
	return true


func _get_upgrade_cost(building: Building) -> int:
	var data = Config.buildings.get(building.building_type, {})
	var upgrades = data.get("upgrades", [])
	if building.upgrade_level >= upgrades.size():
		return -1
	var sm = wall_system.get_node_or_null("/root/SkillManager")
	if sm and building.upgrade_level >= sm.get_max_upgrade_level(building.building_type):
		return -1
	return int(upgrades[building.upgrade_level].get("cost", 0))


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


func _update_line_highlights() -> void:
	_clear_line_highlights()
	var bg = get_building_grid()
	if not bg:
		return

	var tiles = _get_line_tiles(_drag_start_tile, _drag_current_tile)
	var ground = wall_system.get_tree().current_scene.get_node_or_null("Ground") as TileMapLayer
	var ysort = wall_system.get_tree().current_scene.get_node_or_null("YSort")
	if not ground or not ysort:
		return

	for t in tiles:
		var building = bg.get_building(t)
		var can_upgrade = building and building is Building and _get_upgrade_cost(building) >= 0

		var marker = Node2D.new()
		marker.position = ground.map_to_local(t) + ground.position
		marker.z_index = 80
		var color = Color(1.0, 0.85, 0.1, 0.35) if can_upgrade else Color(0.5, 0.5, 0.5, 0.1)
		var draw_node = marker
		draw_node.draw.connect(func():
			var hw = 32.0
			var hh = 16.0
			var diamond = PackedVector2Array([
				Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
			])
			draw_node.draw_colored_polygon(diamond, color)
		)
		ysort.add_child(marker)
		marker.queue_redraw()
		_line_highlights.append(marker)

		if can_upgrade:
			building.modulate = Color(1.2, 1.1, 0.6)


func _clear_line_highlights() -> void:
	var bg = get_building_grid()
	if bg:
		for tile in bg.buildings:
			var b = bg.get_building(tile)
			if b:
				b.modulate = Color.WHITE

	for h in _line_highlights:
		if is_instance_valid(h):
			h.queue_free()
	_line_highlights.clear()


func _update_hover() -> void:
	var bg = get_building_grid()
	if not bg:
		return
	var mouse_pos = wall_system.get_global_mouse_position()
	var tile = bg.find_nearest_building(mouse_pos, 30.0)

	if tile != Vector2i(-9999, -9999):
		var b = bg.get_building(tile)
		if not b or not b is Building or _get_upgrade_cost(b) < 0:
			tile = Vector2i(-9999, -9999)

	if tile != _hovered_building_tile:
		_reset_hover()
		_hovered_building_tile = tile
		if _hovered_building_tile != Vector2i(-9999, -9999):
			var b = bg.get_building(_hovered_building_tile)
			if b:
				b.modulate = Color(1.2, 1.1, 0.6)
				show_tile_highlight(tile, true)


func _reset_hover() -> void:
	var bg = get_building_grid()
	if _hovered_building_tile != Vector2i(-9999, -9999) and bg:
		var b = bg.get_building(_hovered_building_tile)
		if b:
			b.modulate = Color.WHITE
	_hovered_building_tile = Vector2i(-9999, -9999)
	_clear_tile_highlight()


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

	var bg = get_building_grid()
	if not bg:
		_cost_label.visible = false
		return

	var total_cost = 0

	if _dragging:
		var tiles = _get_line_tiles(_drag_start_tile, _drag_current_tile)
		for t in tiles:
			var building = bg.get_building(t)
			if building and building is Building:
				var c = _get_upgrade_cost(building)
				if c >= 0:
					total_cost += c
	else:
		if _hovered_building_tile != Vector2i(-9999, -9999):
			var building = bg.get_building(_hovered_building_tile)
			if building and building is Building:
				var c = _get_upgrade_cost(building)
				if c >= 0:
					total_cost = c

	if total_cost > 0:
		_cost_label.text = "-%d" % total_cost
		_cost_label.visible = true
		if total_cost > GameManager.gold:
			_cost_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			_cost_label.add_theme_color_override("font_color", Color("#f0d060"))
		var viewport = wall_system.get_viewport()
		_cost_label.position = viewport.get_mouse_position() + Vector2(20, -10)
	else:
		_cost_label.visible = false
