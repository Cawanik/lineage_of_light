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
var hit_type: String = ""  # "" = single, "aoe" = area
var aoe_radius: float = 0.0
var lifetime: float = 5.0
var _age: float = 0.0
var arc_height: float = 40.0
var _start_pos: Vector2 = Vector2.ZERO
var _total_dist: float = 0.0

# Визуал
var trail_enabled: bool = false
var trail_color: Color = Color(0.6, 0.3, 1.0, 0.8)
var _trail_points: PackedVector2Array = PackedVector2Array()
var _trail_max: int = 10
var draw_mode: String = ""  # "" = sprite, "orb" = процедурный шар, "sprite_tex" = текстура из конфига
var orb_radius: float = 5.0
var orb_color: Color = Color(0.7, 0.2, 1.0, 1.0)
var orb_glow_color: Color = Color(1.0, 0.5, 0.0, 0.4)
var is_static: bool = false  # Статичный на тайле (не летит)
var static_duration: float = 3.0  # Сколько живёт статичный
var static_tick: float = 0.5  # Интервал нанесения урона
var _static_tick_timer: float = 0.0
var slow_percent: float = 0.0  # Замедление врагов (0.0-1.0)

@onready var sprite: Sprite2D = $Sprite2D


func setup(type: String, from: Vector2, to_pos: Vector2, to_node: Node2D = null) -> void:
	projectile_type = type
	position = from
	target_pos = to_pos
	target_node = to_node

	_start_pos = from
	_total_dist = from.distance_to(to_pos)

	var data = _get_config()
	speed = data.get("speed", 200.0)
	arc_height = data.get("arc_height", 40.0)
	damage = data.get("damage", 10.0)
	homing = data.get("homing", false)
	hit_radius = data.get("hit_radius", 8.0)
	hit_type = data.get("hit_type", "")
	aoe_radius = data.get("aoe_radius", 0.0)
	lifetime = data.get("lifetime", 5.0)
	trail_enabled = data.get("trail", false)
	_trail_max = data.get("trail_length", 10)

	var trail_col = data.get("trail_color", "#9933cccc")
	trail_color = Color(trail_col)

	draw_mode = data.get("draw_mode", "")
	orb_radius = data.get("orb_radius", 5.0)
	if data.has("orb_color"):
		orb_color = Color(data["orb_color"])
	if data.has("orb_glow_color"):
		orb_glow_color = Color(data["orb_glow_color"])

	is_static = data.get("static", false)
	static_duration = data.get("static_duration", 3.0)
	static_tick = data.get("static_tick", 0.5)
	slow_percent = data.get("slow", 0.0)

	if is_static:
		lifetime = static_duration
		# Jitter для статичных проджектайлов
		var jitter_r = data.get("jitter", 0.0)
		var jitter_offset = Vector2.ZERO
		if jitter_r > 0:
			jitter_offset = Vector2(randf_range(-jitter_r, jitter_r), randf_range(-jitter_r, jitter_r))
		position = to_pos + jitter_offset
		z_index = 0

	if draw_mode == "orb":
		sprite.visible = false
	elif draw_mode == "animated":
		# Анимированный проджектайл — рандомный вариант
		sprite.visible = false
		var variants = data.get("anim_variants", [])
		if not variants.is_empty():
			var variant_path = variants[randi() % variants.size()]
			var anim_spr = AnimatedSprite2D.new()
			anim_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var sf = SpriteFrames.new()
			sf.add_animation("play")
			sf.set_animation_speed("play", data.get("anim_fps", 4.0))
			sf.set_animation_loop("play", true)
			# Загружаем фреймы: prefix_0001.png ...
			var prefix = variant_path.get_file()
			for i in range(1, 100):
				var path = variant_path + "_%04d.png" % i if not variant_path.ends_with("/") else variant_path + "%04d.png" % i
				# Пробуем prefix_0001 формат
				var frame_path = variant_path.get_base_dir() + "/" + prefix + "_%04d.png" % i
				if ResourceLoader.exists(frame_path):
					sf.add_frame("play", load(frame_path))
				else:
					break
			if sf.has_animation("default"):
				sf.remove_animation("default")
			anim_spr.sprite_frames = sf
			var spr_offset = data.get("sprite_offset", [0.0, 0.0])
			anim_spr.position = Vector2(spr_offset[0], spr_offset[1])
			var sc = data.get("scale", 1.0)
			anim_spr.scale = Vector2(sc, sc)
			add_child(anim_spr)
			anim_spr.play("play")
	elif draw_mode == "sprite_tex":
		# Текстура из конфига
		var tex_path = data.get("texture", "")
		if tex_path != "" and ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sc = data.get("scale", 1.0)
		sprite.scale = Vector2(sc, sc)
		sprite.rotation = 0.0
		var spr_offset = data.get("sprite_offset", [0.0, 0.0])
		sprite.position = Vector2(spr_offset[0], spr_offset[1])
	else:
		var sprite_path = data.get("sprite", "")
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			sprite.texture = load(sprite_path)
		var sc = data.get("scale", 1.0)
		sprite.scale = Vector2(sc, sc)
		var dir = (target_pos - position).normalized()
		sprite.rotation = dir.angle()


