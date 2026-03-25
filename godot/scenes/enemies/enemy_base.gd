class_name EnemyBase
extends Node2D

## Grid-based enemy with AStarGrid2D pathfinding and wall attack FSM.

@onready var sprite: ColorRect = $Sprite
@onready var accent_sprite: ColorRect = $AccentSprite
@onready var hp_bar_bg: ColorRect = $HPBarBG
@onready var hp_bar: ColorRect = $HPBar
var anim_sprite: AnimatedSprite2D = null
var has_anim_sprite: bool = false
const ANIM_DIRECTIONS = ["south", "south-east", "east", "north-east", "north"]

# Визуальный jitter — чтобы враги не стакались
var visual_jitter: Vector2 = Vector2.ZERO
const JITTER_RANGE = 8.0

var enemy_type: String = "hero_barbarian"
var enemy_data: Dictionary = {}
var brain: EnemyBrain = null

var max_hp: float = 100.0
var hp: float = 100.0
var base_speed: float = 60.0
var current_speed: float = 60.0
var reward: int = 10
var damage_to_base: int = 1
var wall_dps: float = 10.0

var is_dead: bool = false
var path_progress: float = 0.0

# Slow effect
var slow_timer: float = 0.0
var slow_factor: float = 1.0

# Дебаффы
var debuffs: Dictionary = {}  # "slow" -> {timer, value}, "curse" -> {timer, value}
var _debuff_icons: Dictionary = {}  # "slow" -> Sprite2D

# Invincibility (выдаётся brain'ом)
var invincible_timer: float = 0.0
var _inv_pulse: float = 0.0

# Grid movement
var building_grid: Node = null
var wall_system: Node = null
var current_tile: Vector2i = Vector2i.ZERO
var target_tile: Vector2i = Vector2i.ZERO
var tile_path: Array[Vector2i] = []
var path_index: int = 0
var move_progress: float = 0.0

# FSM
enum State { MOVING, ATTACKING_WALL, ATTACKING_BUILDING, DEAD, VICTORY }
enum ThroneAccess { BLOCKED, CLEAR_PATH, ADJACENT }
var state: State = State.MOVING
var attacking_edge_key: StringName = &""
var attacking_building: Building = null
var attack_timer: float = 0.0
const ATTACK_INTERVAL: float = 0.5

var _repath_queued: bool = false

var wall_repath_timer: float = 0.0
const WALL_REPATH_INTERVAL: float = 2.0
var wall_attack_offset: Vector2 = Vector2.ZERO


func setup(type: String) -> void:
	enemy_type = type
	enemy_data = EnemyData.ENEMIES[type]

	max_hp = enemy_data["hp"]
	hp = max_hp
	base_speed = enemy_data["speed"]
	current_speed = base_speed
	reward = enemy_data["reward"]
	damage_to_base = enemy_data["damage_to_base"]
	wall_dps = enemy_data.get("wall_dps", 10.0)
	_init_brain()


func _init_brain() -> void:
	var brain_type = enemy_data.get("brain", "peasant")
	match brain_type:
		"peasant":
			brain = PeasantBrain.new()
		"knight":
			brain = KnightBrain.new()
		"mage":
			brain = MageBrain.new()
		"alchemist":
			brain = AlchemistBrain.new()
		"heir":
			brain = HeirBrain.new()
		_:
			brain = PeasantBrain.new()
	brain.setup(self)


## Публичные методы для мозгов
func start_wall_attack(wall_key: String) -> void:
	attacking_edge_key = wall_key
	state = State.ATTACKING_WALL
	attack_timer = 0.0
	wall_repath_timer = 0.0
	wall_attack_offset = _get_wall_spread_offset(wall_key)



func _ready() -> void:
	if enemy_data.is_empty():
		enemy_data = EnemyData.ENEMIES[enemy_type]

	# Рандомный jitter при спавне
	visual_jitter = Vector2(randf_range(-JITTER_RANGE, JITTER_RANGE), randf_range(-JITTER_RANGE * 0.5, JITTER_RANGE * 0.5))

	# Пробуем загрузить спрайты
	_setup_animated_sprite()

	if not has_anim_sprite:
		sprite.color = enemy_data["color"]
		accent_sprite.color = enemy_data["accent"]

	add_to_group("enemies")

	var ps = get_node_or_null("/root/PathfindingSystem")
	if ps:
		ps.path_grid_changed.connect(_on_path_grid_changed)


