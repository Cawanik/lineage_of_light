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


func _ready() -> void:
	tools = {
		"build": BuildTool.new(),
		"demolish": DemolishTool.new(),
		"move": MoveTool.new(),
		"place": place_tool,
	}

	build_menu.building_selected.connect(_on_building_selected)
	build_menu.visibility_changed.connect(_on_menu_visibility_changed)
	build_button.pressed.connect(_on_build_button_pressed)
	demolish_button.pressed.connect(_on_demolish_button_pressed)
	move_button.pressed.connect(_on_move_button_pressed)

	# Ховер-эффекты на кнопки тулбара
	for btn in [build_button, demolish_button, move_button]:
		btn.mouse_entered.connect(func(): btn.modulate = Color(1.3, 1.1, 1.4, 1.0))
		btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Place throne on tile (берём позицию из Ground)
	var ground = get_node_or_null("Ground") as IsoGround
	if ground:
		throne_start_tile = ground.throne_tile
	var throne = throne_scene.instantiate()
	building_grid.place_building(throne_start_tile, throne)

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


func _get_tool_slot(tool_name: String) -> Node:
	match tool_name:
		"build", "place":
			return $UILayer/Toolbar/Grid/Slot1
		"demolish":
			return $UILayer/Toolbar/Grid/Slot2
		"move":
			return $UILayer/Toolbar/Grid/Slot3
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if active_tool:
			active_tool.click()
		else:
			_try_focus_building()

	# N key — start next wave (quick hotkey)
	if event is InputEventKey and event.pressed and event.keycode == KEY_N:
		WaveManager.start_next_wave()


func _try_focus_building() -> void:
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


func _on_wave_started(wave_number: int) -> void:
	print("Wave %d started!" % wave_number)


func _on_wave_completed(wave_number: int) -> void:
	print("Wave %d completed!" % wave_number)


func _on_all_waves_completed() -> void:
	print("All waves completed! Victory!")


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
