extends PanelContainer

signal building_selected(building_type: String)

@onready var item_list: VBoxContainer = $MarginContainer/VBoxContainer/ItemList

var is_open: bool = false
var selected_building: String = ""

const BUILDINGS = {
	"wall": {
		"name": "Стена",
		"cost": 10,
		"desc": "Каменная стена с башенками на стыках",
		"hotkey": "1",
	},
}


func _ready() -> void:
	visible = false
	_build_buttons()


func _build_buttons() -> void:
	for key in BUILDINGS:
		var data = BUILDINGS[key]
		var btn = Button.new()
		btn.text = "%s  [%d]  (%s)" % [data["name"], data["cost"], data["hotkey"]]
		btn.tooltip_text = data["desc"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(220, 40)

		btn.add_theme_color_override("font_color", Color("#e8e0ff"))
		btn.add_theme_color_override("font_hover_color", Color("#f0d060"))
		btn.add_theme_color_override("font_pressed_color", Color("#9933cc"))

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