func _setup_animated_sprite() -> void:
	var sprite_path = enemy_data.get("sprite_path", "")
	if sprite_path == "":
		return

	var walk_anim_name = enemy_data.get("walk_anim", "walking-8-frames")
	var attack_anim_name = enemy_data.get("attack_anim", "")

	var frames = SpriteFrames.new()

	# Загружаем walk анимации для 5 направлений + зеркала
	for dir in ANIM_DIRECTIONS:
		var dir_key = dir.replace("-", "_")
		var anim_name = "walk_" + dir_key
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 8.0)
		frames.set_animation_loop(anim_name, true)
		for i in range(20):
			var path = sprite_path + "animations/" + walk_anim_name + "/" + dir + "/frame_%03d.png" % i
			if ResourceLoader.exists(path):
				frames.add_frame(anim_name, load(path))
			else:
				break

	# Зеркальные направления
	for dir in ["south-west", "west", "north-west"]:
		var dir_key = dir.replace("-", "_")
		var mirror_dir = dir.replace("west", "east")
		var mirror_key = mirror_dir.replace("-", "_")
		var anim_name = "walk_" + dir_key
		var mirror_name = "walk_" + mirror_key
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 8.0)
		frames.set_animation_loop(anim_name, true)
		if frames.has_animation(mirror_name):
			for i in range(frames.get_frame_count(mirror_name)):
				frames.add_frame(anim_name, frames.get_frame_texture(mirror_name, i))

	# Attack анимации
	if attack_anim_name != "":
		for dir in ANIM_DIRECTIONS:
			var dir_key = dir.replace("-", "_")
			var anim_name = "attack_" + dir_key
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, 10.0)
			frames.set_animation_loop(anim_name, true)
			for i in range(20):
				var path = sprite_path + "animations/" + attack_anim_name + "/" + dir + "/frame_%03d.png" % i
				if ResourceLoader.exists(path):
					frames.add_frame(anim_name, load(path))
				else:
					break
		# Зеркала атаки
		for dir in ["south-west", "west", "north-west"]:
			var dir_key = dir.replace("-", "_")
			var mirror_dir = dir.replace("west", "east")
			var mirror_key = mirror_dir.replace("-", "_")
			var anim_name = "attack_" + dir_key
			var mirror_name = "attack_" + mirror_key
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, 10.0)
			frames.set_animation_loop(anim_name, true)
			if frames.has_animation(mirror_name):
				for i in range(frames.get_frame_count(mirror_name)):
					frames.add_frame(anim_name, frames.get_frame_texture(mirror_name, i))

	# Idle = первый фрейм walk
	for dir in ANIM_DIRECTIONS:
		var dir_key = dir.replace("-", "_")
		var idle_name = "idle_" + dir_key
		var walk_name = "walk_" + dir_key
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 1.0)
		frames.set_animation_loop(idle_name, true)
		if frames.has_animation(walk_name) and frames.get_frame_count(walk_name) > 0:
			frames.add_frame(idle_name, frames.get_frame_texture(walk_name, 0))

	if frames.has_animation("default"):
		frames.remove_animation("default")

	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.sprite_frames = frames
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim_sprite.position = Vector2(0, -12)
	add_child(anim_sprite)
	anim_sprite.play("walk_south")

	# Прячем ColorRect
	sprite.visible = false
	accent_sprite.visible = false
	has_anim_sprite = true


func _update_enemy_anim(direction: Vector2) -> void:
	if not has_anim_sprite:
		return
	var dir_key = _vec_to_dir_key(direction)
	var anim_prefix = "walk_"
	if state == State.ATTACKING_WALL or state == State.ATTACKING_BUILDING:
		anim_prefix = "attack_"
	var anim_name = anim_prefix + dir_key
	if anim_sprite.sprite_frames.has_animation(anim_name):
		if anim_sprite.animation != anim_name:
			anim_sprite.play(anim_name)
	# Flip для западных направлений
	anim_sprite.flip_h = dir_key.find("west") != -1


func _vec_to_dir_key(dir: Vector2) -> String:
	if dir.length() < 0.01:
		return "south"
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


