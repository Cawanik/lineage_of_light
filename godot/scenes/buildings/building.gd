class_name Building
extends Node2D

## Base class for all buildings with HP

var building_type: String = ""
var max_hp: float = 100.0
var hp: float = 100.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_bar_bg: ColorRect = $HPBarBG
@onready var hp_bar: ColorRect = $HPBar


func setup(type: String) -> void:
	building_type = type
	var data = Config.buildings.get(type, {})
	max_hp = data.get("hp", 100.0)
	hp = max_hp

	var sprite_path = data.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)

	var offset = data.get("sprite_offset", [0.0, 0.0])
	sprite.position = Vector2(offset[0], offset[1])


func take_damage(amount: float) -> void:
	hp -= amount
	_update_hp_bar()
	if hp <= 0:
		_on_destroyed()


func _update_hp_bar() -> void:
	var ratio = clampf(hp / max_hp, 0.0, 1.0)
	hp_bar.scale.x = ratio

	if ratio > 0.5:
		hp_bar.color = Color(0.17, 0.35, 0.15)
	elif ratio > 0.25:
		hp_bar.color = Color(0.77, 0.48, 0.27)
	else:
		hp_bar.color = Color(0.55, 0, 0)

	hp_bar_bg.visible = ratio < 1.0
	hp_bar.visible = ratio < 1.0


func _on_destroyed() -> void:
	# Override in subclasses
	queue_free()
