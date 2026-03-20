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

@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_bar_bg: ColorRect = $HPBarBG
@onready var hp_bar: ColorRect = $HPBar

const CELL_SIZE = 64
const ISO_RATIO = 0.5


func _process(_delta: float) -> void:
	OcclusionFade.find_player(get_tree())
	OcclusionFade.update_node_fade(self)


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

	if frames.has_animation("default"):
		frames.remove_animation("default")

	unit_sprite.sprite_frames = frames
	var unit_offset = data.get("unit_offset", [0.0, 0.0])
	var jitter = data.get("unit_offset_jitter", 0)
	var jx = randf_range(-jitter, jitter)
	var jy = randf_range(-jitter, jitter)
	unit_sprite.position = Vector2(unit_offset[0] + jx, unit_offset[1] + jy)
	add_child(unit_sprite)
	unit_sprite.play(idle_name)


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
