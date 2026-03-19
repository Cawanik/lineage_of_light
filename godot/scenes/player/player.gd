# ==========================================
# player.gd — Управление волшебником, блять
# ==========================================
# _ready() — подгружает конфиг и настраивает всю анимационную хуйню
# _setup_animations() — создаёт SpriteFrames для ходьбы, idle и курения, ёбаный рот
# _physics_process(delta) — движение WASD/мышкой + AFK таймер, каждый сраный кадр
# _reset_afk() — сбрасывает AFK таймер нахуй
# _update_animation(input) — переключает анимации: ходьба, idle или курёха если AFK
# _vec_to_direction(v) — вектор в строку направления (8 сторон), математика ёпта
# _input(event) — ПКМ для движения мышкой + зум колёсиком
# _on_sit_finished() — после анимации присаживания запускает петлю курения
# _remove_marker() — убирает маркер движения нахуй
# _spawn_marker(pos) — ставит маркер куда кликнули ПКМ
# ==========================================

class_name Player
extends CharacterBody2D

var speed: float = 120.0
var zoom_speed: float = 0.1
var zoom_min: float = 0.5
var zoom_max: float = 4.0
var afk_timeout: float = 10.0
var move_threshold: float = 5.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

var last_direction: String = "south"
var move_target: Vector2 = Vector2.ZERO
var _target_zoom: float = 2.0
var _zoom_smooth_speed: float = 8.0
var using_mouse_move: bool = false
var afk_timer: float = 0.0
var is_afk: bool = false

var move_marker_scene: PackedScene = preload("res://scenes/ui/move_marker.tscn")
var current_marker: Node2D = null

const WALK_PATH = "res://assets/sprites/player/wizard/animations/walking-8-frames/"
const IDLE_PATH = "res://assets/sprites/player/wizard/animations/breathing-idle/"
const SMOKE_PATH = "res://assets/sprites/player/wizard/animations/smoke/"

const DIRECTIONS = ["south", "south-west", "west", "north-west", "north", "north-east", "east", "south-east"]


func _ready() -> void:
	var p = Config.player
	speed = p.get("speed", 120.0)
	zoom_speed = p.get("zoom_speed", 0.1)
	zoom_min = p.get("zoom_min", 0.5)
	zoom_max = p.get("zoom_max", 4.0)
	_target_zoom = camera.zoom.x
	afk_timeout = p.get("afk_timeout", 10.0)
	move_threshold = p.get("move_threshold", 5.0)

	_setup_animations()
	sprite.play("idle_south")


func _setup_animations() -> void:
	var frames = SpriteFrames.new()

	for dir in DIRECTIONS:
		var dir_key = dir.replace("-", "_")
		var is_se = (dir == "south-east")
		var fallback_dir = "south-west" if is_se else dir

		# Walk animation (8 frames)
		var walk_name = "walk_" + dir_key
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, 10.0)
		frames.set_animation_loop(walk_name, true)
		for i in range(8):
			var path = WALK_PATH + fallback_dir + "/frame_%03d.png" % i
			if ResourceLoader.exists(path):
				frames.add_frame(walk_name, load(path))

		# Idle animation: breathing-idle only for south, others use walk frame 0
		var idle_name = "idle_" + dir_key
		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, true)
		if dir == "south" or dir == "north":
			frames.set_animation_speed(idle_name, 2.0)
			var idle_loaded = false
			for i in range(20):
				var path = IDLE_PATH + dir + "/frame_%03d.png" % i
				if ResourceLoader.exists(path):
					frames.add_frame(idle_name, load(path))
					idle_loaded = true
				else:
					break
			if not idle_loaded:
				frames.add_frame(idle_name, load(WALK_PATH + fallback_dir + "/frame_000.png"))
		else:
			frames.set_animation_speed(idle_name, 1.0)
			var fallback = WALK_PATH + fallback_dir + "/frame_000.png"
			if ResourceLoader.exists(fallback):
				frames.add_frame(idle_name, load(fallback))

	# Smoke sit-down (plays once)
	var sit_name = "smoke_sit"
	frames.add_animation(sit_name)
	frames.set_animation_speed(sit_name, 6.0)
	frames.set_animation_loop(sit_name, false)
	for i in range(8):  # frames 0-7: sitting down
		var path = SMOKE_PATH + "south/frame_%03d.png" % i
		if ResourceLoader.exists(path):
			frames.add_frame(sit_name, load(path))

	# Smoke loop (frames 8+ from smoke folder)
	var smoke_name = "smoke_loop"
	frames.add_animation(smoke_name)
	frames.set_animation_speed(smoke_name, 6.0)
	frames.set_animation_loop(smoke_name, true)
	for i in range(8, 50):
		var path = SMOKE_PATH + "south/frame_%03d.png" % i
		if ResourceLoader.exists(path):
			frames.add_frame(smoke_name, load(path))
		else:
			break

	if frames.has_animation("default"):
		frames.remove_animation("default")

	sprite.sprite_frames = frames


