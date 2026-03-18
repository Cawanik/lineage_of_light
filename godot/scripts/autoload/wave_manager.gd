extends Node

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_waves_completed
signal enemy_spawned(enemy: Node)

var current_wave: int = 0
var total_waves: int = 15
var enemies_alive: int = 0
var is_spawning: bool = false

var enemy_scene: PackedScene

# Wave definitions: array of {enemy_type, count, spawn_delay}
var wave_defs: Array = []

# AI-selected spawn sides for current wave
var _current_spawn_sides: Array = []
var _spawn_side_index: int = 0


func _ready() -> void:
	enemy_scene = load("res://scenes/enemies/enemy_base.tscn")
	if not enemy_scene:
		push_error("WaveManager: Failed to load enemy scene!")
	_generate_waves()


func _generate_waves() -> void:
	# Epoch I: Barbarians (waves 1-3)
	wave_defs.append([{"type": "hero_barbarian", "count": 5, "delay": 1.2}])
	wave_defs.append([{"type": "hero_barbarian", "count": 8, "delay": 1.0}])
	wave_defs.append([{"type": "hero_barbarian", "count": 12, "delay": 0.8}])

	# Epoch II: Knights join (waves 4-6)
	wave_defs.append([
		{"type": "hero_barbarian", "count": 6, "delay": 1.0},
		{"type": "hero_knight", "count": 3, "delay": 1.5},
	])
	wave_defs.append([
		{"type": "hero_knight", "count": 6, "delay": 1.2},
		{"type": "hero_barbarian", "count": 4, "delay": 0.8},
	])
	wave_defs.append([{"type": "hero_knight", "count": 10, "delay": 1.0}])

	# Epoch III: Mages join (waves 7-9)
	wave_defs.append([
		{"type": "hero_knight", "count": 5, "delay": 1.0},
		{"type": "hero_mage", "count": 3, "delay": 1.5},
	])
	wave_defs.append([
		{"type": "hero_mage", "count": 6, "delay": 1.2},
		{"type": "hero_barbarian", "count": 8, "delay": 0.6},
	])
	wave_defs.append([
		{"type": "hero_mage", "count": 8, "delay": 1.0},
		{"type": "hero_knight", "count": 4, "delay": 1.2},
	])

	# Epoch IV: Alchemists join (waves 10-12)
	wave_defs.append([
		{"type": "hero_alchemist", "count": 5, "delay": 1.0},
		{"type": "hero_mage", "count": 3, "delay": 1.5},
	])
	wave_defs.append([
		{"type": "hero_alchemist", "count": 8, "delay": 0.8},
		{"type": "hero_knight", "count": 6, "delay": 1.0},
	])
	wave_defs.append([
		{"type": "hero_alchemist", "count": 10, "delay": 0.7},
		{"type": "hero_mage", "count": 5, "delay": 1.2},
	])

	# Epoch V: Heirs - final waves (13-15)
	wave_defs.append([
		{"type": "hero_heir", "count": 3, "delay": 2.0},
		{"type": "hero_knight", "count": 8, "delay": 0.8},
	])
	wave_defs.append([
		{"type": "hero_heir", "count": 5, "delay": 1.5},
		{"type": "hero_mage", "count": 6, "delay": 1.0},
		{"type": "hero_alchemist", "count": 4, "delay": 0.8},
	])
	wave_defs.append([
		{"type": "hero_heir", "count": 8, "delay": 1.2},
		{"type": "hero_mage", "count": 8, "delay": 0.8},
		{"type": "hero_knight", "count": 8, "delay": 0.6},
	])

	total_waves = wave_defs.size()


func start_next_wave() -> void:
	print("=== WaveManager.start_next_wave START ===")
	print("is_spawning: ", is_spawning)
	print("current_wave: ", current_wave)
	print("total_waves: ", total_waves)
	
	if is_spawning:
		print("Already spawning, returning")
		return
	if current_wave >= total_waves:
		print("All waves completed")
		all_waves_completed.emit()
		return

	current_wave += 1
	print("Starting wave: ", current_wave)
	
	# Update epoch based on wave
	if current_wave <= 3:
		GameManager.current_epoch = 1
	elif current_wave <= 6:
		GameManager.current_epoch = 2
	elif current_wave <= 9:
		GameManager.current_epoch = 3
	elif current_wave <= 12:
		GameManager.current_epoch = 4
	else:
		GameManager.current_epoch = 5
	
	print("Epoch: ", GameManager.current_epoch)

	# AI selects spawn direction
	var ps = get_node_or_null("/root/PathfindingSystem")
	print("PathfindingSystem found: ", ps != null)
	if ps:
		_current_spawn_sides = WaveAI.select_spawn_sides_weighted(ps)
	else:
		_current_spawn_sides = [SpawnZone.Side.NORTH]
	_spawn_side_index = 0
	print("Spawn sides selected: ", _current_spawn_sides)

	wave_started.emit(current_wave)
	is_spawning = true
	
	var wave_def = wave_defs[current_wave - 1]
	print("Wave definition: ", wave_def)
	_spawn_wave(wave_def)
	print("=== WaveManager.start_next_wave END ===")


