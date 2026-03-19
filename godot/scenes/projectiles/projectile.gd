# ==========================================
# projectile.gd — Базовый снаряд, настраиваемый через конфиг
# ==========================================
# setup(type, from, to) — инициализирует снаряд: тип, откуда, куда летит
# _process(delta) — двигает снаряд к цели, проверяет попадание
# _on_hit() — при попадании наносит урон и удаляется
# _on_miss() — если цель мертва или пропал — удаляется
# spawn(tree, type, from, to) — статический метод для спавна
# ==========================================

class_name Projectile
extends Node2D

# Конфиг снаряда
var projectile_type: String = ""
var speed: float = 200.0
var damage: float = 10.0
var target_pos: Vector2 = Vector2.ZERO
var target_node: Node2D = null
var homing: bool = false
var hit_radius: float = 8.0
var lifetime: float = 5.0
var _age: float = 0.0

# Визуал
var trail_enabled: bool = false
var trail_color: Color = Color(0.6, 0.3, 1.0, 0.8)
var _trail_points: PackedVector2Array = PackedVector2Array()
var _trail_max: int = 10

@onready var sprite: Sprite2D = $Sprite2D


func setup(type: String, from: Vector2, to_pos: Vector2, to_node: Node2D = null) -> void:
	projectile_type = type
	position = from
	target_pos = to_pos
	target_node = to_node

	var data = _get_config()
	speed = data.get("speed", 200.0)
	damage = data.get("damage", 10.0)
	homing = data.get("homing", false)
	hit_radius = data.get("hit_radius", 8.0)
	lifetime = data.get("lifetime", 5.0)
	trail_enabled = data.get("trail", false)
	_trail_max = data.get("trail_length", 10)

	var trail_col = data.get("trail_color", "#9933cccc")
	trail_color = Color(trail_col)

	# Спрайт
	var sprite_path = data.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)

	var sc = data.get("scale", 1.0)
	sprite.scale = Vector2(sc, sc)

	# Поворачиваем в сторону цели
	var dir = (target_pos - position).normalized()
	sprite.rotation = dir.angle()


func _get_config() -> Dictionary:
	return Config.projectiles.get(projectile_type, {})


func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime:
		_on_miss()
		return

	# Обновляем цель для самонаводящихся
	if homing and is_instance_valid(target_node):
		target_pos = target_node.global_position

	# Движение
	var dir = (target_pos - position)
	var dist = dir.length()

	if dist < hit_radius:
		_on_hit()
		return

	var move = dir.normalized() * speed * delta
	if move.length() > dist:
		position = target_pos
	else:
		position += move

	# Поворот спрайта
	sprite.rotation = dir.angle()

	# Трейл
	if trail_enabled:
		_trail_points.append(position)
		if _trail_points.size() > _trail_max:
			_trail_points = _trail_points.slice(_trail_points.size() - _trail_max)
		queue_redraw()


func _on_hit() -> void:
	if is_instance_valid(target_node) and target_node.has_method("take_damage"):
		target_node.take_damage(damage)
	_spawn_hit_effect()
	queue_free()


func _on_miss() -> void:
	_spawn_hit_effect()
	queue_free()


func _spawn_hit_effect() -> void:
	# Можно потом добавить партиклы
	pass


func _draw() -> void:
	if not trail_enabled or _trail_points.size() < 2:
		return
	for i in range(_trail_points.size() - 1):
		var alpha = float(i) / _trail_points.size()
		var col = Color(trail_color, trail_color.a * alpha)
		var width = 1.0 + alpha * 2.0
		var from_local = _trail_points[i] - position
		var to_local = _trail_points[i + 1] - position
		draw_line(from_local, to_local, col, width)


# === Статический спавнер ===

static func spawn(tree: SceneTree, type: String, from: Vector2, to_pos: Vector2, to_node: Node2D = null) -> Projectile:
	var scene = load("res://scenes/projectiles/projectile.tscn")
	var proj = scene.instantiate() as Projectile
	tree.current_scene.get_node("YSort").add_child(proj)
	proj.setup(type, from, to_pos, to_node)
	return proj
