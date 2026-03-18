class_name EnemyBase
extends Node2D

## Grid-based enemy with AStarGrid2D pathfinding and wall attack FSM.

@onready var body: CharacterBody2D = $Body
@onready var sprite: ColorRect = $Body/Sprite
@onready var accent_sprite: ColorRect = $Body/AccentSprite
@onready var hp_bar_bg: ColorRect = $Body/HPBarBG
@onready var hp_bar: ColorRect = $Body/HPBar

var enemy_type: String = "hero_barbarian"
var enemy_data: Dictionary = {}

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

# Grid movement
var building_grid: Node = null
var wall_system: Node = null
var current_tile: Vector2i = Vector2i.ZERO
var target_tile: Vector2i = Vector2i.ZERO
var tile_path: Array[Vector2i] = []
var path_index: int = 0
var move_progress: float = 0.0

# FSM
enum State { MOVING, ATTACKING_WALL, ATTACKING_BUILDING, DEAD }
enum ThroneAccess { BLOCKED, CLEAR_PATH, ADJACENT }
var state: State = State.MOVING
var attacking_edge_key: StringName = &""
var attacking_building: Building = null
var attack_timer: float = 0.0
const ATTACK_INTERVAL: float = 0.5

var _repath_queued: bool = false


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


func _ready() -> void:
	if enemy_data.is_empty():
		enemy_data = EnemyData.ENEMIES[enemy_type]

	sprite.color = enemy_data["color"]
	accent_sprite.color = enemy_data["accent"]

	body.collision_layer = 2
	body.collision_mask = 1  # Collide with walls (layer 1)

	var ps = get_node_or_null("/root/PathfindingSystem")
	if ps:
		ps.path_grid_changed.connect(_on_path_grid_changed)


func _on_path_grid_changed() -> void:
	if is_dead:
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
	print("=== EnemyBase.repath START ===")
	print("current_tile: ", current_tile)
	
	var ps = get_node_or_null("/root/PathfindingSystem")
	print("PathfindingSystem found: ", ps != null)
	if not ps:
		push_error("EnemyBase: PathfindingSystem not found!")
		return

	print("Getting path to throne from: ", current_tile)
	tile_path = ps.get_path_to_throne(current_tile)
	print("Initial path size: ", tile_path.size())
	
	if tile_path.is_empty():
		print("No path with walls, trying path ignoring walls")
		tile_path = ps.get_path_ignoring_walls(current_tile)
		print("Path ignoring walls size: ", tile_path.size())

	path_index = 0
	move_progress = 0.0

	print("EnemyBase repath from=%s path_size=%d bg=%s" % [current_tile, tile_path.size(), building_grid != null])

	if tile_path.is_empty():
		push_warning("EnemyBase: NO PATH from %s to throne!" % current_tile)
		return

	print("Path found: ", tile_path)
	
	# Debug: Check if path goes through the entrance
	var entrance_tile = Vector2i(17, 15)  # Should be the entrance at (17,15)
	if entrance_tile in tile_path:
		print("✓ Path goes through entrance at %s" % entrance_tile)
	else:
		print("✗ Path does NOT go through entrance at %s" % entrance_tile)
		print("  Path tiles near entrance: ")
		for tile in tile_path:
			if tile.distance_to(entrance_tile) <= 2:
				print("    %s (distance: %.1f)" % [tile, tile.distance_to(entrance_tile)])

	# Skip current tile if it's first in path
	if tile_path[0] == current_tile and tile_path.size() > 1:
		path_index = 1
		print("Skipping current tile in path, path_index now: ", path_index)

	if path_index < tile_path.size():
		target_tile = tile_path[path_index]
		print("Set target_tile: ", target_tile)
		_check_wall_ahead()
	
	state = State.MOVING
	print("State set to MOVING")
	print("=== EnemyBase.repath END ===")


