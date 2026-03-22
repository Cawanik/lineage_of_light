# ==========================================
# building.gd — Базовый класс зданий, блять
# ==========================================
# _process(_delta) — каждый кадр ищет игрока и обновляет прозрачность, нахуй
# setup(type) — настраивает здание по типу из конфига: хп, спрайт, офсет, юнит, коллизия — всё в одном месте, ёпт
# _create_tile_collision() — создаёт изометрический ромб-коллизию на тайле, чтоб не проходили сквозь
# _setup_unit(data) — спавнит анимированного юнита (idle) рядом со зданием, с рандомным jitter'ом, сука
# take_damage(amount) — получает урон, если хп <= 0 — пиздец, удаляем
# _update_hp_bar() — обновляет полоску хп: зелёная/оранжевая/красная, ну ты понял
# _on_destroyed() — вызывается когда зданию пизда, queue_free по дефолту
# toggle_adjust() — включает/выключает дебаг-режим подгонки спрайта стрелками
# _input(event) — обрабатывает стрелки в adjust-режиме, двигает спрайт, печатает офсет
# _draw() — рисует дебаг-ромб и крестик в adjust-режиме, чтоб было видно куда хуярить
# ==========================================

class_name Building
extends Node2D

## Base class for all buildings with HP

var building_type: String = ""
var max_hp: float = 100.0
var hp: float = 100.0
var can_build: bool = true
var can_demolish: bool = true
var can_move: bool = true
var move_cost: int = 0
var upgrade_level: int = 0
var _adjust_mode: bool = false

# Атака
var attack_range_cardinal: int = 0
var attack_range_diagonal: int = 0
var attack_speed: float = 0.0
var attack_projectile: String = ""
var _attack_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_bar_bg: ColorRect = $HPBarBG
@onready var hp_bar: ColorRect = $HPBar

const CELL_SIZE = 64
const ISO_RATIO = 0.5


func _process(_delta: float) -> void:
	OcclusionFade.find_player(get_tree())
	OcclusionFade.update_node_fade(self)

	# Атака врагов
	if attack_speed > 0 and PhaseManager.is_combat_phase():
		_attack_timer -= _delta
		if _attack_timer <= 0:
			var target = _find_enemy_in_range()
			if target:
				_shoot(target)
				_attack_timer = 1.0 / attack_speed
			else:
				_attack_timer = 0.1  # Быстрее проверяем когда нет цели


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

	var sc = data.get("sprite_scale", [1.0, 1.0])
	sprite.scale = Vector2(sc[0], sc[1])

	can_build = data.get("can_build", true)
	can_demolish = data.get("can_demolish", true)
	can_move = data.get("can_move", true)
	move_cost = data.get("move_cost", 0)

	attack_range_cardinal = int(data.get("attack_range_cardinal", 0))
	attack_range_diagonal = int(data.get("attack_range_diagonal", 0))
	attack_speed = data.get("attack_speed", 0.0)
	attack_projectile = data.get("attack_projectile", "")

	_create_tile_collision()
	_setup_unit(data)


func _create_tile_collision() -> void:
	# Remove existing StaticBody if any (from tscn)
	var existing = get_node_or_null("StaticBody2D")
	if existing:
		existing.queue_free()

	# Isometric diamond collision matching one tile
	var hw = CELL_SIZE * 0.5  # 32
	var hh = CELL_SIZE * ISO_RATIO * 0.5  # 16

	var body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0

	var shape = CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array([
		Vector2(0, -hh),
		Vector2(hw, 0),
		Vector2(0, hh),
		Vector2(-hw, 0),
	])

	body.add_child(shape)
	add_child(body)


