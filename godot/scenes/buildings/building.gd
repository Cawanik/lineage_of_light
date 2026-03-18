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

	can_build = data.get("can_build", true)
	can_demolish = data.get("can_demolish", true)
	can_move = data.get("can_move", true)
	move_cost = data.get("move_cost", 0)

	_create_tile_collision()


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
		print("[BuildingAdjust] ON for %s — Arrows to move sprite, Enter to print" % building_type)
	else:
		print("[BuildingAdjust] OFF")


func _input(event: InputEvent) -> void:
	if not _adjust_mode:
		return
	if not (event is InputEventKey and event.pressed):
		return

	var s = 1.0 if not event.shift_pressed else 5.0

	match event.keycode:
		KEY_UP:
			sprite.position.y -= s
		KEY_DOWN:
			sprite.position.y += s
		KEY_LEFT:
			sprite.position.x -= s
		KEY_RIGHT:
			sprite.position.x += s
		KEY_ENTER:
			print("[BuildingAdjust] \"%s\" sprite_offset: [%.1f, %.1f]" % [building_type, sprite.position.x, sprite.position.y])
			return
		_:
			return

	queue_redraw()
	print("[BuildingAdjust] offset: %s" % sprite.position)


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