func _check_wall_ahead() -> void:
	# PHYSICS SEPARATION: Wall checking is now handled in _process_movement
	# This function only maintains tile-based pathfinding logic
	print("Enemy %s: Moving from %s to %s" % [self, current_tile, target_tile])


func _process(delta: float) -> void:
	if is_dead:
		return

	# Slow effect
	if slow_timer > 0:
		slow_timer -= delta
		current_speed = base_speed * slow_factor
		sprite.modulate = Color(0.6, 0.6, 1.0)
	else:
		current_speed = base_speed
		sprite.modulate = Color.WHITE

	# Debug state info (every 1 second)
	if fmod(Time.get_ticks_msec(), 1000) < 16:  # ~60fps = 16ms frames
		print("Enemy %s: State=%s, Pos=%s, Target=%s" % [self, State.keys()[state], current_tile, target_tile])

	match state:
		State.MOVING:
			_process_movement(delta)
		State.ATTACKING_WALL:
			_process_wall_attack(delta)
		State.ATTACKING_BUILDING:
			_process_building_attack(delta)


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
	
	# PHYSICS SEPARATION: Only use CharacterBody2D for wall collision detection
	# Set target position first
	var desired_movement = target_pos - body.global_position
	body.velocity = desired_movement.normalized() * current_speed
	
	# Test for wall collision using move_and_slide
	var original_position = body.global_position
	body.global_position = original_position  # Reset position
	body.velocity = desired_movement.normalized() * current_speed
	body.move_and_slide()
	
	var collision_detected = body.get_slide_collision_count() > 0
	if collision_detected:
		print("Enemy %s: Wall collision detected at %s -> %s" % [self, current_tile, target_tile])
		# Reset body position after collision test
		body.global_position = original_position
	
	if collision_detected:
		# WALL HIT: Switch to attacking nearest wall
		var closest_wall = _find_nearest_wall_edge()
		if closest_wall != "":
			attacking_edge_key = closest_wall
			state = State.ATTACKING_WALL
			attack_timer = 0.0
			print("Enemy %s: Attacking wall %s" % [self, attacking_edge_key])
		else:
			# No wall found, try alternate pathfinding
			print("Enemy %s: No wall found for collision, repathing" % self)
			repath()
		return
	
	# NO COLLISION: Update positions normally
	global_position = target_pos
	body.global_position = target_pos

	if move_progress >= 1.0:
		current_tile = target_tile
		path_index += 1
		move_progress = 0.0

		# Update tower targeting progress
		if tile_path.size() > 0:
			path_progress = float(path_index) / float(tile_path.size())

		# Check if adjacent to any building (including throne)
		var adjacent_building = _check_adjacent_building()
		if adjacent_building:
			_start_building_attack(adjacent_building)
			return

		if path_index < tile_path.size():
			target_tile = tile_path[path_index]
			_check_wall_ahead()
		else:
			# Path exhausted - now check throne accessibility with priority system
			print("Enemy %s: Path exhausted at tile %s, evaluating throne accessibility" % [self, current_tile])
			
			var throne_priority = _evaluate_throne_accessibility()
			if throne_priority == ThroneAccess.ADJACENT:
				# Throne is adjacent - highest priority
				var throne = _get_throne_building()
				if throne:
					print("Enemy %s: Throne adjacent! Starting throne attack" % self)
					_start_building_attack(throne)
					return
			elif throne_priority == ThroneAccess.CLEAR_PATH:
				# Clear path to throne - repath directly
				print("Enemy %s: Clear path to throne available, repathing" % self)
				repath()
				return
			
			# No throne access - check for other adjacent buildings to attack
			var building_at_path_end = _check_adjacent_building()
			if building_at_path_end:
				print("Enemy %s: Found adjacent building at path end: %s" % [self, building_at_path_end])
				_start_building_attack(building_at_path_end)
				return
			
			# No adjacent buildings - repath and try again
			print("Enemy %s: No adjacent targets, repathing from %s" % [self, current_tile])
			repath()


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
		print("Enemy %s: No wall_system, back to moving" % self)
		state = State.MOVING
		return

	# Check if wall still exists (might have been destroyed by another enemy)
	if not wall_system.edges.has(attacking_edge_key):
		print("Enemy %s: Wall destroyed, back to moving" % self)
		sprite.modulate = Color.WHITE  # Remove attack tint
		state = State.MOVING
		repath()
		return

	print("Enemy %s: Attacking wall %s (HP: %s)" % [self, attacking_edge_key, wall_system.edge_hp.get(attacking_edge_key, 0)])
	
	# Visual effect while attacking
	sprite.modulate = Color(1.5, 1.0, 1.0)  # Slight red tint while attacking
	
	attack_timer += delta
	if attack_timer >= ATTACK_INTERVAL:
		attack_timer -= ATTACK_INTERVAL
		var destroyed = wall_system.damage_wall_edge(attacking_edge_key, wall_dps * ATTACK_INTERVAL)
		var remaining_hp = wall_system.edge_hp.get(attacking_edge_key, 0)
		print("Enemy %s: Dealt %.1f damage to wall %s. Remaining HP: %.1f, Destroyed: %s" % [self, wall_dps * ATTACK_INTERVAL, attacking_edge_key, remaining_hp, destroyed])
		
		if destroyed:
			print("Enemy %s: Wall destroyed! Switching back to movement" % self)
			sprite.modulate = Color.WHITE  # Remove attack tint
			
			# PHYSICS FIX: Stabilize position and velocity to prevent teleportation
			_stabilize_physics_after_wall_destruction()
			
			state = State.MOVING
			# Give PathfindingSystem a moment to update after wall destruction
			await get_tree().process_frame
			
			# Simple transition: go back to movement and repath
			print("Enemy %s: Wall destroyed, repathing to find new route" % self)
			repath()


