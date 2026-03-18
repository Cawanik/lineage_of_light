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

var throne_scene: PackedScene = preload("res://scenes/buildings/throne.tscn")


func _ready() -> void:
	tools = {
		"build": BuildTool.new(),
		"demolish": DemolishTool.new(),
		"move": MoveTool.new(),
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

	# Lich King on adjacent tile
	var lich_tile = Vector2i(15, 15)
	lich_king.position = building_grid.tile_to_world(lich_tile)

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
