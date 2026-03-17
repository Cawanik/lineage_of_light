extends PanelContainer

signal building_selected(building_type: String)

@onready var item_list: VBoxContainer = $MarginContainer/VBoxContainer/ItemList

var is_open: bool = false
var selected_building: String = ""

var BUILDINGS: Dictionary = {}


func _ready() -> void:
	visible = false
	BUILDINGS = Config.buildings
	_build_buttons()


func _build_buttons() -> void:
	for key in BUILDINGS:
		var data = BUILDINGS[key]
		# Skip buildings without cost (like throne) — not player-buildable
		if not data.has("hotkey"):
			continue
		var btn = Button.new()
		btn.text = "%s  [%d]  (%s)" % [data.get("name", key), data.get("cost", 0), data.get("hotkey", "")]
		btn.tooltip_text = data.get("desc", "")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(220, 40)

		var ui = Config.game.get("ui", {})
		btn.add_theme_color_override("font_color", Color(ui.get("font_color", "#e8e0ff")))
		btn.add_theme_color_override("font_hover_color", Color(ui.get("font_hover_color", "#f0d060")))
		btn.add_theme_color_override("font_pressed_color", Color(ui.get("font_pressed_color", "#9933cc")))

		btn.pressed.connect(_on_item_pressed.bind(key))
		item_list.add_child(btn)


func _on_item_pressed(building_type: String) -> void:
	selected_building = building_type
	building_selected.emit(building_type)


func toggle_menu() -> void:
	is_open = not is_open
	visible = is_open


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			toggle_menu()