func _evaluate_throne_accessibility() -> ThroneAccess:
	var ps = get_node_or_null("/root/PathfindingSystem")
	if not ps:
		return ThroneAccess.BLOCKED
	
	# Check if throne is adjacent (highest priority) 
	var throne_tile = ps.throne_tile
	var distance = current_tile.distance_to(throne_tile)
	if distance <= 1.5:  # Adjacent (including diagonal)
		print("Enemy %s: Throne ADJACENT at distance %.1f" % [self, distance])
		return ThroneAccess.ADJACENT
	
	# Check if there's a clear path to throne (no walls blocking)
	var path_to_throne = ps.get_path_to_throne(current_tile)
	if path_to_throne.size() > 1:  # Valid path exists
		print("Enemy %s: CLEAR_PATH to throne found (%d steps)" % [self, path_to_throne.size()])
		return ThroneAccess.CLEAR_PATH
	
	print("Enemy %s: Throne BLOCKED - no valid path" % self)
	return ThroneAccess.BLOCKED


func _get_throne_building() -> Building:
	var ps = get_node_or_null("/root/PathfindingSystem")
	if not ps or not building_grid:
		return null
		
	var throne_building = building_grid.get_building(ps.throne_tile)
	if throne_building and throne_building is Building:
		print("Enemy %s: Found throne building at %s" % [self, ps.throne_tile])
		return throne_building
	
	print("Enemy %s: No throne building found at %s" % [self, ps.throne_tile])
	return null


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

func _anchor_for_building_attack(building: Building) -> void:
	# Set stable attack position near the building, with collision padding
	var building_pos = building.global_position
	var offset = (global_position - building_pos).normalized() * 32.0  # 32px distance
	attack_anchor_position = building_pos + offset


func _maintain_attack_anchor() -> void:
	# Keep enemy at stable attack position to prevent bouncing
	if attack_anchor_position != Vector2.ZERO:
		body.global_position = attack_anchor_position
		global_position = attack_anchor_position