func set_victory_state() -> void:
	"""Called by GameManager when throne is destroyed - stop all AI activity"""
	state = State.VICTORY
	sprite.modulate = Color.GRAY  # Visual indication
	pass


func _on_path_grid_changed() -> void:
	if is_dead or state == State.VICTORY:
		return
	if not _repath_queued:
		_repath_queued = true
		call_deferred("_deferred_repath")


func _deferred_repath() -> void:
	_repath_queued = false
	if is_dead:
		return
	repath()


func repath() -> void:
	var ps = get_node_or_null("/root/PathfindingSystem")
	if not ps:
		push_error("EnemyBase: PathfindingSystem not found!")
		return

	var target = brain.get_path_target(ps, current_tile, building_grid)

	var detour_path: Array[Vector2i]
	var straight_path: Array[Vector2i]
	if target == ps.throne_tile:
		detour_path = ps.get_path_to_throne(current_tile)
		straight_path = ps.get_path_ignoring_walls(current_tile)
	else:
		detour_path = ps.get_path_to_tile(current_tile, target)
		straight_path = ps.get_path_to_tile_ignoring_walls(current_tile, target)

	# Brain определяет стратегию выбора пути
	tile_path = brain.choose_path(detour_path, straight_path, self)

	path_index = 0
	move_progress = 0.0

	if tile_path.is_empty():
		if not GameManager.is_game_active:
			set_victory_state()
		return

	# Skip current tile if it's first in path
	if tile_path[0] == current_tile and tile_path.size() > 1:
		path_index = 1

	if path_index < tile_path.size():
		target_tile = tile_path[path_index]

	state = State.MOVING


func _check_wall_ahead() -> void:
	# PHYSICS SEPARATION: Wall checking is now handled in _process_movement
	pass


func _process(delta: float) -> void:
	if is_dead or state == State.VICTORY:
		return
	
	# Stop all AI if game is over
	if not GameManager.is_game_active:
		if state != State.VICTORY:
			set_victory_state()
		return

	# Invincibility — золотой пульс
	if invincible_timer > 0:
		invincible_timer -= delta
		_inv_pulse += delta
		var pulse = 0.5 + 0.5 * sin(_inv_pulse * 12.0)
		modulate = Color(1.0 + pulse * 0.6, 1.0 + pulse * 0.4, 0.2 + pulse * 0.2)
		if invincible_timer <= 0:
			modulate = Color.WHITE
	# Дебаффы
	_update_debuffs(delta)
	# Slow effect (визуал)
	if slow_timer > 0:
		slow_timer -= delta
		current_speed = base_speed * slow_factor
		sprite.modulate = Color(0.6, 0.6, 1.0)
	else:
		current_speed = base_speed
		if invincible_timer <= 0:
			sprite.modulate = Color.WHITE

	# Debug state info (every 1 second)
	brain.process(delta)

	match state:
		State.MOVING:
			_process_movement(delta)
		State.ATTACKING_WALL:
			_process_wall_attack(delta)
		State.ATTACKING_BUILDING:
			_process_building_attack(delta)
		State.VICTORY:
			pass


