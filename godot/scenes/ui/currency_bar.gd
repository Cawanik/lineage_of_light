# ==========================================
# currency_bar.gd — Панель валют сверху экрана
# ==========================================

@tool
extends TextureRect

@export_group("Иконки")
@export var gold_texture: Texture2D
@export var soul_texture: Texture2D
@export var icon_size: Vector2 = Vector2(32, 32)

@export_group("Шрифт")
@export var font_size: int = 18
@export var gold_color: Color = Color(0.941, 0.816, 0.376, 1)
@export var soul_color: Color = Color(0.6, 0.4, 1, 1)

@export_group("Таймер")
@export var timer_seconds: float = 300.0
@export var timer_color: Color = Color(0.9, 0.85, 0.8, 1)
@export var timer_warning_color: Color = Color(1.0, 0.3, 0.3, 1)
@export var timer_warning_threshold: float = 30.0

@export_group("Расположение")
@export var spacing: int = 12
@export var currency_gap: int = 30
@export var content_offset_y: float = 0.55

@onready var gold_icon: TextureRect = $HBox/GoldGroup/GoldIcon
@onready var gold_label: Label = $HBox/GoldGroup/GoldLabel
@onready var gold_group: HBoxContainer = $HBox/GoldGroup
@onready var soul_icon: TextureRect = $HBox/SoulGroup/SoulIcon
@onready var soul_label: Label = $HBox/SoulGroup/SoulLabel
@onready var soul_group: HBoxContainer = $HBox/SoulGroup
@onready var hbox: HBoxContainer = $HBox
@onready var timer_label: Label = $HBox/TimerLabel

var _last_gold: int = -1
var _last_souls: int = -1
var _time_remaining: float = 300.0


func _ready() -> void:
	await get_tree().process_frame
	_apply_settings()
	_time_remaining = timer_seconds


func _apply_settings() -> void:
	if not is_inside_tree():
		return
	if gold_icon:
		gold_icon.custom_minimum_size = icon_size
		if gold_texture:
			gold_icon.texture = gold_texture
	if soul_icon:
		soul_icon.custom_minimum_size = icon_size
		if soul_texture:
			soul_icon.texture = soul_texture
	if gold_label:
		gold_label.add_theme_font_size_override("font_size", font_size)
		gold_label.add_theme_color_override("font_color", gold_color)
	if soul_label:
		soul_label.add_theme_font_size_override("font_size", font_size)
		soul_label.add_theme_color_override("font_color", soul_color)
	if hbox:
		hbox.add_theme_constant_override("separation", currency_gap)
		hbox.anchor_top = content_offset_y
		hbox.anchor_bottom = content_offset_y
	if gold_group:
		gold_group.add_theme_constant_override("separation", spacing)
	if soul_group:
		soul_group.add_theme_constant_override("separation", spacing)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var gold = GameManager.gold
	var souls = GameManager.souls

	if gold != _last_gold:
		_last_gold = gold
		gold_label.text = _format_number(gold)

	if souls != _last_souls:
		_last_souls = souls
		soul_label.text = _format_number(souls)

	# Таймер из PhaseManager
	if timer_label:
		if PhaseManager.is_build_phase():
			_time_remaining = PhaseManager.get_build_time_remaining()
			if _time_remaining > 9999:
				timer_label.text = "∞"
				timer_label.add_theme_color_override("font_color", timer_color)
			else:
				var mins = int(_time_remaining) / 60
				var secs = int(_time_remaining) % 60
				timer_label.text = "%02d:%02d" % [mins, secs]
			if _time_remaining <= timer_warning_threshold:
				timer_label.add_theme_color_override("font_color", timer_warning_color)
			else:
				timer_label.add_theme_color_override("font_color", timer_color)
		else:
			timer_label.text = "БОЙ"
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))


func _format_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	elif n >= 1000:
		return "%.1fK" % (n / 1000.0)
	return str(n)