func _spawn_wave(groups: Array) -> void:
	print("=== WaveManager._spawn_wave START ===")
	print("Groups: ", groups)
	
	var spawn_queue: Array = []
	for group in groups:
		print("Processing group: ", group)
		for i in range(group["count"]):
			spawn_queue.append({"type": group["type"], "delay": group["delay"]})

	spawn_queue.shuffle()
	print("Spawn queue size: ", spawn_queue.size())
	print("Spawn queue: ", spawn_queue)

	for i in range(spawn_queue.size()):
		if not GameManager.is_game_active:
			print("Game not active, breaking spawn loop")
			break
		
		print("Spawning enemy %d/%d: %s" % [i+1, spawn_queue.size(), spawn_queue[i]["type"]])
		spawn_test_enemy(spawn_queue[i]["type"])
		
		if i < spawn_queue.size() - 1:
			var delay = spawn_queue[i]["delay"]
			print("Waiting %f seconds before next spawn" % delay)
			await get_tree().create_timer(delay).timeout

	is_spawning = false
	print("=== WaveManager._spawn_wave END ===")


func spawn_test_enemy(enemy_type: String) -> void:
	print("=== WaveManager._spawn_enemy START ===")
	print("GameManager.is_game_active: ", GameManager.is_game_active)
	
	if not GameManager.is_game_active:
		print("Game not active, aborting spawn")
		return

	if enemy_scene == null:
		push_error("WaveManager: enemy_scene is null! Check enemy_base.tscn")
		return

	print("Creating enemy of type: ", enemy_type)
	var enemy = enemy_scene.instantiate()
	if enemy == null:
		push_error("WaveManager: Failed to instantiate enemy scene!")
		return
	
	enemy.setup(enemy_type)
	enemies_alive += 1
	print("Enemies alive: ", enemies_alive)

	# Pick spawn tile from AI-selected side (alternate sides if multiple)
	var side = _current_spawn_sides[_spawn_side_index % _current_spawn_sides.size()]
	_spawn_side_index += 1
	var spawn_tile = SpawnZone.pick_spawn_tile(side)
	print("Spawn side: %d, tile: %s" % [side, spawn_tile])

	# Find BuildingGrid and WallSystem in main scene
	var main = get_tree().current_scene
	print("Main scene: ", main)
	print("Main scene name: ", main.name if main else "null")
	
	# Print all children of main scene for debugging
	if main:
		print("Main scene children:")
		for child in main.get_children():
			print("  - ", child.name, " (", child.get_class(), ")")
	
	var ysort = main.get_node_or_null("YSort") if main else null
	var building_grid = main.get_node_or_null("YSort/BuildingGrid") if main else null
	var wall_system = main.get_node_or_null("YSort/WallSystem") if main else null

	# Try alternative paths if primary paths fail
	if not building_grid and ysort:
		print("Trying to find BuildingGrid in YSort children...")
		for child in ysort.get_children():
			if child.name == "BuildingGrid":
				building_grid = child
				print("Found BuildingGrid as child: ", child)
				break
	
	if not wall_system and ysort:
		print("Trying to find WallSystem in YSort children...")
		for child in ysort.get_children():
			if child.name == "WallSystem":
				wall_system = child
				print("Found WallSystem as child: ", child)
				break

	print("Found nodes - YSort: %s, BuildingGrid: %s, WallSystem: %s" % [ysort != null, building_grid != null, wall_system != null])
	
	if ysort:
		print("YSort children:")
		for child in ysort.get_children():
			print("  - ", child.name, " (", child.get_class(), ")")

	enemy.building_grid = building_grid
	enemy.wall_system = wall_system
	enemy.current_tile = spawn_tile

	var world_pos = Vector2.ZERO
	if building_grid:
		world_pos = building_grid.tile_to_world(spawn_tile)
		print("World position from building_grid: ", world_pos)
	else:
		# Fallback calculation
		world_pos = Vector2(spawn_tile.x * 64, spawn_tile.y * 64)
		print("Fallback world position: ", world_pos)
	
	enemy.global_position = world_pos

	# Add to YSort for proper depth ordering
	var parent_node = null
	if ysort:
		parent_node = ysort
		ysort.add_child(enemy)
		print("Added enemy to YSort")
	elif main:
		parent_node = main
		main.add_child(enemy)
		print("Added enemy to main scene")
	else:
		push_error("No parent node found for enemy!")
		return

	print("Enemy added to parent: ", parent_node.name if parent_node else "null")
	print("Enemy global_position after adding: ", enemy.global_position)
	print("Enemy in tree: ", enemy.is_inside_tree())
	
	# Add a visual debug marker
	_add_debug_marker(enemy.global_position, "SPAWN")

	enemy.repath()
	enemy_spawned.emit(enemy)
	print("=== WaveManager._spawn_enemy END ===")


func _add_debug_marker(pos: Vector2, text: String) -> void:
	var main = get_tree().current_scene
	if not main:
		return
	
	var marker = ColorRect.new()
	marker.size = Vector2(20, 20)
	marker.color = Color.RED
	marker.global_position = pos - Vector2(10, 10)
	
	var label = Label.new()
	label.text = text
	label.position = Vector2(25, 0)
	label.modulate = Color.YELLOW
	marker.add_child(label)
	
	main.add_child(marker)
	
	# Auto-remove after 5 seconds
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func(): if is_instance_valid(marker): marker.queue_free())


func on_enemy_died() -> void:
	enemies_alive -= 1
	_check_wave_complete()


func on_enemy_reached_end() -> void:
	enemies_alive -= 1
	_check_wave_complete()


func _check_wave_complete() -> void:
	if enemies_alive <= 0 and not is_spawning:
		wave_completed.emit(current_wave)
		if current_wave >= total_waves:
			all_waves_completed.emit()