func _process_movement(delta: float) -> void:
	if tile_path.is_empty() or path_index >= tile_path.size():
		return

	if not building_grid:
		return

	# TILE-BASED MOVEMENT: Move directly between tile centers
	var from_world = building_grid.tile_to_world(current_tile)
	var to_world = building_grid.tile_to_world(target_tile)
	var tile_distance = from_world.distance_to(to_world)

	if tile_distance < 0.1:
		move_progress = 1.0
	else:
		move_progress += (current_speed * delta) / tile_distance

	var target_pos = from_world.lerp(to_world, clampf(move_progress, 0.0, 1.0))

	# Обновляем анимацию по направлению движения
	_update_enemy_anim(to_world - from_world)

	# Проверяем столкновение с постройкой/стеной на следующем тайле
	# Игнорируем border тайлы (спавн-зоны) — враги могут по ним ходить
	if move_progress < 0.3 and building_grid and not building_grid.is_border(target_tile):
		var wall_edge_key = _make_edge_key(current_tile, target_tile)
		var wall_blocks = wall_system != null and wall_system.edges.has(wall_edge_key)
		var building_blocks = building_grid.buildings.has(target_tile)

		if wall_blocks or building_blocks:
			# Стена на пути — brain решает как реагировать
			if wall_blocks:
				brain.on_wall_encountered(wall_edge_key)
				return

			# Здание прямо на следующем тайле пути — атакуем
			if building_blocks:
				var blocking_building = building_grid.get_building(target_tile)
				if blocking_building and blocking_building is Building:
					_start_building_attack(blocking_building)
					return
			repath()
			return

	# Двигаемся + jitter
	global_position = target_pos + visual_jitter

	if move_progress >= 1.0:
		current_tile = target_tile
		path_index += 1
		move_progress = 0.0

		# Update tower targeting progress
		if tile_path.size() > 0:
			path_progress = float(path_index) / float(tile_path.size())

		# Трон рядом — атакуем сразу
		var throne_access = _evaluate_throne_accessibility()
		if throne_access == ThroneAccess.ADJACENT:
			var throne = _get_throne_building()
			if throne:
				_start_building_attack(throne)
				return

		# Башня в соседней клетке — атакуем только если brain разрешает
		if brain.should_attack_adjacent_towers():
			var adjacent_tower = _find_adjacent_tower()
			if adjacent_tower:
				_start_building_attack(adjacent_tower)
				return

		if path_index < tile_path.size():
			target_tile = tile_path[path_index]
		else:
			# Путь исчерпан — пересчитываем
			repath()


## Считает стоимость пути в секундах: время ходьбы + время пролома стен + время пролома зданий
func _calculate_path_cost(path: Array[Vector2i]) -> float:
	if path.is_empty():
		return INF
	var cell_size = 64.0
	var move_time = (path.size() - 1) * (cell_size / maxf(current_speed, 1.0))
	var break_time = 0.0
	for i in range(path.size() - 1):
		# Время пролома стены (ребра)
		if wall_system:
			var edge_key = _make_edge_key(path[i], path[i + 1])
			if wall_system.edges.has(edge_key):
				var wall_hp = wall_system.edge_hp.get(edge_key, 100.0)
				break_time += wall_hp / maxf(wall_dps, 0.1)
		# Время пролома здания на следующем тайле
		if building_grid and not building_grid.is_border(path[i + 1]):
			var bld = building_grid.get_building(path[i + 1])
			if bld and bld is Building:
				break_time += bld.hp / maxf(wall_dps, 0.1)
	return move_time + break_time


## Ищет атакующую башню (не wall_block, не трон) в 8 соседних клетках
func _find_adjacent_tower() -> Building:
	if not building_grid:
		return null
	var adjacent_tiles = [
		current_tile + Vector2i(-1, -1), current_tile + Vector2i(0, -1), current_tile + Vector2i(1, -1),
		current_tile + Vector2i(-1,  0),                                  current_tile + Vector2i(1,  0),
		current_tile + Vector2i(-1,  1), current_tile + Vector2i(0,  1), current_tile + Vector2i(1,  1),
	]
	for tile in adjacent_tiles:
		var building = building_grid.get_building(tile)
		if building and building is Building and building.attack_speed > 0:
			return building
	return null


func _find_nearest_wall_edge() -> String:
	if not wall_system:
		return ""
	
	var closest_key = ""
	var closest_distance = 999999.0
	
	for edge_key in wall_system.edges.keys():
		var parts = str(edge_key).split("-")
		if parts.size() == 2:
			var tile1_parts = parts[0].split(",")
			var tile2_parts = parts[1].split(",")
			if tile1_parts.size() == 2 and tile2_parts.size() == 2:
				var tile1 = Vector2i(int(tile1_parts[0]), int(tile1_parts[1]))
				var tile2 = Vector2i(int(tile2_parts[0]), int(tile2_parts[1]))
				var edge_center = (tile1 + tile2) * 0.5
				var distance = current_tile.distance_to(edge_center)
				# Only attack walls within 1.5 tiles (adjacent only)
				if distance <= 1.5 and distance < closest_distance:
					closest_distance = distance
					closest_key = edge_key
	
	return closest_key


