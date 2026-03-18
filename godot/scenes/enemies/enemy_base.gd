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
enum State { MOVING, ATTACKING_WALL, DEAD }
var state: State = State.MOVING
var attacking_edge_key: StringName = &""
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
	if not wall_system:
		print("Enemy %s: No wall_system!" % self)
		return
	
	var key = _make_edge_key(current_tile, target_tile)
	print("Enemy %s: Checking wall from %s to %s, key=%s" % [self, current_tile, target_tile, key])
	print("  Wall exists: %s" % wall_system.edges.has(key))
	print("  Total edges in wall_system: %d" % wall_system.edges.size())
	
	if wall_system.edges.has(key):
		print("Enemy %s: Found wall! Switching to ATTACKING_WALL state" % self)
		state = State.ATTACKING_WALL
		attacking_edge_key = key
		attack_timer = 0.0
	else:
		print("Enemy %s: No wall found, continuing movement" % self)


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


func _process_movement(delta: float) -> void:
	if tile_path.is_empty() or path_index >= tile_path.size():
		return

	if not building_grid:
		return

	var from_world = building_grid.tile_to_world(current_tile)
	var to_world = building_grid.tile_to_world(target_tile)
	var tile_distance = from_world.distance_to(to_world)

	if tile_distance < 0.1:
		move_progress = 1.0
	else:
		move_progress += (current_speed * delta) / tile_distance

	var target_pos = from_world.lerp(to_world, clampf(move_progress, 0.0, 1.0))
	
	# Use CharacterBody2D physics for collision with walls
	body.velocity = (target_pos - body.global_position) * current_speed * 2.0
	body.move_and_slide()
	
	# Check if we hit a wall (collision detected)
	if body.get_slide_collision_count() > 0:
		print("Enemy %s: Hit wall! Position: %s, Target: %s" % [self, current_tile, target_tile])
		
		# Check if there's a clear path to the entrance (17,15) - the intended way in
		var ps = get_node_or_null("/root/PathfindingSystem")
		var entrance_tile = Vector2i(17, 15)
		var path_to_entrance = []
		
		if ps:
			path_to_entrance = ps.get_path_to_throne(current_tile)
			
		# If we can reach entrance, continue moving (collision might be temporary)
		if path_to_entrance.size() > 1 and entrance_tile in path_to_entrance:
			print("Enemy %s: Path to entrance exists, trying to move around collision" % self)
			# Try to move slightly in a different direction to get unstuck
			var collision = body.get_slide_collision(0)
			if collision:
				# Move perpendicular to collision normal
				var perpendicular = collision.get_normal().rotated(PI/2) * current_speed * 0.5
				body.velocity = perpendicular
				body.move_and_slide()
			global_position = body.global_position
			return
		
		# No path to entrance - attack the wall blocking our way
		print("Enemy %s: No path to entrance, attacking wall!" % self)
		
		# Find the actual wall edge we're colliding with
		var collision = body.get_slide_collision(0)
		if collision and wall_system:
			# Find closest wall edge to our position
			var closest_key = ""
			var closest_distance = 999999.0
			
			for edge_key in wall_system.edges.keys():
				# Parse edge key to get tile positions
				var parts = edge_key.split("-")
				if parts.size() == 2:
					var tile1_parts = parts[0].split(",")
					var tile2_parts = parts[1].split(",")
					if tile1_parts.size() == 2 and tile2_parts.size() == 2:
						var tile1 = Vector2i(int(tile1_parts[0]), int(tile1_parts[1]))
						var tile2 = Vector2i(int(tile2_parts[0]), int(tile2_parts[1]))
						var edge_center = (tile1 + tile2) * 0.5
						var distance = current_tile.distance_to(edge_center)
						if distance < closest_distance:
							closest_distance = distance
							closest_key = edge_key
			
			if closest_key != "":
				attacking_edge_key = closest_key
				print("Enemy %s: Found closest wall edge: %s (distance: %.1f)" % [self, attacking_edge_key, closest_distance])
			else:
				attacking_edge_key = _make_edge_key(current_tile, target_tile)
				print("Enemy %s: Using fallback edge key: %s" % [self, attacking_edge_key])
		else:
			attacking_edge_key = _make_edge_key(current_tile, target_tile)
			
		state = State.ATTACKING_WALL
		attack_timer = 0.0
		
		# Update Node2D position to match body
		global_position = body.global_position
		return
	
	# Update Node2D position to match body
	global_position = body.global_position

	if move_progress >= 1.0:
		current_tile = target_tile
		path_index += 1
		move_progress = 0.0

		# Update tower targeting progress
		if tile_path.size() > 0:
			path_progress = float(path_index) / float(tile_path.size())

		# Check if reached throne
		var ps = get_node_or_null("/root/PathfindingSystem")
		if ps and current_tile == ps.throne_tile:
			_reached_throne()
			return

		if path_index < tile_path.size():
			target_tile = tile_path[path_index]
			_check_wall_ahead()
		else:
			# Path exhausted without reaching throne — repath
			repath()


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
			print("Enemy %s: Wall destroyed! Path should now be clear to throne" % self)
			sprite.modulate = Color.WHITE  # Remove attack tint
			state = State.MOVING
			# Give PathfindingSystem a moment to update after wall destruction
			await get_tree().process_frame
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
