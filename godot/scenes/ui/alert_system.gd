# ==========================================
# alert_system.gd — Система всплывающих алёртов, autoload
# ==========================================

extends CanvasLayer

const MAX_ALERTS = 3
const ALERT_DURATION = 2.5
const FADE_DURATION = 0.4
const ALERT_SPACING = 60
const ALERT_OFFSET_Y = 80

var _alerts: Array[Control] = []
var _alert_bg_tex: Texture2D = null


func _ready() -> void:
	layer = 108
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists("res://assets/sprites/ui/alert_bg.png"):
		_alert_bg_tex = load("res://assets/sprites/ui/alert_bg.png")


func show_alert(text: String, color: Color = Color.WHITE) -> void:
	# Удаляем старые если больше MAX
	while _alerts.size() >= MAX_ALERTS:
		var old = _alerts.pop_front()
		if is_instance_valid(old):
			old.queue_free()

	# Сдвигаем существующие вверх
	for i in range(_alerts.size()):
		if is_instance_valid(_alerts[i]):
			var tween = create_tween()
			var target_y = ALERT_OFFSET_Y + (i) * ALERT_SPACING
			tween.tween_property(_alerts[i], "position:y", target_y, 0.2)

	var alert = _create_alert(text, color)
	var vp_size = get_viewport().get_visible_rect().size
	alert.position = Vector2(vp_size.x * 0.5 - alert.size.x * 0.5, ALERT_OFFSET_Y + _alerts.size() * ALERT_SPACING)
	alert.modulate = Color(1, 1, 1, 0)
	add_child(alert)
	_alerts.append(alert)

	# Fade in
	var tween = create_tween()
	tween.tween_property(alert, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_interval(ALERT_DURATION)
	tween.tween_property(alert, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func():
		_alerts.erase(alert)
		if is_instance_valid(alert):
			alert.queue_free()
	)


func _create_alert(text: String, color: Color) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(200, 50)
	container.size = Vector2(200, 50)

	# Фон — текстура
	if _alert_bg_tex:
		var bg = TextureRect.new()
		bg.texture = _alert_bg_tex
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.anchors_preset = Control.PRESET_FULL_RECT
		bg.anchor_right = 1.0
		bg.anchor_bottom = 1.0
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(bg)

	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 16
	label.offset_right = -16
	label.offset_top = 4
	label.offset_bottom = -4
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)

	return container


# Хелперы
func alert_error(text: String) -> void:
	show_alert(text, Color(1.0, 0.3, 0.3))


func alert_warning(text: String) -> void:
	show_alert(text, Color(1.0, 0.8, 0.2))


func alert_info(text: String) -> void:
	show_alert(text, Color(0.7, 0.8, 1.0))


func alert_success(text: String) -> void:
	show_alert(text, Color(0.3, 1.0, 0.4))


# Постоянный алёрт (не исчезает)
var _persistent_alert: Control = null

func show_persistent(text: String, color: Color = Color(1.0, 0.85, 0.2)) -> void:
	hide_persistent()
	_persistent_alert = _create_alert(text, color)
	var vp_size = get_viewport().get_visible_rect().size
	_persistent_alert.position = Vector2(vp_size.x * 0.5 - _persistent_alert.size.x * 0.5, ALERT_OFFSET_Y)
	_persistent_alert.modulate = Color(1, 1, 1, 0)
	add_child(_persistent_alert)
	var tween = create_tween()
	tween.tween_property(_persistent_alert, "modulate:a", 1.0, FADE_DURATION)


func hide_persistent() -> void:
	if _persistent_alert and is_instance_valid(_persistent_alert):
		var alert = _persistent_alert
		_persistent_alert = null
		var tween = create_tween()
		tween.tween_property(alert, "modulate:a", 0.0, FADE_DURATION)
		tween.tween_callback(alert.queue_free)
