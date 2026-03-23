# ==========================================
# main.gd — Главная сцена, тут всё начинается, ёб твою мать
# ==========================================
# _ready() — инициализирует инструменты (build/demolish/move/place), подключает сигналы, ставит трон и Лича
# _set_tool(tool_name) — переключает активный инструмент, деактивирует старый, активирует новый
# _on_build_button_pressed() — нажали кнопку строительства — открываем меню, нахуй
# _on_demolish_button_pressed() — включает инструмент сноса
# _on_move_button_pressed() — включает инструмент перемещения
# _on_building_selected(building_type) — выбрали здание в меню: wall -> build tool, остальное -> place tool
# _on_menu_visibility_changed() — если меню закрылось а build tool активен — деактивируем его
# _process(_delta) — каждый кадр дёргает update() активного инструмента
# _input(event) — F7 экспорт карты, F5 adjust стен, F6 adjust трона, ЛКМ -> клик инструмента
# ==========================================

extends Node2D

@export var throne_start_tile: Vector2i = Vector2i(14, 15)

@onready var placement_grid = $PlacementGrid
@onready var build_menu = $UILayer/BuildMenu
@onready var build_button: TextureButton = $UILayer/Toolbar/Grid/Slot1/BuildButton
@onready var demolish_button: TextureButton = $UILayer/Toolbar/Grid/Slot2/DemolishButton
@onready var move_button: TextureButton = $UILayer/Toolbar/Grid/Slot3/MoveButton
@onready var upgrade_button: TextureButton = $UILayer/Toolbar/Grid/Slot4/UpgradeButton
@onready var flat_view_button: TextureButton = $UILayer/Toolbar/Grid/Slot5/FlatViewButton
@onready var wall_system: WallSystem = $YSort/WallSystem
@onready var building_grid: BuildingGrid = $YSort/BuildingGrid

var active_tool: BaseTool = null
var active_tool_name: String = ""
var tools: Dictionary = {}
var place_tool: PlaceBuildingTool = PlaceBuildingTool.new()
const SLOT_ACTIVE_COLOR = Color(0.7, 0.4, 1.0, 1.0)
const SLOT_DEFAULT_COLOR = Color(1.0, 1.0, 1.0, 1.0)

var throne_scene: PackedScene = preload("res://scenes/buildings/throne.tscn")
var _camera_focused: bool = false
var _focus_building: Node2D = null
var _focus_range_highlights: Array[Node2D] = []
var _flat_view: bool = false
var _flat_labels: Array[Node2D] = []


func _ready() -> void:
	tools = {
		"build": BuildTool.new(),
		"demolish": DemolishTool.new(),
		"move": MoveTool.new(),
		"place": place_tool,
		"upgrade": UpgradeTool.new(),
	}

	build_menu.building_selected.connect(_on_building_selected)
	build_menu.visibility_changed.connect(_on_menu_visibility_changed)
	build_button.pressed.connect(_on_build_button_pressed)
	demolish_button.pressed.connect(_on_demolish_button_pressed)
	move_button.pressed.connect(_on_move_button_pressed)
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	flat_view_button.pressed.connect(_on_flat_view_button_pressed)

	# Тултипы и ховер-эффекты
	build_button.tooltip_text = "Строительство\nРазмещай здания на поле\nЗажми ЛКМ для линии"
	demolish_button.tooltip_text = "Снос\nУдаляй постройки\nЗажми ЛКМ для линии"
	move_button.tooltip_text = "Перемещение\nПеретащи здание на новое место"
	upgrade_button.tooltip_text = "Улучшение\nУлучшай здания за золото\nЗажми ЛКМ для линии"
	flat_view_button.tooltip_text = "Плоский вид\nПоказывает подписи построек\nМожно совмещать с другими инструментами"

	for btn in [build_button, demolish_button, move_button, upgrade_button, flat_view_button]:
		btn.mouse_entered.connect(func(): btn.modulate = Color(1.3, 1.1, 1.4, 1.0))
		btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Place throne on tile (берём позицию из Ground)
	var ground = get_node_or_null("Ground") as IsoGround
	if ground:
		throne_start_tile = ground.throne_tile
	var throne = throne_scene.instantiate()
	building_grid.place_building(throne_start_tile, throne)

	# Спавним игрока рядом с троном
	var player_node = get_node_or_null("YSort/Player")
	if player_node:
		var free_tile = _find_free_tile_near(throne_start_tile)
		player_node.position = building_grid.tile_to_world(free_tile)

	# Connect throne destruction to game over
	throne.throne_destroyed.connect(GameManager.on_throne_destroyed)

	# Sync PathfindingSystem
	var ps = get_node_or_null("/root/PathfindingSystem")
	if ps:
		ps.throne_tile = throne_start_tile
		ps.set_tile_solid(throne_start_tile, false)

	# Connect wave signals
	if WaveManager:
		WaveManager.wave_started.connect(_on_wave_started)
		WaveManager.wave_completed.connect(_on_wave_completed)
		WaveManager.all_waves_completed.connect(_on_all_waves_completed)

	# Connect phase signals
	PhaseManager.phase_changed.connect(_on_phase_changed)