func _process_wall_attack(delta: float) -> void:
	if not wall_system:
		state = State.MOVING
		return

	# Стена уничтожена другим врагом — уходим
	if not wall_system.edges.has(attacking_edge_key):
		sprite.modulate = Color.WHITE
		state = State.MOVING
		repath()
		return

	# Держим позицию с разбросом (чтобы не стакаться)
	if building_grid:
		global_position = building_grid.tile_to_world(current_tile) + wall_attack_offset

	# Периодически проверяем: а не выгоднее ли уйти?
	wall_repath_timer += delta
	if wall_repath_timer >= WALL_REPATH_INTERVAL:
		wall_repath_timer = 0.0
		_maybe_abandon_wall_attack()
		if state != State.ATTACKING_WALL:
			return

	sprite.modulate = Color(1.5, 1.0, 1.0)

	attack_timer += delta
	if attack_timer >= ATTACK_INTERVAL:
		attack_timer -= ATTACK_INTERVAL
		var destroyed = wall_system.damage_wall_edge(attacking_edge_key, wall_dps * ATTACK_INTERVAL)
		var am = get_node_or_null("/root/AudioManager")
		if am:
			am.play("enemy_hit")
		var remaining_hp = wall_system.edge_hp.get(attacking_edge_key, 0)
		
		if destroyed:
			sprite.modulate = Color.WHITE
			_stabilize_physics_after_wall_destruction()
			state = State.MOVING
			await get_tree().process_frame
			brain.on_wall_destroyed()


## Проверяет: стоит ли бросить атаку стены и пойти по открытому пути
func _maybe_abandon_wall_attack() -> void:
	var ps = get_node_or_null("/root/PathfindingSystem")
	if not ps or not wall_system:
		return
	var target = brain.get_path_target(ps, current_tile, building_grid)
	var detour_path = ps.get_path_to_tile(current_tile, target) if target != ps.throne_tile else ps.get_path_to_throne(current_tile)
	if detour_path.is_empty():
		return
	var detour_cost = _calculate_path_cost(detour_path)
	var remaining_hp = wall_system.edge_hp.get(attacking_edge_key, 0.0)
	var remaining_time = remaining_hp / maxf(wall_dps, 0.1) + 64.0 / maxf(current_speed, 1.0)
	if brain.should_abandon_wall_attack(detour_cost, remaining_time):
		sprite.modulate = Color.WHITE
		tile_path = detour_path
		path_index = 0
		if tile_path.size() > 1 and tile_path[0] == current_tile:
			path_index = 1
		if path_index < tile_path.size():
			target_tile = tile_path[path_index]
		state = State.MOVING


func _evaluate_throne_accessibility() -> ThroneAccess:
	var ps = get_node_or_null("/root/PathfindingSystem")
	if not ps:
		return ThroneAccess.BLOCKED
	
	# Check if throne is within attack range (Chebyshev distance, consistent with get_path_target)
	var throne_tile = ps.throne_tile
	var dx = absi(current_tile.x - throne_tile.x)
	var dy = absi(current_tile.y - throne_tile.y)
	if maxi(dx, dy) <= brain.get_attack_range():
		return ThroneAccess.ADJACENT
	
	# Check if there's a clear path to throne (no walls blocking)
	var path_to_throne = ps.get_path_to_throne(current_tile)
	if path_to_throne.size() > 1:  # Valid path exists
		return ThroneAccess.CLEAR_PATH
	
	return ThroneAccess.BLOCKED


func _get_throne_building() -> Building:
	var ps = get_node_or_null("/root/PathfindingSystem")
	if not ps or not building_grid:
		return null
		
	var throne_building = building_grid.get_building(ps.throne_tile)
	if throne_building and throne_building is Building:
		return throne_building
	
	return null


func _is_target_building_adjacent(target: Building) -> bool:
	if not building_grid or not is_instance_valid(target):
		return false
	var range = brain.get_attack_range()
	for tile in building_grid.buildings:
		if building_grid.buildings[tile] == target:
			var dx = absi(tile.x - current_tile.x)
			var dy = absi(tile.y - current_tile.y)
			return maxi(dx, dy) <= range
	return false


func _check_adjacent_building() -> Building:
	# Check all 8 adjacent tiles for buildings
	var adjacent_tiles = [
		current_tile + Vector2i(-1, -1), current_tile + Vector2i(0, -1), current_tile + Vector2i(1, -1),
		current_tile + Vector2i(-1,  0),                                  current_tile + Vector2i(1,  0),
		current_tile + Vector2i(-1,  1), current_tile + Vector2i(0,  1), current_tile + Vector2i(1,  1)
	]
	
	if not building_grid:
		return null
		
	for tile in adjacent_tiles:
		var building = building_grid.get_building(tile)
		if building and building is Building:
			return building
	
	return null