func _stabilize_physics_after_wall_destruction() -> void:
	# CRITICAL: Prevent teleportation bug when walls are destroyed
	print("Enemy %s: Stabilizing physics after wall destruction at position %s" % [self, body.global_position])
	
	# Stop all velocity immediately
	body.velocity = Vector2.ZERO
	
	# Validate and clamp position to prevent out-of-bounds teleportation
	var current_pos = body.global_position
	var world_bounds = Rect2(0, 0, 30 * 64, 30 * 64)  # 30x30 grid * 64px cell size
	
	if not world_bounds.has_point(current_pos):
		print("Enemy %s: Position out of bounds! Clamping from %s" % [self, current_pos])
		current_pos = Vector2(
			clampf(current_pos.x, world_bounds.position.x + 32, world_bounds.end.x - 32),
			clampf(current_pos.y, world_bounds.position.y + 32, world_bounds.end.y - 32)
		)
		body.global_position = current_pos
		global_position = current_pos
		
	# Update current tile to match stabilized position
	if building_grid:
		current_tile = building_grid.world_to_tile(current_pos)
		print("Enemy %s: Stabilized at tile %s, world pos %s" % [self, current_tile, current_pos])
	
	# Reset attack anchor
	attack_anchor_position = Vector2.ZERO


func _start_building_attack(building: Building) -> void:
	print("Enemy %s: Starting attack on building %s" % [self, building])
	attacking_building = building
	state = State.ATTACKING_BUILDING
	attack_timer = 0.0
	sprite.modulate = Color(1.5, 1.0, 1.0)  # Red tint while attacking
	
	# PHYSICS FIX: Anchor position to prevent bouncing during attack
	_anchor_for_building_attack(building)


func _process_building_attack(delta: float) -> void:
	if not attacking_building or not is_instance_valid(attacking_building):
		print("Enemy %s: Building destroyed or invalid, back to moving" % self)
		sprite.modulate = Color.WHITE
		attacking_building = null
		body.velocity = Vector2.ZERO  # Stop movement to prevent physics issues
		state = State.MOVING
		repath()
		return
	
	# PHYSICS FIX: Maintain stable attack position, disable collision physics during attack
	body.velocity = Vector2.ZERO  # Prevent bouncing from collisions
	_maintain_attack_anchor()
	
	# Check if building is still adjacent
	var current_adjacent = _check_adjacent_building()
	if current_adjacent != attacking_building:
		print("Enemy %s: No longer adjacent to building, back to moving" % self)
		sprite.modulate = Color.WHITE
		attacking_building = null
		state = State.MOVING
		repath()
		return
	
	print("Enemy %s: Attacking building %s (HP: %.1f)" % [self, attacking_building, attacking_building.hp])
	
	attack_timer += delta
	if attack_timer >= ATTACK_INTERVAL:
		attack_timer -= ATTACK_INTERVAL
		var damage = wall_dps * ATTACK_INTERVAL
		attacking_building.take_damage(damage)
		print("Enemy %s: Dealt %.1f damage to building. Remaining HP: %.1f" % [self, damage, attacking_building.hp])
		
		# Check if building was destroyed
		if attacking_building.hp <= 0:
			print("Enemy %s: Building destroyed!" % self)
			sprite.modulate = Color.WHITE
			attacking_building = null
			body.velocity = Vector2.ZERO
			state = State.MOVING
			repath()


func _reached_throne() -> void:
	if is_dead:
		return
		
	print("Enemy %s: Reached throne! Dealing %d damage" % [self, damage_to_base])
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


func take_damage(amount: float) -> void:
	if is_dead:
		return

	hp -= amount
	_update_hp_bar()

	var tween = create_tween()
	sprite.modulate = Color(2, 2, 2)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	if hp <= 0:
		die()


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	slow_timer = duration


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


func _make_edge_key(a: Vector2i, b: Vector2i) -> StringName:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return StringName("%d,%d-%d,%d" % [a.x, a.y, b.x, b.y])
	else:
		return StringName("%d,%d-%d,%d" % [b.x, b.y, a.x, a.y])
