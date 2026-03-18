# ==========================================
# lich_king.gd — Лич Кинг, бродит вокруг трона как ёбаный босс
# ==========================================
# _ready() — грузит конфиг, настраивает анимации, находит трон, спавнится рядом
# _load_config() — тащит все настройки из game.json: пути, скорость, офсеты
# _find_throne() — ищет трон в building_grid, запоминает тайл
# _spawn_near_throne() — спавнится на свободном соседнем тайле рядом с троном
# _process(_delta) — прозрачность + движение к цели или idle таймер
# _pick_next_target() — выбирает рандомный свободный тайл рядом с троном
# _update_flip(dir_key) — флипает спрайт для западных направлений
# _get_direction_key(dir) — определяет направление анимации по вектору
# _get_free_neighbors(from) — 4 кардинальных свободных соседа
# _on_building_moved(btype, from, to) — если трон переехал — респавн
# _setup_animations() — собирает SpriteFrames для 8 направлений
# ==========================================

extends AnimatedSprite2D

var idle_path: String = "res://assets/sprites/lich_king/animations/breathing-idle/"
var walk_path: String = "res://assets/sprites/lich_king/animations/walking-8-frames/"
var rot_path: String = "res://assets/sprites/lich_king/rotations/"
const DIRECTIONS = ["south", "south-east", "east", "north-east", "north"]

var walk_speed: float = 15.0
var idle_time_min: float = 2.0
var idle_time_max: float = 5.0

var building_grid: BuildingGrid = null
var throne_tile: Vector2i = Vector2i(-9999, -9999)
var target_pos: Vector2 = Vector2.ZERO
var is_walking: bool = false
var idle_timer: float = 0.0
var current_dir: String = "south"


func _load_config() -> void:
	var cfg = Config.game.get("lich_king", {})
	idle_path = cfg.get("idle_path", idle_path)
	walk_path = cfg.get("walk_path", walk_path)
	rot_path = cfg.get("rotations_path", rot_path)
	walk_speed = cfg.get("walk_speed", walk_speed)
	idle_time_min = cfg.get("idle_time_min", idle_time_min)
	idle_time_max = cfg.get("idle_time_max", idle_time_max)

	var s = cfg.get("scale", 1.25)
	scale = Vector2(s, s)

	var so = cfg.get("sprite_offset", [0.0, -16.0])
	offset = Vector2(so[0], so[1])


func _ready() -> void:
	_load_config()
	_setup_animations()
	play("idle_south")
	await get_tree().process_frame
	var ysort = get_parent()
	if ysort:
		building_grid = ysort.get_node_or_null("BuildingGrid")
	if building_grid:
		building_grid.building_moved.connect(_on_building_moved)
		_find_throne()
		_spawn_near_throne()
		target_pos = position
		idle_timer = randf_range(idle_time_min, idle_time_max)


func _find_throne() -> void:
	for tile in building_grid.buildings:
		var b = building_grid.buildings[tile]
		if b.building_type == "throne":
			throne_tile = tile
			return


func _on_building_moved(btype: String, _from: Vector2i, to: Vector2i) -> void:
	if btype == "throne":
		throne_tile = to
		is_walking = false
		_spawn_near_throne()
		target_pos = position
		idle_timer = randf_range(idle_time_min, idle_time_max)


func _spawn_near_throne() -> void:
	var free_tiles = _get_free_neighbors(throne_tile)
	var chosen: Vector2i
	if not free_tiles.is_empty():
		chosen = free_tiles[randi() % free_tiles.size()]
	else:
		chosen = throne_tile
	position = building_grid.tile_to_world(chosen)


func _process(delta: float) -> void:
	OcclusionFade.find_player(get_tree())
	OcclusionFade.update_node_fade(self)

	if not building_grid:
		return

	# Проверяем, не заняли ли текущий или целевой тайл
	var current_tile = building_grid.world_to_tile(position)
	var target_tile = building_grid.world_to_tile(target_pos)
	if building_grid.is_occupied(current_tile) or (is_walking and building_grid.is_occupied(target_tile)):
		_spawn_near_throne()
		target_pos = position
		is_walking = false
		idle_timer = randf_range(idle_time_min, idle_time_max)
		var anim = "idle_" + current_dir
		if sprite_frames.has_animation(anim):
			play(anim)
		return

	if is_walking:
		var dir = (target_pos - position)
		var dist = dir.length()
		if dist < 1.0:
			position = target_pos
			is_walking = false
			idle_timer = randf_range(idle_time_min, idle_time_max)
			var anim = "idle_" + current_dir
			if sprite_frames.has_animation(anim):
				play(anim)
			_update_flip(current_dir)
		else:
			position += dir.normalized() * walk_speed * delta
	else:
		idle_timer -= delta
		if idle_timer <= 0.0:
			_pick_next_target()