func _setup_unit(data: Dictionary) -> void:
	var unit_path = data.get("unit_idle", "")
	if unit_path == "":
		return

	var unit_sprite = AnimatedSprite2D.new()
	unit_sprite.name = "UnitSprite"
	var frames = SpriteFrames.new()

	var idle_name = "idle"
	frames.add_animation(idle_name)
	frames.set_animation_speed(idle_name, 6.0)
	frames.set_animation_loop(idle_name, true)
	for i in range(100):
		var path = unit_path + "/frame_%03d.png" % i
		if ResourceLoader.exists(path):
			frames.add_frame(idle_name, load(path))
		else:
			break

	# Анимация атаки
	var attack_path = data.get("unit_attack", "")
	if attack_path != "":
		var attack_name = "attack"
		frames.add_animation(attack_name)
		frames.set_animation_speed(attack_name, 12.0)
		frames.set_animation_loop(attack_name, false)
		for i in range(100):
			var path = attack_path + "/frame_%03d.png" % i
			if ResourceLoader.exists(path):
				frames.add_frame(attack_name, load(path))
			else:
				break

	if frames.has_animation("default"):
		frames.remove_animation("default")

	unit_sprite.sprite_frames = frames
	var unit_offset = data.get("unit_offset", [0.0, 0.0])
	var base_pos = Vector2(unit_offset[0], unit_offset[1])

	# Углы верхушки башни (изометрический ромб)
	var corners = [
		Vector2(-8, -4),
		Vector2(8, -4),
		Vector2(-8, 1),
		Vector2(8, 1),
	]

	# Собираем занятые углы
	var taken: Array[int] = []
	for child in get_children():
		if child is AnimatedSprite2D and child.has_meta("corner_idx"):
			taken.append(child.get_meta("corner_idx"))

	# Выбираем рандомный свободный угол
	var free_corners: Array[int] = []
	for i in range(corners.size()):
		if i not in taken:
			free_corners.append(i)

	var corner_idx: int
	if free_corners.is_empty():
		corner_idx = randi() % corners.size()
	else:
		corner_idx = free_corners[randi() % free_corners.size()]

	var corner_offset = corners[corner_idx]

	unit_sprite.position = base_pos + corner_offset
	unit_sprite.z_index = int(corner_offset.y + 5)
	unit_sprite.z_as_relative = true
	unit_sprite.set_meta("corner_idx", corner_idx)
	add_child(unit_sprite)
	unit_sprite.play(idle_name)


func _find_enemy_in_range() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var my_tile = _get_my_tile()
	if my_tile == Vector2i(-9999, -9999):
		return null

	var closest: Node2D = null
	var closest_dist: float = 9999.0

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var enemy_tile = enemy.current_tile
		var dx = absi(enemy_tile.x - my_tile.x)
		var dy = absi(enemy_tile.y - my_tile.y)

		# Евклидово расстояние — круговой радиус
		var euclidean = sqrt(float(dx * dx + dy * dy))
		if euclidean <= float(attack_range_cardinal) + 0.5:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = enemy

	return closest


func _get_unit_sprites() -> Array:
	var units: Array = []
	for child in get_children():
		if child is AnimatedSprite2D and child.has_meta("corner_idx"):
			units.append(child)
	return units


func _shoot(target: Node2D) -> void:
	if attack_projectile == "":
		return
	var units = _get_unit_sprites()
	if units.is_empty():
		Projectile.spawn(get_tree(), attack_projectile, global_position + Vector2(0, -40), target.global_position, target)
		return

	for unit in units:
		# Проджектайл из позиции юнита
		var shoot_from = global_position + unit.position + Vector2(0, 5)
		var target_jitter = Vector2(randf_range(-6, 6), randf_range(-3, 3))
		Projectile.spawn(get_tree(), attack_projectile, shoot_from, target.global_position + target_jitter, target)
		# Анимация стрельбы
		if unit.sprite_frames.has_animation("attack"):
			unit.play("attack")
			# Вернуть idle после окончания
			if not unit.animation_finished.is_connected(_on_unit_attack_finished):
				unit.animation_finished.connect(_on_unit_attack_finished.bind(unit))


func _on_unit_attack_finished(unit: AnimatedSprite2D) -> void:
	if is_instance_valid(unit) and unit.sprite_frames.has_animation("idle"):
		unit.play("idle")
		if unit.animation_finished.is_connected(_on_unit_attack_finished):
			unit.animation_finished.disconnect(_on_unit_attack_finished)


