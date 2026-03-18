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
	
	# Connect throne destruction to game over
	throne.throne_destroyed.connect(GameManager.on_throne_destroyed)
	print("Throne destruction signal connected to GameManager")

	# Sync PathfindingSystem
	var ps = get_node_or_null("/root/PathfindingSystem")
	if ps:
		ps.throne_tile = throne_tile
		# Throne was marked solid by place_building — undo it so enemies can path to it
		ps.set_tile_solid(throne_tile, false)

	# Simple wall defense around throne (14,15)
	# Create a 7x7 wall box with throne in center and entrance from the right
	var throne_center = throne_tile
	
	# Top wall (full)
	wall_system.place_wall_line(throne_center + Vector2i(-3, -3), throne_center + Vector2i(3, -3))
	# Bottom wall (full)  
	wall_system.place_wall_line(throne_center + Vector2i(-3, 3), throne_center + Vector2i(3, 3))
	# Left wall (full)
	wall_system.place_wall_line(throne_center + Vector2i(-3, -3), throne_center + Vector2i(-3, 3))
	# Right wall (with entrance gap in the middle)
	wall_system.place_wall_line(throne_center + Vector2i(3, -3), throne_center + Vector2i(3, -1))
	wall_system.place_wall_line(throne_center + Vector2i(3, 1), throne_center + Vector2i(3, 3))
	
	print("Throne at: %s, Wall box: %s to %s" % [throne_center, throne_center + Vector2i(-3, -3), throne_center + Vector2i(3, 3)])

	# Connect wave signals
	WaveManager.wave_started.connect(_on_wave_started)
	WaveManager.wave_completed.connect(_on_wave_completed)
	WaveManager.all_waves_completed.connect(_on_all_waves_completed)


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

	# N key — start next wave (quick hotkey)
	if event is InputEventKey and event.pressed and event.keycode == KEY_N:
		WaveManager.start_next_wave()


func _on_wave_started(wave_number: int) -> void:
	print("Wave %d started!" % wave_number)


func _on_wave_completed(wave_number: int) -> void:
	print("Wave %d completed!" % wave_number)


func _on_all_waves_completed() -> void:
	print("All waves completed! Victory!")