func _physics_process(delta: float) -> void:
	var input = Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")

	# WASD overrides mouse movement
	if input.length() > 0:
		using_mouse_move = false
		_remove_marker()
		input = input.normalized()
		velocity = input * speed
		_reset_afk()
	elif using_mouse_move:
		var diff = move_target - global_position
		if diff.length() > move_threshold:
			input = diff.normalized()
			velocity = input * speed
			_reset_afk()
		else:
			using_mouse_move = false
			_remove_marker()
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	# AFK timer
	if velocity.length() < 1.0:
		afk_timer += delta
		if afk_timer >= afk_timeout and not is_afk:
			is_afk = true

	move_and_slide()
	_update_animation(input)

	# Обновляем позицию курсора для occlusion
	OcclusionFade.cursor_pos = get_global_mouse_position()

	# Плавный зум
	_target_zoom = clampf(_target_zoom, zoom_min, zoom_max)
	var current_zoom = camera.zoom.x
	if absf(current_zoom - _target_zoom) > 0.001:
		var new_zoom = lerpf(current_zoom, _target_zoom, _zoom_smooth_speed * delta)
		camera.zoom = Vector2(new_zoom, new_zoom)


func _reset_afk() -> void:
	afk_timer = 0.0
	is_afk = false


func _update_animation(input: Vector2) -> void:
	if input.length() > 0.1:
		last_direction = _vec_to_direction(input)

	sprite.flip_h = (last_direction == "south-east")

	var dir_key = last_direction.replace("-", "_")

	if velocity.length() > 1.0:
		var anim = "walk_" + dir_key
		if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
			sprite.play(anim)
	elif is_afk:
		if sprite.animation != "smoke_sit" and sprite.animation != "smoke_loop":
			last_direction = "south"
			sprite.flip_h = false
			sprite.play("smoke_sit")
			sprite.animation_finished.connect(_on_sit_finished, CONNECT_ONE_SHOT)
	else:
		var anim = "idle_" + dir_key
		if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
			sprite.play(anim)


func _vec_to_direction(v: Vector2) -> String:
	var angle = v.angle()
	if angle < 0:
		angle += TAU
	var sector = int(round(angle / (TAU / 8.0))) % 8
	var dirs = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return dirs[sector]


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			move_target = get_global_mouse_position()
			using_mouse_move = true
			_spawn_marker(move_target)
			_reset_afk()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_zoom = clampf(_target_zoom + zoom_speed, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_zoom = clampf(_target_zoom - zoom_speed, zoom_min, zoom_max)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		move_target = get_global_mouse_position()
		using_mouse_move = true
		_reset_afk()

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_cast_magic_bolt()


func _cast_magic_bolt() -> void:
	# Рандомная точка в пределах 2 тайлов (128px)
	var angle = randf() * TAU
	var dist = randf_range(64.0, 128.0)
	var target = global_position + Vector2(cos(angle), sin(angle)) * dist
	Projectile.spawn(get_tree(), "magic_bolt", global_position, target)


func _on_sit_finished() -> void:
	if is_afk:
		sprite.play("smoke_loop")


func _remove_marker() -> void:
	if is_instance_valid(current_marker):
		current_marker.queue_free()
		current_marker = null


func _spawn_marker(pos: Vector2) -> void:
	if is_instance_valid(current_marker):
		current_marker.queue_free()
	current_marker = move_marker_scene.instantiate()
	current_marker.global_position = pos
	get_tree().current_scene.add_child(current_marker)
