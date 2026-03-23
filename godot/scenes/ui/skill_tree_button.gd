# ==========================================
# skill_tree_button.gd — Кнопка дерева развития, ставит игру на паузу
# ==========================================

extends TextureRect


func _ready() -> void:
	mouse_entered.connect(func(): modulate = Color(1.3, 1.1, 1.4, 1.0))
	mouse_exited.connect(func(): modulate = Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var skill_tree = get_tree().current_scene.get_node_or_null("SkillTree")
		if skill_tree:
			skill_tree.open()
