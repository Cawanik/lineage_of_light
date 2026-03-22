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
	_load_waves()


func _load_waves() -> void:
	for wave_data in Config.waves:
		wave_defs.append(wave_data.get("groups", []))
	total_waves = wave_defs.size()


func start_next_wave() -> void:
	
	if is_spawning:
		return
	if current_wave >= total_waves:
		all_waves_completed.emit()
		return

	current_wave += 1

	# Эпоха берётся из waves.json
	if current_wave - 1 < Config.waves.size():
		GameManager.current_epoch = Config.waves[current_wave - 1].get("epoch", 1)
	

	# AI selects spawn direction
	var ps = get_node_or_null("/root/PathfindingSystem")
	if ps:
		_current_spawn_sides = WaveAI.select_spawn_sides_weighted(ps)
	else:
		_current_spawn_sides = [SpawnZone.Side.NORTH]
	_spawn_side_index = 0

	wave_started.emit(current_wave)
	is_spawning = true
	
	var wave_def = wave_defs[current_wave - 1]
	_spawn_wave(wave_def)


func _spawn_wave(groups: Array) -> void:
	
	var spawn_queue: Array = []
	for group in groups:
		for i in range(group["count"]):
			spawn_queue.append({"type": group["type"], "delay": group["delay"]})

	spawn_queue.shuffle()

	for i in range(spawn_queue.size()):
		if not GameManager.is_game_active:
			break
		
		spawn_test_enemy(spawn_queue[i]["type"])
		
		if i < spawn_queue.size() - 1:
			var delay = spawn_queue[i]["delay"]
			await get_tree().create_timer(delay).timeout

	is_spawning = false


func spawn_test_enemy(enemy_type: String) -> void:
	
	if not GameManager.is_game_active:
		return

	if enemy_scene == null:
		push_error("WaveManager: enemy_scene is null! Check enemy_base.tscn")
		return

	var enemy = enemy_scene.instantiate()
	if enemy == null:
		push_error("WaveManager: Failed to instantiate enemy scene!")
		return
	
	enemy.setup(enemy_type)
	enemies_alive += 1

	# Pick spawn tile from AI-selected side (alternate sides if multiple)
	var side = _current_spawn_sides[_spawn_side_index % _current_spawn_sides.size()]
	_spawn_side_index += 1
	var spawn_tile = SpawnZone.pick_spawn_tile(side)

	# Find BuildingGrid and WallSystem in main scene
	var main = get_tree().current_scene
	
	var ysort = main.get_node_or_null("YSort") if main else null
	var building_grid = main.get_node_or_null("YSort/BuildingGrid") if main else null
	var wall_system = main.get_node_or_null("YSort/WallSystem") if main else null

	# Try alternative paths if primary paths fail
	if not building_grid and ysort:
		for child in ysort.get_children():
			if child.name == "BuildingGrid":
				building_grid = child
				break
	
	if not wall_system and ysort:
		for child in ysort.get_children():
			if child.name == "WallSystem":
				wall_system = child
				break

	enemy.building_grid = building_grid
	enemy.wall_system = wall_system
	enemy.current_tile = spawn_tile

	var world_pos = Vector2.ZERO
	if building_grid:
		world_pos = building_grid.tile_to_world(spawn_tile)
	else:
		# Fallback calculation
		world_pos = Vector2(spawn_tile.x * 64, spawn_tile.y * 64)
	
	enemy.global_position = world_pos

	# Add to YSort for proper depth ordering
	var parent_node = null
	if ysort:
		parent_node = ysort
		ysort.add_child(enemy)
	elif main:
		parent_node = main
		main.add_child(enemy)
	else:
		push_error("No parent node found for enemy!")
		return

	
	enemy.repath()
	enemy_spawned.emit(enemy)


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
