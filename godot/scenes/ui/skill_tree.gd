# ==========================================
# skill_tree.gd — Экран дерева талантов
# ==========================================

extends CanvasLayer


func _ready() -> void:
	visible = false
	layer = 100
	$CloseButton.pressed.connect(close)


func open() -> void:
	visible = true
	GameManager.pause_game()


func close() -> void:
	visible = false
	GameManager.resume_game()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
