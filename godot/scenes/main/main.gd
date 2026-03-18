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

@onready var placement_grid = $PlacementGrid
@onready var build_menu = $UILayer/BuildMenu
@onready var build_button: TextureButton = $UILayer/Toolbar/Grid/BuildButton
@onready var demolish_button: TextureButton = $UILayer/Toolbar/Grid/DemolishButton
@onready var move_button: TextureButton = $UILayer/Toolbar/Grid/MoveButton
@onready var wall_system: WallSystem = $YSort/WallSystem
@onready var building_grid: BuildingGrid = $YSort/BuildingGrid
@onready var lich_king: AnimatedSprite2D = $YSort/LichKing

var active_tool: BaseTool = null
var tools: Dictionary = {}
var place_tool: PlaceBuildingTool = PlaceBuildingTool.new()

var throne_scene: PackedScene = preload("res://scenes/buildings/throne.tscn")


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

	# Place throne on tile
	var throne_tile = Vector2i(14, 15)
	var throne = throne_scene.instantiate()
	building_grid.place_building(throne_tile, throne)


	# Box 1
	var c = Vector2i(15, 15)
	wall_system.place_wall_line(c, c + Vector2i(4, 0))
	wall_system.place_wall_line(c + Vector2i(4, 0), c + Vector2i(4, 4))
	wall_system.place_wall_line(c + Vector2i(4, 4), c + Vector2i(0, 4))
	wall_system.place_wall_line(c + Vector2i(0, 4), c)

	# Box 2
	var c2 = c + Vector2i(4, 0)
	wall_system.place_wall_line(c2, c2 + Vector2i(3, 0))
	wall_system.place_wall_line(c2 + Vector2i(3, 0), c2 + Vector2i(3, 4))
	wall_system.place_wall_line(c2 + Vector2i(3, 4), c2 + Vector2i(0, 4))


func _set_tool(tool_name: String) -> void:
	var same = active_tool == tools.get(tool_name)
	if active_tool:
		active_tool.deactivate()
		active_tool = null
	build_menu.visible = false
	if not same and tools.has(tool_name):
		active_tool = tools[tool_name]
		active_tool.activate(wall_system)


func _on_build_button_pressed() -> void:
	if active_tool:
		active_tool.deactivate()
		active_tool = null
	build_menu.toggle_menu()


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


func _process(_delta: float) -> void:
	if active_tool:
		active_tool.update()


func _input(event: InputEvent) -> void:
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
		var throne = $YSort/BuildingGrid.get_node_or_null("Throne")
		if throne:
			throne.toggle_adjust()
		return
	if active_tool and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		active_tool.click()


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
