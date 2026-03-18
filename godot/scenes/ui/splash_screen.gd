# ==========================================
# splash_screen.gd — Заставка при запуске, ну хуле
# ==========================================
# _ready() — запускает тween: fade in → пауза → fade out → переход на главную сцену
# _go_to_main() — переключает на main.tscn, пиздуем играть
# _input(event) — скипает заставку нахуй по любому нажатию
# ==========================================

extends Control

@onready var logo: TextureRect = $Logo
@onready var tween_node: Node = self

var fade_in_time: float = 1.0
var hold_time: float = 2.0
var fade_out_time: float = 1.0


func _ready() -> void:
	logo.modulate = Color(1, 1, 1, 0)

	var tween = create_tween()
	# Fade in
	tween.tween_property(logo, "modulate:a", 1.0, fade_in_time).set_ease(Tween.EASE_IN_OUT)
	# Hold
	tween.tween_interval(hold_time)
	# Fade out
	tween.tween_property(logo, "modulate:a", 0.0, fade_out_time).set_ease(Tween.EASE_IN_OUT)
	# Switch to main scene
	tween.tween_callback(_go_to_main)


func _go_to_main() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed:
		_go_to_main()
