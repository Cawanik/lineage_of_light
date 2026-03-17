class_name TowerBase
extends Node2D

@onready var attack_timer: Timer = $AttackTimer
@onready var range_area: Area2D = $RangeArea
@onready var range_shape: CollisionShape2D = $RangeArea/CollisionShape2D
@onready var sprite: ColorRect = $Sprite
@onready var accent_sprite: ColorRect = $AccentSprite

var tower_type: String = "tower_arrow"
var tower_data: Dictionary = {}
var enemies_in_range: Array = []
var current_target: Node2D = null

var projectile_scene: PackedScene


func _ready() -> void:
	projectile_scene = load("res://scenes/projectiles/projectile.tscn")
	range_area.body_entered.connect(_on_enemy_entered_range)
	range_area.body_exited.connect(_on_enemy_exited_range)


func setup(type: String) -> void:
	tower_type = type
	tower_data = TowerData.TOWERS[type]

	# Set range
	var shape = CircleShape2D.new()
	shape.radius = tower_data["range"]
	range_shape.shape = shape

	# Set attack speed
	attack_timer.wait_time = 1.0 / tower_data["attack_speed"]
	attack_timer.start()

	# Visual placeholder
	sprite.color = tower_data["color"]
	accent_sprite.color = tower_data["accent"]


func _on_enemy_entered_range(body: Node2D) -> void:
	if body is EnemyBase:
		enemies_in_range.append(body)


func _on_enemy_exited_range(body: Node2D) -> void:
	enemies_in_range.erase(body)
	if current_target == body:
		current_target = null


func _find_target() -> Node2D:
	# Target the enemy closest to the end of the path (most progress)
	var best_target: Node2D = null
	var best_progress: float = -1.0

	for enemy in enemies_in_range:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.path_progress > best_progress:
			best_progress = enemy.path_progress
			best_target = enemy

	return best_target


func _on_attack_timer_timeout() -> void:
	if not GameManager.is_game_active:
		return

	# Clean up invalid refs
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e) and not e.is_dead)

	current_target = _find_target()
	if current_target == null:
		return

	match tower_data.get("type", "ATTACK"):
		"ATTACK":
			_fire_projectile(current_target)
		"MAGIC":
			_fire_projectile(current_target)
			# Apply slow
			if current_target.has_method("apply_slow"):
				current_target.apply_slow(
					tower_data.get("slow_factor", 0.5),
					tower_data.get("slow_duration", 2.0)
				)
		"ATTACK_AOE":
			_fire_aoe()


func _fire_projectile(target: Node2D) -> void:
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position + Vector2(0, -16)  # Fire from top of tower
	proj.setup(
		target,
		tower_data["damage"],
		tower_data["projectile_speed"],
		tower_data["accent"]
	)
	get_tree().current_scene.add_child(proj)


func _fire_aoe() -> void:
	var aoe_radius = tower_data.get("aoe_radius", 80.0)
	for enemy in enemies_in_range:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.take_damage(tower_data["damage"])

	# Visual feedback - flash accent color
	var tween = create_tween()
	accent_sprite.modulate = Color.WHITE * 2.0
	tween.tween_property(accent_sprite, "modulate", Color.WHITE, 0.3)
