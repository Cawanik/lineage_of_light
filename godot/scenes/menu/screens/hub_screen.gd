extends VBoxContainer

signal skill_tree_pressed
signal map_pressed
signal back_pressed

@onready var title_label: Label = $Title
@onready var souls_label: Label = $Souls


func update_info(map_name: String) -> void:
	title_label.text = map_name
	souls_label.text = "Души: %d" % GameManager.souls


func _on_skill_tree_pressed() -> void:
	skill_tree_pressed.emit()

func _on_map_pressed() -> void:
	map_pressed.emit()

func _on_back_pressed() -> void:
	back_pressed.emit()
