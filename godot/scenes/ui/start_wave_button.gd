# ==========================================
# start_wave_button.gd — Кнопка запуска следующей волны
# ==========================================

extends TextureRect

@onready var title_label: Label = $VBox/TitleLabel
@onready var wave_label: Label = $VBox/WaveLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_update_wave_text()


var force_hidden: bool = false

func _process(_delta: float) -> void:
	_update_wave_text()
	if force_hidden:
		visible = false
	else:
		visible = PhaseManager.is_build_phase()


func _update_wave_text() -> void:
	if wave_label:
		wave_label.text = "%d / %d" % [WaveManager.current_wave, WaveManager.total_waves]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if PhaseManager.is_build_phase():
			var am = get_node_or_null("/root/AudioManager")
			if am:
				am.play("ui_click")
			PhaseManager.skip_build_phase()
			modulate = Color(0.8, 0.7, 1.0)
			var tween = create_tween()
			tween.tween_property(self, "modulate", Color.WHITE, 0.3)