var attack_anchor_position: Vector2

func _anchor_for_building_attack(_building: Building) -> void:
	# Враг остаётся на своём текущем тайле — не прыгает к зданию
	if building_grid:
		attack_anchor_position = building_grid.tile_to_world(current_tile) + visual_jitter
	else:
		attack_anchor_position = global_position


func _maintain_attack_anchor() -> void:
	# Keep enemy at stable attack position to prevent bouncing
	if attack_anchor_position != Vector2.ZERO:
		global_position = attack_anchor_position
		global_position = attack_anchor_position


func _stabilize_physics_after_wall_destruction() -> void:
	# CRITICAL: Prevent teleportation bug when walls are destroyed
	
	# Stop all velocity immediately
	pass
	
	# Validate and clamp position to prevent out-of-bounds teleportation
	var current_pos = global_position
	var world_bounds = Rect2(0, 0, 30 * 64, 30 * 64)  # 30x30 grid * 64px cell size
	
	if not world_bounds.has_point(current_pos):
		current_pos = Vector2(
			clampf(current_pos.x, world_bounds.position.x + 32, world_bounds.end.x - 32),
			clampf(current_pos.y, world_bounds.position.y + 32, world_bounds.end.y - 32)
		)
		global_position = current_pos
		global_position = current_pos
		
	# Update current tile to match stabilized position
	if building_grid:
		current_tile = building_grid.world_to_tile(current_pos)
	
	# Reset attack anchor
	attack_anchor_position = Vector2.ZERO


func _start_building_attack(building: Building) -> void:
	attacking_building = building
	state = State.ATTACKING_BUILDING
	attack_timer = 0.0
	var dir_to_building = building.global_position - global_position
	_update_enemy_anim(dir_to_building)
	sprite.modulate = Color(1.5, 1.0, 1.0)  # Red tint while attacking
	
	# PHYSICS FIX: Anchor position to prevent bouncing during attack
	_anchor_for_building_attack(building)


func _process_building_attack(delta: float) -> void:
	if not attacking_building or not is_instance_valid(attacking_building):
		sprite.modulate = Color.WHITE
		attacking_building = null
		state = State.MOVING
		repath()
		return

	_maintain_attack_anchor()
	
	# Check if the specific target building is still adjacent
	if not _is_target_building_adjacent(attacking_building):
		sprite.modulate = Color.WHITE
		attacking_building = null
		state = State.MOVING
		repath()
		return
	
	
	attack_timer += delta
	if attack_timer >= ATTACK_INTERVAL:
		attack_timer -= ATTACK_INTERVAL
		# Урон от шипов — враг получает урон при контакте
		if attacking_building.contact_damage > 0:
			take_damage(attacking_building.contact_damage * ATTACK_INTERVAL)
			if is_dead:
				return
		var damage = wall_dps * ATTACK_INTERVAL
		var proj_type = brain.get_projectile_type()
		if proj_type != "":
			# Дальняя атака: снаряд сам нанесёт урон при попадании
			# Когда здание умрёт — is_instance_valid вернёт false и враг сам перепроложит путь
			Projectile.spawn(get_tree(), proj_type, global_position, attacking_building.global_position, attacking_building).damage = damage
		else:
			attacking_building.take_damage(damage)
			var am = get_node_or_null("/root/AudioManager")
			if am:
				am.play("enemy_hit")
			# Клив: дополнительный урон соседним зданиям вдоль линии
			var cleave_targets = brain.get_cleave_targets(attacking_building, current_tile, building_grid)
			for cleave_target in cleave_targets:
				if is_instance_valid(cleave_target):
					cleave_target.take_damage(damage * 0.6)
			# Проверяем уничтожение только для ближней атаки (снаряд сам обработает попадание)
			if attacking_building.hp <= 0:
				sprite.modulate = Color.WHITE
				attacking_building = null
				state = State.MOVING
				# Ждём фрейм чтобы PathfindingSystem успел обновиться после уничтожения здания
				await get_tree().process_frame
				if not is_dead:
					repath()