func _pick_next_target() -> void:
	# Выбираем только из соседей текущего тайла, которые тоже рядом с троном
	var current_tile = building_grid.world_to_tile(position)
	var my_neighbors = _get_free_neighbors(current_tile)
	var valid: Array[Vector2i] = []
	for tile in my_neighbors:
		# Только тайлы в радиусе 1 от трона
		if absi(tile.x - throne_tile.x) <= 1 and absi(tile.y - throne_tile.y) <= 1:
			valid.append(tile)

	if valid.is_empty():
		idle_timer = randf_range(idle_time_min, idle_time_max)
		return

	var chosen = valid[randi() % valid.size()]
	target_pos = building_grid.tile_to_world(chosen)

	var move_dir = target_pos - position
	current_dir = _get_direction_key(move_dir)

	var walk_anim = "walk_" + current_dir
	_update_flip(current_dir)
	if sprite_frames.has_animation(walk_anim):
		play(walk_anim)
	else:
		var idle_anim = "idle_" + current_dir
		if sprite_frames.has_animation(idle_anim):
			play(idle_anim)
	is_walking = true


func _update_flip(dir_key: String) -> void:
	if dir_key.find("west") != -1:
		flip_h = true
	elif dir_key.find("east") != -1:
		flip_h = false
	else:
		flip_h = false


func _get_direction_key(dir: Vector2) -> String:
	var deg = rad_to_deg(dir.angle())
	if deg < 0:
		deg += 360.0

	if deg < 22.5 or deg >= 337.5:
		return "east"
	elif deg < 67.5:
		return "south_east"
	elif deg < 112.5:
		return "south"
	elif deg < 157.5:
		return "south_west"
	elif deg < 202.5:
		return "west"
	elif deg < 247.5:
		return "north_west"
	elif deg < 292.5:
		return "north"
	else:
		return "north_east"


func _get_free_neighbors(from: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cardinal = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir in cardinal:
		var tile = from + dir
		if not building_grid.is_occupied(tile):
			result.append(tile)
	return result


func _setup_animations() -> void:
	var cfg = Config.game.get("lich_king", {})
	var anim_speed = cfg.get("animation_speed", 2.0)
	var frames = SpriteFrames.new()

	for dir in DIRECTIONS:
		var dir_key = dir.replace("-", "_")
		var idle_name = "idle_" + dir_key
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, anim_speed)
		frames.set_animation_loop(idle_name, true)

		var loaded = false
		for i in range(10):
			var path = idle_path + dir + "/frame_%03d.png" % i
			if ResourceLoader.exists(path):
				frames.add_frame(idle_name, load(path))
				loaded = true
			else:
				break
		if not loaded:
			var rot = rot_path + dir + ".png"
			if ResourceLoader.exists(rot):
				frames.add_frame(idle_name, load(rot))

	# Walk animations
	for dir in DIRECTIONS:
		var dir_key = dir.replace("-", "_")
		var walk_name = "walk_" + dir_key
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, anim_speed * 1.5)
		frames.set_animation_loop(walk_name, true)

		for i in range(20):
			var path = walk_path + dir + "/frame_%03d.png" % i
			if ResourceLoader.exists(path):
				frames.add_frame(walk_name, load(path))
			else:
				break

	for dir in ["south-west", "west", "north-west"]:
		var dir_key = dir.replace("-", "_")
		var mirror_dir = dir.replace("west", "east")
		var mirror_key = mirror_dir.replace("-", "_")
		var idle_name = "idle_" + dir_key
		var mirror_name = "idle_" + mirror_key
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, anim_speed)
		frames.set_animation_loop(idle_name, true)
		if frames.has_animation(mirror_name):
			for i in range(frames.get_frame_count(mirror_name)):
				frames.add_frame(idle_name, frames.get_frame_texture(mirror_name, i))

		# Mirror walk
		var walk_name = "walk_" + dir_key
		var walk_mirror = "walk_" + mirror_key
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, anim_speed * 1.5)
		frames.set_animation_loop(walk_name, true)
		if frames.has_animation(walk_mirror):
			for i in range(frames.get_frame_count(walk_mirror)):
				frames.add_frame(walk_name, frames.get_frame_texture(walk_mirror, i))

	if frames.has_animation("default"):
		frames.remove_animation("default")

	sprite_frames = frames