func _get_config() -> Dictionary:
	return Config.projectiles.get(projectile_type, {})


func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime:
		_on_miss()
		return

	# Статичный проджектайл — наносит урон по тику
	if is_static:
		_static_tick_timer -= delta
		if _static_tick_timer <= 0:
			_static_tick_timer = static_tick
			_apply_static_effects()
		# Fade out в конце жизни
		var remaining = lifetime - _age
		if remaining < 0.5:
			modulate.a = remaining / 0.5
		return

	# Обновляем цель для самонаводящихся
	if homing and is_instance_valid(target_node):
		target_pos = target_node.global_position

	# Движение по дуге
	var traveled = _age * speed
	var progress = clampf(traveled / _total_dist, 0.0, 1.0) if _total_dist > 0 else 1.0

	if progress >= 0.99:
		_on_hit()
		return

	# Линейная позиция
	var flat_pos = _start_pos.lerp(target_pos, progress)

	# Парабола: arc = 4 * h * t * (1 - t)
	var arc_y = -arc_height * 4.0 * progress * (1.0 - progress)
	position = flat_pos + Vector2(0, arc_y)

	# Поворот спрайта по направлению движения (только если спрайт используется)
	if draw_mode != "orb":
		var next_progress = clampf(progress + 0.05, 0.0, 1.0)
		var next_flat = _start_pos.lerp(target_pos, next_progress)
		var next_arc_y = -arc_height * 4.0 * next_progress * (1.0 - next_progress)
		var next_pos = next_flat + Vector2(0, next_arc_y)
		sprite.rotation = (next_pos - position).angle()

	# Трейл
	if trail_enabled:
		_trail_points.append(position)
		if _trail_points.size() > _trail_max:
			_trail_points = _trail_points.slice(_trail_points.size() - _trail_max)
		queue_redraw()

	# Орб всегда требует redraw (пульсация цвета)
	if draw_mode == "orb":
		var pulse = sin(_age * 8.0) * 0.1
		orb_color.a = clampf(1.0 + pulse, 0.8, 1.0)
		queue_redraw()


func _apply_static_effects() -> void:
	var radius_sq = hit_radius * hit_radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if position.distance_squared_to(e.global_position) > radius_sq:
			continue
		if e.has_method("take_damage"):
			e.take_damage(damage)
		if slow_percent > 0 and e.has_method("apply_slow"):
			e.apply_slow(slow_percent, static_tick * 1.5)


func _on_hit() -> void:
	if hit_type == "aoe":
		var aoe_sq = aoe_radius * aoe_radius
		var hit_pos = target_pos
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.has_method("take_damage"):
				if hit_pos.distance_squared_to(e.global_position) <= aoe_sq:
					e.take_damage(damage)
					_apply_hit_debuff(e)
	else:
		if is_instance_valid(target_node):
			if damage > 0 and target_node.has_method("take_damage"):
				target_node.take_damage(damage)
			_apply_hit_debuff(target_node)
	_spawn_hit_effect()
	queue_free()


func _apply_hit_debuff(enemy: Node2D) -> void:
	var data = _get_config()
	var debuff_type = data.get("on_hit_debuff", "")
	if debuff_type == "":
		return
	var value = data.get("debuff_value", 1.0)
	var duration = data.get("debuff_duration", 3.0)
	match debuff_type:
		"slow":
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(value, duration)
		"curse":
			if enemy.has_method("apply_curse"):
				enemy.apply_curse(value, duration)


func _on_miss() -> void:
	_spawn_hit_effect()
	queue_free()


func _spawn_hit_effect() -> void:
	# Можно потом добавить партиклы
	pass


func _draw() -> void:
	# Трейл
	if trail_enabled and _trail_points.size() >= 2:
		for i in range(_trail_points.size() - 1):
			var alpha = float(i) / _trail_points.size()
			var col = Color(trail_color, trail_color.a * alpha)
			var width = 1.0 + alpha * 2.0
			var from_local = _trail_points[i] - position
			var to_local = _trail_points[i + 1] - position
			draw_line(from_local, to_local, col, width)

	# Процедурный орб (файербол)
	if draw_mode == "orb":
		# Внешнее свечение (несколько полупрозрачных кругов)
		for i in range(3):
			var t = float(i) / 3.0
			var glow_r = orb_radius * (2.5 - t * 1.2)
			var glow_a = orb_glow_color.a * (0.3 - t * 0.08)
			draw_circle(Vector2.ZERO, glow_r, Color(orb_glow_color, glow_a))
		# Основной шар
		draw_circle(Vector2.ZERO, orb_radius, orb_color)
		# Яркий центр
		draw_circle(Vector2.ZERO, orb_radius * 0.45, Color(1.0, 1.0, 1.0, 0.85))


# === Статический спавнер ===

static func spawn(tree: SceneTree, type: String, from: Vector2, to_pos: Vector2, to_node: Node2D = null) -> Projectile:
	var scene = load("res://scenes/projectiles/projectile.tscn")
	var proj = scene.instantiate() as Projectile
	tree.current_scene.get_node("YSort").add_child(proj)
	proj.setup(type, from, to_pos, to_node)
	return proj