func _reached_throne() -> void:
	if is_dead:
		return
		
	is_dead = true
	state = State.DEAD
	
	# Visual effect before dealing damage
	_show_base_attack_effect()
	
	# Wait a bit before applying damage for visual effect
	await get_tree().create_timer(0.3).timeout
	
	GameManager.lose_life(damage_to_base)
	WaveManager.on_enemy_reached_end()
	queue_free()


func _show_base_attack_effect() -> void:
	# Flash red
	sprite.modulate = Color.RED
	var tween = create_tween()
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.3)
	
	# Scale up effect
	tween.parallel().tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.15)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)


func apply_slow(percent: float, duration: float) -> void:
	debuffs["slow"] = {"timer": duration, "value": percent}
	slow_factor = 1.0 - percent
	slow_timer = duration
	current_speed = base_speed * slow_factor
	_ensure_debuff_icon("slow", "res://assets/sprites/ui/debuff_slow.png")


func apply_curse(damage_mult: float, duration: float) -> void:
	debuffs["curse"] = {"timer": duration, "value": damage_mult}
	_ensure_debuff_icon("curse", "res://assets/sprites/ui/debuff_curse.png")


func get_damage_multiplier() -> float:
	if debuffs.has("curse"):
		return 1.0 + debuffs["curse"]["value"]
	return 1.0


func _update_debuffs(delta: float) -> void:
	var to_remove: Array[String] = []
	for key in debuffs:
		debuffs[key]["timer"] -= delta
		if debuffs[key]["timer"] <= 0:
			to_remove.append(key)
	for key in to_remove:
		debuffs.erase(key)
		_remove_debuff_icon(key)
		if key == "slow":
			slow_timer = 0
			slow_factor = 1.0
			current_speed = base_speed


func _ensure_debuff_icon(key: String, icon_path: String) -> void:
	if _debuff_icons.has(key):
		return
	if not ResourceLoader.exists(icon_path):
		return
	var icon = Sprite2D.new()
	icon.texture = load(icon_path)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.scale = Vector2(0.5, 0.5)
	icon.z_index = 10
	# Позиция над головой, смещаем по кол-ву иконок
	var idx = _debuff_icons.size()
	icon.position = Vector2(-10 + idx * 14, -28)
	add_child(icon)
	_debuff_icons[key] = icon


func _remove_debuff_icon(key: String) -> void:
	if _debuff_icons.has(key):
		var icon = _debuff_icons[key]
		if is_instance_valid(icon):
			icon.queue_free()
		_debuff_icons.erase(key)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	if invincible_timer > 0:
		return

	# Применяем множитель от проклятия
	amount *= get_damage_multiplier()

	var was_full_hp = hp >= max_hp
	hp -= amount
	_update_hp_bar()

	# Триггер первого удара — brain может активировать эффекты
	if was_full_hp:
		brain.on_first_hit()

	var tween = create_tween()
	sprite.modulate = Color(2, 2, 2)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	if hp <= 0:
		die()


func activate_invincibility(duration: float) -> void:
	invincible_timer = duration
	_inv_pulse = 0.0


func die() -> void:
	if is_dead:
		return
	is_dead = true
	state = State.DEAD
	GameManager.earn_gold(reward)
	WaveManager.on_enemy_died()

	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(queue_free)


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


## Возвращает случайный оффсет перпендикулярно стене — враги не стакаются
func _get_wall_spread_offset(edge_key: StringName) -> Vector2:
	var parts = str(edge_key).split("-")
	if parts.size() != 2:
		return visual_jitter
	var t1 = parts[0].split(",")
	var t2 = parts[1].split(",")
	if t1.size() != 2 or t2.size() != 2:
		return visual_jitter
	var tile1 = Vector2i(int(t1[0]), int(t1[1]))
	var tile2 = Vector2i(int(t2[0]), int(t2[1]))
	# Направление стены → перпендикуляр = направление разброса
	var wall_dir = Vector2(tile2 - tile1).normalized()
	var perp = Vector2(-wall_dir.y, wall_dir.x)
	return perp * randf_range(-20.0, 20.0)


func _make_edge_key(a: Vector2i, b: Vector2i) -> StringName:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return StringName("%d,%d-%d,%d" % [a.x, a.y, b.x, b.y])
	else:
		return StringName("%d,%d-%d,%d" % [b.x, b.y, a.x, a.y])
