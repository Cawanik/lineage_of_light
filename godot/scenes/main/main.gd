extends Node2D

@onready var placement_grid = $PlacementGrid
@onready var build_menu = $UILayer/BuildMenu
@onready var build_button: TextureButton = $UILayer/Toolbar/Grid/BuildButton
@onready var demolish_button: TextureButton = $UILayer/Toolbar/Grid/DemolishButton
@onready var wall_system: WallSystem = $YSort/WallSystem

var building_mode: bool = false
var demolish_mode: bool = false


func _ready() -> void:
	build_menu.building_selected.connect(_on_building_selected)
	build_menu.visibility_changed.connect(_on_menu_visibility_changed)
	build_button.pressed.connect(_on_build_button_pressed)
	demolish_button.pressed.connect(_on_demolish_button_pressed)

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


func _on_build_button_pressed() -> void:
	_exit_demolish()
	build_menu.toggle_menu()


func _on_demolish_button_pressed() -> void:
	build_menu.visible = false
	_exit_build()
	demolish_mode = not demolish_mode
	wall_system.demolish_mode = demolish_mode
	if not demolish_mode:
		wall_system.clear_demolish_mode()


func _exit_demolish() -> void:
	if demolish_mode:
		demolish_mode = false
		wall_system.clear_demolish_mode()


func _exit_build() -> void:
	if building_mode:
		building_mode = false
		wall_system.clear_build_mode()


func _on_building_selected(building_type: String) -> void:
	_exit_demolish()
	if building_type == "wall":
		building_mode = true
		wall_system.build_mode = true


func _on_menu_visibility_changed() -> void:
	if not build_menu.visible:
		_exit_build()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if demolish_mode:
			wall_system.demolish_hovered()
		elif building_mode:
			wall_system.place_at_preview()
