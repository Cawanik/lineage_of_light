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

var _abilities: Dictionary = {}
var _cooldowns: Dictionary = {}
var _storm_placing: bool = false
var _storm_ghost: Node2D = null
var _fireball_placing: bool = false
var _fireball_ghost: Node2D = null

const _KEY_MAP: Dictionary = {
	"space": KEY_SPACE,
	"q": KEY_Q, "w": KEY_W, "e": KEY_E, "r": KEY_R,
	"1": KEY_1, "2": KEY_2, "3": KEY_3,
	"f": KEY_F, "g": KEY_G,
}

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

	_abilities = Config.player.get("abilities", {})
	for id in _abilities:
		_cooldowns[id] = 0.0


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


func _process(delta: float) -> void:
	for id in _cooldowns:
		if _cooldowns[id] > 0.0:
			_cooldowns[id] -= delta

	if _storm_placing and is_instance_valid(_storm_ghost):
		var bg = get_tree().current_scene.get_node_or_null("YSort/BuildingGrid")
		if bg:
			var tile = bg.world_to_tile(get_global_mouse_position())
			_storm_ghost.global_position = bg.tile_to_world(tile)
			_storm_ghost.set_meta("hovered_tile", tile)
			var is_free = bg.get_building(tile) == null
			_storm_ghost.modulate = Color(1, 1, 1, 1) if is_free else Color(1, 0.3, 0.3, 1)

	if _fireball_placing and is_instance_valid(_fireball_ghost):
		var bg = get_tree().current_scene.get_node_or_null("YSort/BuildingGrid")
		if bg:
			var mouse_tile = bg.world_to_tile(get_global_mouse_position())
			# Центр 2x2 блока: верхний-левый тайл = mouse_tile
			var center = (bg.tile_to_world(mouse_tile) + bg.tile_to_world(mouse_tile + Vector2i(1, 1))) * 0.5
			_fireball_ghost.global_position = center
			_fireball_ghost.base_tile = mouse_tile
			_fireball_ghost.is_valid_placement = true


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
	if event is InputEventKey and event.pressed and not event.echo:
		for ability_id in _abilities:
			var key_str = _abilities[ability_id].get("key", "").to_lower()
			if key_str in _KEY_MAP and event.keycode == _KEY_MAP[key_str]:
				_try_cast(ability_id)
				return


func _unhandled_input(event: InputEvent) -> void:
	# Размещение шторма или фаербола
	if _storm_placing or _fireball_placing:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if _storm_placing: _place_storm()
				else: _place_fireball()
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if _storm_placing: _cancel_storm()
				else: _cancel_fireball()
				return
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			if _storm_placing: _cancel_storm()
			else: _cancel_fireball()
			return

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


func _try_cast(ability_id: String) -> void:
	if _cooldowns.get(ability_id, 0.0) > 0.0:
		return
	match ability_id:
		"magic_bolt":    _cast_magic_bolt()
		"magic_missile": _cast_magic_missile()
		"fireball":
			_cast_fireball()
			return  # кулдаун ставится в _place_fireball()
		"storm":
			_cast_storm()
			return  # кулдаун ставится в _place_storm()
	_cooldowns[ability_id] = _abilities[ability_id].get("cooldown", 1.0)


func _get_nearest_enemies(max_range: float, count: int) -> Array:
	var candidates: Array = []
	var max_dist_sq = max_range * max_range
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_squared_to(e.global_position)
		if d < max_dist_sq:
			candidates.append({"node": e, "dist": d})
	candidates.sort_custom(func(a, b): return a.dist < b.dist)
	var result: Array = []
	for i in range(mini(count, candidates.size())):
		result.append(candidates[i].node)
	return result


func _get_nearest_enemy(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_dist = max_range * max_range
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_squared_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best


func _cast_magic_bolt() -> void:
	var ability = _abilities.get("magic_bolt", {})
	var enemy = _get_nearest_enemy(ability.get("range", 400.0))
	if enemy == null:
		return
	var proj_type = ability.get("projectile", "magic_bolt")
	Projectile.spawn(get_tree(), proj_type, global_position, enemy.global_position, enemy)


func _cast_magic_missile() -> void:
	var ability = _abilities.get("magic_missile", {})
	var count = ability.get("count", 3)
	var proj_type = ability.get("projectile", "magic_bolt")
	var delay = ability.get("shot_delay", 0.15)
	var enemies = _get_nearest_enemies(ability.get("range", 400.0), count)
	if enemies.is_empty():
		return
	for i in range(count):
		var target = enemies[i % enemies.size()]
		Projectile.spawn(get_tree(), proj_type, global_position, target.global_position, target)
		if i < count - 1:
			await get_tree().create_timer(delay).timeout


func _cast_fireball() -> void:
	if _fireball_placing:
		return
	_fireball_placing = true

	var ability = _abilities.get("fireball", {})
	var ghost = FireballZone.new()
	ghost.damage = ability.get("damage", 30.0)
	ghost.fall_duration = ability.get("fall_duration", 0.5)
	ghost.is_preview = true
	get_tree().current_scene.get_node("YSort").add_child(ghost)
	ghost.global_position = get_global_mouse_position()
	_fireball_ghost = ghost


func _place_fireball() -> void:
	if not is_instance_valid(_fireball_ghost):
		_fireball_placing = false
		return
	_fireball_ghost.activate()
	_fireball_ghost = null
	_fireball_placing = false
	_cooldowns["fireball"] = _abilities["fireball"].get("cooldown", 3.0)


func _cancel_fireball() -> void:
	if is_instance_valid(_fireball_ghost):
		_fireball_ghost.queue_free()
	_fireball_ghost = null
	_fireball_placing = false


func _cast_storm() -> void:
	if _storm_placing:
		return
	_storm_placing = true

	var ability = _abilities.get("storm", {})
	var ghost = StormZone.new()
	ghost.damage = ability.get("damage", 10.0)
	ghost.duration = ability.get("duration", 5.0)
	ghost.tick_interval = ability.get("tick_interval", 0.5)
	ghost.is_preview = true
	get_tree().current_scene.get_node("YSort").add_child(ghost)
	ghost.global_position = get_global_mouse_position()
	_storm_ghost = ghost


func _place_storm() -> void:
	if not is_instance_valid(_storm_ghost):
		_storm_placing = false
		return
	var bg = get_tree().current_scene.get_node_or_null("YSort/BuildingGrid")
	if bg:
		var tile = _storm_ghost.get_meta("hovered_tile", Vector2i(-1, -1))
		if bg.get_building(tile) != null:
			return  # занято — не ставим
		_storm_ghost.storm_tile = tile
	_storm_ghost.modulate = Color(1, 1, 1, 1)
	_storm_ghost.activate()
	_storm_ghost = null
	_storm_placing = false
	_cooldowns["storm"] = _abilities["storm"].get("cooldown", 8.0)


func _cancel_storm() -> void:
	if is_instance_valid(_storm_ghost):
		_storm_ghost.queue_free()
	_storm_ghost = null
	_storm_placing = false


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
