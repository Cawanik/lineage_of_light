# ==========================================
# game_over_screen.gd — Экран Game Over при разрушении трона
# ==========================================
# _ready() — подключает кнопки, запускает fade-in анимацию
# _on_restart_pressed() — перезапускает игру (main.tscn)
# _on_exit_pressed() — выходит из игры
# ==========================================

extends Control

@onready var background: ColorRect = $Background
@onready var vbox: VBoxContainer = $VBox

func _ready() -> void:
	# Start invisible
	background.modulate = Color(1, 1, 1, 0)
	vbox.modulate = Color(1, 1, 1, 0)
	
	# Connect buttons
	$VBox/ButtonContainer/RestartButton.pressed.connect(_on_restart_pressed)
	$VBox/ButtonContainer/ExitButton.pressed.connect(_on_exit_pressed)
	
	# Fade in animation
	var tween = create_tween().set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.8, 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(vbox, "modulate", Color(1, 1, 1, 1), 1.2).set_ease(Tween.EASE_OUT).set_delay(0.3)

func _on_restart_pressed() -> void:
	print("GameOverScreen: Restarting game...")
	# Reset GameManager state
	GameManager.reset_game()
	# Reload main scene
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_exit_pressed() -> void:
	print("GameOverScreen: Exiting game...")
	get_tree().quit()