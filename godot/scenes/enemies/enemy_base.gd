class_name EnemyBase
extends PathFollow2D

@onready var body: CharacterBody2D = $Body
@onready var sprite: ColorRect = $Body/Sprite
@onready var accent_sprite: ColorRect = $Body/AccentSprite
@onready var hp_bar_bg: ColorRect = $Body/HPBarBG
@onready var hp_bar: ColorRect = $Body/HPBar

var enemy_type: String = "hero_barbarian"
var enemy_data: Dictionary = {}

var max_hp: float = 100.0
var hp: float = 100.0
var base_speed: float = 60.0
var current_speed: float = 60.0
var reward: int = 10
var damage_to_base: int = 1

var is_dead: bool = false
var path_progress: float = 0.0

# Slow effect
var slow_timer: float = 0.0
var slow_factor: float = 1.0


func setup(type: String) -> void:
	enemy_type = type
	enemy_data = EnemyData.ENEMIES[type]

	max_hp = enemy_data["hp"]
	hp = max_hp
	base_speed = enemy_data["speed"]
	current_speed = base_speed
	reward = enemy_data["reward"]
	damage_to_base = enemy_data["damage_to_base"]


func _ready() -> void:
	# Apply visuals
	if enemy_data.is_empty():
		enemy_data = EnemyData.ENEMIES[enemy_type]

	sprite.color = enemy_data["color"]
	accent_sprite.color = enemy_data["accent"]

	# Set collision layer for tower detection
	body.collision_layer = 2
	body.collision_mask = 0


func _process(delta: float) -> void:
	if is_dead:
		return

	# Handle slow effect
	if slow_timer > 0:
		slow_timer -= delta
		current_speed = base_speed * slow_factor
		sprite.modulate = Color(0.6, 0.6, 1.0)  # Blue tint when slowed
	else:
		current_speed = base_speed
		sprite.modulate = Color.WHITE

	# Move along path
	progress += current_speed * delta
	path_progress = progress_ratio

	# Sync CharacterBody2D position for area detection
	body.global_position = global_position

	# Reached end of path
	if progress_ratio >= 1.0:
		_reached_end()


func take_damage(amount: float) -> void:
	if is_dead:
		return

	hp -= amount
	_update_hp_bar()

	# Flash white on hit
	var tween = create_tween()
	sprite.modulate = Color(2, 2, 2)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	if hp <= 0:
		die()


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	slow_timer = duration


func die() -> void:
	if is_dead:
		return
	is_dead = true
	GameManager.earn_gold(reward)
	WaveManager.on_enemy_died()

	# Death animation
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(queue_free)


func _reached_end() -> void:
	if is_dead:
		return
	is_dead = true
	GameManager.lose_life(damage_to_base)
	WaveManager.on_enemy_reached_end()
	queue_free()


func _update_hp_bar() -> void:
	var ratio = clampf(hp / max_hp, 0.0, 1.0)
	hp_bar.scale.x = ratio

	# Color from green to red
	if ratio > 0.5:
		hp_bar.color = Color(0.17, 0.35, 0.15)  # Moss green
	elif ratio > 0.25:
		hp_bar.color = Color(0.77, 0.48, 0.27)  # Terracotta
	else:
		hp_bar.color = Color(0.55, 0, 0)  # Blood crimson