func _get_tool_slot(tool_name: String) -> Node:
	match tool_name:
		"build", "place":
			return $UILayer/Toolbar/Grid/Slot1
		"demolish":
			return $UILayer/Toolbar/Grid/Slot2
		"move":
			return $UILayer/Toolbar/Grid/Slot3
		"upgrade":
			return $UILayer/Toolbar/Grid/Slot4
	return null


func _update_slot_highlights() -> void:
	for i in range(1, 10):
		var slot = get_node_or_null("UILayer/Toolbar/Grid/Slot%d" % i)
		if slot:
			slot.modulate = SLOT_DEFAULT_COLOR
	if active_tool_name != "":
		var active_slot = _get_tool_slot(active_tool_name)
		if active_slot:
			active_slot.modulate = SLOT_ACTIVE_COLOR


func _set_tool(tool_name: String) -> void:
	var same = active_tool == tools.get(tool_name)
	if active_tool:
		active_tool.deactivate()
		active_tool = null
		active_tool_name = ""
	build_menu.visible = false
	if not same and tools.has(tool_name):
		active_tool = tools[tool_name]
		active_tool_name = tool_name
		active_tool.activate(wall_system)
	_update_slot_highlights()


func _on_build_button_pressed() -> void:
	if active_tool:
		active_tool.deactivate()
		active_tool = null
		active_tool_name = ""
	build_menu.toggle_menu()
	_update_slot_highlights()


func _on_demolish_button_pressed() -> void:
	_set_tool("demolish")


func _on_move_button_pressed() -> void:
	_set_tool("move")


func _on_upgrade_button_pressed() -> void:
	_set_tool("upgrade")


var _flat_view_tex_closed = preload("res://assets/sprites/ui/icon_flat_view_0001.png")
var _flat_view_tex_open = preload("res://assets/sprites/ui/icon_flat_view_0002.png")

func _on_flat_view_button_pressed() -> void:
	if _flat_view:
		_disable_flat_view()
		flat_view_button.texture_normal = _flat_view_tex_closed
		flat_view_button.modulate = Color.WHITE
	else:
		_enable_flat_view()
		flat_view_button.texture_normal = _flat_view_tex_open
		flat_view_button.modulate = SLOT_ACTIVE_COLOR


func _on_building_selected(building_type: String) -> void:
	if building_type == "wall":
		_set_tool("build")
	else:
		place_tool.set_building_type(building_type)
		_set_tool("place")


func _on_menu_visibility_changed() -> void:
	if not build_menu.visible and active_tool == tools.get("build"):
		active_tool.deactivate()
		active_tool = null
		active_tool_name = ""
		_update_slot_highlights()