func _get_my_tile() -> Vector2i:
	var bg = get_tree().current_scene.get_node_or_null("YSort/BuildingGrid") as BuildingGrid
	if bg:
		return bg.world_to_tile(global_position)
	return Vector2i(-9999, -9999)


func take_damage(amount: float) -> void:
	hp -= amount
	_update_hp_bar()
	if hp <= 0:
		_on_destroyed()


func _update_hp_bar() -> void:
	var ratio = clampf(hp / max_hp, 0.0, 1.0)
	hp_bar.scale.x = ratio

	if ratio > 0.5:
		hp_bar.color = Color(0.2, 0.8, 0.2)
	elif ratio > 0.25:
		hp_bar.color = Color(1.0, 0.7, 0.1)
	else:
		hp_bar.color = Color(1.0, 0.15, 0.15)

	hp_bar_bg.visible = ratio < 1.0
	hp_bar.visible = ratio < 1.0


func _on_destroyed() -> void:
	# Уведомляем BuildingGrid — это вызовет PathfindingSystem.set_tile_solid(tile, false)
	# и эмитирует path_grid_changed, чтобы все враги пересчитали путь
	var bg = get_tree().current_scene.get_node_or_null("YSort/BuildingGrid") as BuildingGrid
	if bg:
		var tile = bg.world_to_tile(global_position)
		if bg.buildings.get(tile) == self:
			bg.remove_building(tile)
	queue_free()


func toggle_adjust() -> void:
	_adjust_mode = not _adjust_mode
	queue_redraw()
	if _adjust_mode:
		print("[BuildingAdjust] ON for %s" % building_type)
		print("  Arrows = move offset, +/- = scale, Shift = x5, Enter = print")
	else:
		print("[BuildingAdjust] OFF")


func _input(event: InputEvent) -> void:
	if not _adjust_mode:
		return
	if not (event is InputEventKey and event.pressed):
		return

	var s = 1.0 if not event.shift_pressed else 5.0
	var scale_step = 0.05 if not event.shift_pressed else 0.2

	match event.keycode:
		KEY_UP:
			sprite.position.y -= s
		KEY_DOWN:
			sprite.position.y += s
		KEY_LEFT:
			sprite.position.x -= s
		KEY_RIGHT:
			sprite.position.x += s
		KEY_EQUAL, KEY_KP_ADD:
			sprite.scale += Vector2(scale_step, scale_step)
		KEY_MINUS, KEY_KP_SUBTRACT:
			sprite.scale -= Vector2(scale_step, scale_step)
			sprite.scale = Vector2(maxf(sprite.scale.x, 0.1), maxf(sprite.scale.y, 0.1))
		KEY_ENTER:
			print("[BuildingAdjust] \"%s\":" % building_type)
			print("  sprite_offset: [%.1f, %.1f]" % [sprite.position.x, sprite.position.y])
			print("  sprite_scale: [%.2f, %.2f]" % [sprite.scale.x, sprite.scale.y])
			return
		_:
			return

	queue_redraw()
	print("[BuildingAdjust] offset: %s  scale: %s" % [sprite.position, sprite.scale])


func _draw() -> void:
	if not _adjust_mode:
		return

	# Draw tile diamond at origin (building is placed at tile center)
	var hw = CELL_SIZE * 0.5
	var hh = CELL_SIZE * ISO_RATIO * 0.5
	var diamond = [
		Vector2(0, -hh),
		Vector2(hw, 0),
		Vector2(0, hh),
		Vector2(-hw, 0),
	]
	for i in range(4):
		draw_line(diamond[i], diamond[(i + 1) % 4], Color.RED, 2.0)

	# Crosshair at tile center
	draw_line(Vector2(-10, 0), Vector2(10, 0), Color.YELLOW, 1.0)
	draw_line(Vector2(0, -10), Vector2(0, 10), Color.YELLOW, 1.0)
