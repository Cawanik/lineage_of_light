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


func _ready() -> void:
	enemy_scene = load("res://scenes/enemies/enemy_base.tscn")
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
	if is_spawning:
		return
	if current_wave >= total_waves:
		all_waves_completed.emit()
		return

	current_wave += 1
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

	wave_started.emit(current_wave)
	is_spawning = true
	_spawn_wave(wave_defs[current_wave - 1])


func _spawn_wave(groups: Array) -> void:
	# Build a flat list of enemies to spawn with delays
	var spawn_queue: Array = []
	for group in groups:
		for i in range(group["count"]):
			spawn_queue.append({"type": group["type"], "delay": group["delay"]})

	# Shuffle slightly for variety
	spawn_queue.shuffle()

	for entry in spawn_queue:
		if not GameManager.is_game_active:
			break
		await get_tree().create_timer(entry["delay"]).timeout
		_spawn_enemy(entry["type"])

	is_spawning = false


func _spawn_enemy(enemy_type: String) -> void:
	if not GameManager.is_game_active:
		return

	var enemy = enemy_scene.instantiate()
	enemy.setup(enemy_type)
	enemies_alive += 1
	enemy_spawned.emit(enemy)

	# The main scene will add it to the path
	var main = get_tree().current_scene
	if main and main.has_method("add_enemy"):
		main.add_enemy(enemy)


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