func _process(_delta: float) -> void:
	if active_tool:
		active_tool.update()

	# Автовозврат камеры при движении игрока
	if _camera_focused:
		var player_node = get_node_or_null("YSort/Player") as Player
		if player_node and player_node.velocity.length() > 1.0:
			_unfocus_camera()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_unfocus_camera()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		_print_matrix()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F7:
		MapExporter.export_map(building_grid, wall_system)
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		wall_system.toggle_adjust()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F6:
		# Adjust ближайшего здания к мыши
		var mouse_pos = get_global_mouse_position()
		var tile = building_grid.find_nearest_building(mouse_pos, 60.0)
		if tile != Vector2i(-9999, -9999):
			var b = building_grid.get_building(tile)
			if b and b.has_method("toggle_adjust"):
				b.toggle_adjust()
		return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if active_tool:
				active_tool.click()
			else:
				_try_focus_building()
		else:
			# Отпускание ЛКМ — завершаем драг
			if active_tool and active_tool.has_method("on_release"):
				active_tool.on_release()

	# N key — start next wave (quick hotkey)
	if event is InputEventKey and event.pressed and event.keycode == KEY_N:
		WaveManager.start_next_wave()


func _try_focus_building() -> void:
	if PhaseManager.is_combat_phase():
		return
	var mouse_pos = get_global_mouse_position()
	var tile = building_grid.find_nearest_building(mouse_pos, 30.0)
	if tile == Vector2i(-9999, -9999):
		if _camera_focused:
			_unfocus_camera()
		return
	var building = building_grid.get_building(tile)
	if not building:
		return

	var player_node = get_node_or_null("YSort/Player") as Player
	if not player_node or not player_node.camera:
		return

	# Сбрасываем предыдущий фокус если был
	if _camera_focused:
		for t in building_grid.buildings:
			var b2 = building_grid.get_building(t)
			if b2:
				b2.modulate = Color.WHITE
		BuildingInfoPanel.hide_panel(get_tree())

	_focus_building = building
	_camera_focused = true

	var target_pos = building_grid.tile_to_world(tile)
	var camera_offset = target_pos - player_node.global_position
	# Ограничиваем offset чтобы не вылезти за лимиты камеры
	var cam = player_node.camera
	var viewport_size = get_viewport().get_visible_rect().size
	var half_w = viewport_size.x / (2.0 * cam.zoom.x)
	var half_h = viewport_size.y / (2.0 * cam.zoom.y)
	var max_offset_x = maxf(0, (cam.limit_right - cam.limit_left) / 2.0 - half_w)
	var max_offset_y = maxf(0, (cam.limit_bottom - cam.limit_top) / 2.0 - half_h)
	camera_offset.x = clampf(camera_offset.x, -max_offset_x, max_offset_x)
	camera_offset.y = clampf(camera_offset.y, -max_offset_y, max_offset_y)

	var tween = create_tween()
	tween.tween_property(cam, "offset", camera_offset, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Отключаем occlusion fade и затемняем все здания кроме выбранного
	OcclusionFade.focus_mode = true
	for t in building_grid.buildings:
		var b = building_grid.get_building(t)
		if b and b != building:
			b.modulate = Color(1, 1, 1, 0.3)
	building.modulate = Color(1, 1, 1, 1)

	# Показываем инфо-панель и радиус атаки
	BuildingInfoPanel.show_for(building, target_pos, get_tree())
	_show_focus_range(tile, building.building_type)


func _show_focus_range(tile: Vector2i, btype: String) -> void:
	_clear_focus_range()
	var data = Config.buildings.get(btype, {})
	var range_cardinal = int(data.get("attack_range_cardinal", 0))
	var range_diagonal = int(data.get("attack_range_diagonal", 0))
	if range_cardinal == 0 and range_diagonal == 0:
		return

	var ground = get_node_or_null("Ground") as TileMapLayer
	var ysort = get_node_or_null("YSort")
	if not ground or not ysort:
		return

	var r = float(range_cardinal) + 0.5
	for dx in range(-range_cardinal, range_cardinal + 1):
		for dy in range(-range_cardinal, range_cardinal + 1):
			if dx == 0 and dy == 0:
				continue
			if sqrt(float(dx * dx + dy * dy)) > r:
				continue
			var t = tile + Vector2i(dx, dy)
			if not building_grid.is_on_ground(t):
				continue

			var marker = Node2D.new()
			marker.position = ground.map_to_local(t) + ground.position
			marker.z_index = 85
			marker.modulate = Color(1, 1, 1, 0.4)
			var draw_node = marker
			draw_node.draw.connect(func():
				var hw = 32.0
				var hh = 16.0
				var diamond = PackedVector2Array([
					Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
				])
				draw_node.draw_colored_polygon(diamond, Color(0.3, 0.6, 1.0, 0.3))
				for i in range(4):
					draw_node.draw_line(diamond[i], diamond[(i + 1) % 4], Color(0.4, 0.7, 1.0, 0.6), 1.5)
			)
			ysort.add_child(marker)
			marker.queue_redraw()
			_focus_range_highlights.append(marker)


func _clear_focus_range() -> void:
	for h in _focus_range_highlights:
		if is_instance_valid(h):
			h.queue_free()
	_focus_range_highlights.clear()


func _unfocus_camera() -> void:
	if not _camera_focused:
		return
	var player_node = get_node_or_null("YSort/Player") as Player
	if not player_node or not player_node.camera:
		return

	_camera_focused = false
	_focus_building = null
	BuildingInfoPanel.hide_panel(get_tree())
	_clear_focus_range()

	# Восстанавливаем прозрачность и occlusion
	OcclusionFade.focus_mode = false
	for tile in building_grid.buildings:
		var b = building_grid.get_building(tile)
		if b:
			b.modulate = Color.WHITE

	var tween = create_tween()
	tween.tween_property(player_node.camera, "offset", Vector2.ZERO, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_phase_changed(phase) -> void:
	if phase == PhaseManager.Phase.COMBAT:
		# Сбрасываем фокус
		if _camera_focused:
			_unfocus_camera()
		# Сбрасываем активный инструмент
		if active_tool:
			active_tool.deactivate()
			active_tool = null
			active_tool_name = ""
		# Выключаем flat view
		if _flat_view:
			_disable_flat_view()
		# Закрываем меню строительства
		build_menu.visible = false
		build_menu.is_open = false
		_update_slot_highlights()
		# Скрываем кнопки строительства
		_set_toolbar_mode("combat")
	elif phase == PhaseManager.Phase.BUILD:
		_set_toolbar_mode("build")


func _set_toolbar_mode(mode: String) -> void:
	var toolbar_grid = get_node_or_null("UILayer/Toolbar/Grid")
	if not toolbar_grid:
		return
	if mode == "combat":
		for slot in toolbar_grid.get_children():
			# Скрываем содержимое слота, оставляем подложку
			for child in slot.get_children():
				child.visible = false
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif mode == "build":
		for slot in toolbar_grid.get_children():
			for child in slot.get_children():
				child.visible = true
			slot.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_wave_started(wave_number: int) -> void:
	print("Wave %d started!" % wave_number)


func _on_wave_completed(wave_number: int) -> void:
	print("Wave %d completed!" % wave_number)


func _on_all_waves_completed() -> void:
	print("All waves completed! Victory!")


func _find_free_tile_near(center: Vector2i) -> Vector2i:
	# BFS от центра — находим ближайший свободный тайл
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [center]
	visited[center] = true
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var current = queue.pop_front()
		if not building_grid.is_occupied(current) and current != center:
			return current
		for d in dirs:
			var n = current + d
			if not visited.has(n) and building_grid.is_on_ground(n):
				visited[n] = true
				queue.append(n)

	return center


func _enable_flat_view() -> void:
	if _flat_view:
		return
	_flat_view = true

	# Скрываем все здания и стены
	for tile in building_grid.buildings:
		var b = building_grid.get_building(tile)
		if b:
			b.visible = false
	if wall_system:
		wall_system.visible = false

	# Лич Кинг
	var lk = get_node_or_null("YSort/LichKing")
	if lk:
		lk.visible = false

	_draw_flat_labels()


func _draw_flat_labels() -> void:
	_clear_flat_labels()
	var ground = get_node_or_null("Ground") as TileMapLayer
	var ysort = get_node_or_null("YSort")
	if not ground or not ysort:
		return

	for tile in building_grid.buildings:
		var b = building_grid.get_building(tile)
		if not b:
			continue
		var world_pos = ground.map_to_local(tile) + ground.position
		var label_node = Node2D.new()
		label_node.position = world_pos
		label_node.z_index = 200

		var data = Config.buildings.get(b.building_type, {})
		var short = data.get("short_name", b.building_type.left(3).to_upper())
		var tier = b.upgrade_level
		var tile_color = Color(0.6, 0.2, 0.8, 0.5)  # фиолетовый для зданий
		if b.building_type == "throne":
			tile_color = Color(0.8, 0.1, 0.1, 0.5)  # красный для трона
		elif b.building_type == "wall_block":
			tile_color = Color(0.3, 0.3, 0.5, 0.5)  # серый для стен

		var draw_n = label_node
		var display_text = short
		if tier > 0:
			display_text += "%d" % tier
		draw_n.draw.connect(func():
			var hw = 32.0
			var hh = 16.0
			# Окраска тайла
			var diamond = PackedVector2Array([
				Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
			])
			draw_n.draw_colored_polygon(diamond, tile_color)
			# Текст на тайле (центрирован)
			draw_n.draw_string(ThemeDB.fallback_font, Vector2(-12, 5), display_text, HORIZONTAL_ALIGNMENT_CENTER, 24, 10, Color.WHITE)
		)
		ysort.add_child(label_node)
		label_node.queue_redraw()
		_flat_labels.append(label_node)


func refresh_flat_view() -> void:
	if _flat_view:
		# Скрываем все здания (включая новые)
		for tile in building_grid.buildings:
			var b = building_grid.get_building(tile)
			if b:
				b.visible = false
		_clear_flat_labels()
		_draw_flat_labels()


func _clear_flat_labels() -> void:
	for l in _flat_labels:
		if is_instance_valid(l):
			l.queue_free()
	_flat_labels.clear()


func _disable_flat_view() -> void:
	if not _flat_view:
		return
	_flat_view = false

	# Показываем здания обратно
	for tile in building_grid.buildings:
		var b = building_grid.get_building(tile)
		if b:
			b.visible = true
	if wall_system:
		wall_system.visible = true

	var lk = get_node_or_null("YSort/LichKing")
	if lk:
		lk.visible = true

	_clear_flat_labels()
	flat_view_button.texture_normal = _flat_view_tex_closed
	flat_view_button.modulate = Color.WHITE


func _print_matrix() -> void:
	var iso = Config.game.get("iso", {})
	var w: int = iso.get("grid_width", 32)
	var h: int = iso.get("grid_height", 32)
	# Найти тайл трона
	var throne_pos = Vector2i(-9999, -9999)
	for tile in building_grid.buildings:
		var b = building_grid.buildings[tile]
		if b.building_type == "throne":
			throne_pos = tile
			break

	print("=== MAP MATRIX %dx%d === (throne at %s)" % [w, h, throne_pos])
	for y in range(h):
		var row = ""
		for x in range(w):
			var tile = Vector2i(x, y)
			if building_grid.buildings.has(tile):
				var b = building_grid.buildings[tile]
				if b.building_type == "throne":
					row += "T "
				else:
					row += "B "
			elif wall_system.nodes.has(tile):
				row += "W "
			elif building_grid.is_border(tile):
				row += "S "
			elif throne_pos != Vector2i(-9999, -9999) and absi(tile.x - throne_pos.x) <= 1 and absi(tile.y - throne_pos.y) <= 1:
				row += "L "
			else:
				row += ". "
		print(row)
