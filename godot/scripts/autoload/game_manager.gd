# ==========================================
# game_manager.gd — Глобальный менеджер игры, autoload
# ==========================================
# _ready() — заглушка, ни хуя не делает пока
# can_afford(cost) — проверяет, хватает ли бабла
# spend_gold(amount) — тратит золото, возвращает true если хватило
# earn_gold(amount) — начисляет золотишко
# lose_life(amount) — отнимает жизни, если дошло до нуля — game_over нахуй
# world_to_grid(world_pos) — конвертит мировые координаты в сетку
# grid_to_world(grid_pos) — конвертит сетку обратно в мировые координаты
# is_cell_free(grid_pos) — проверяет, свободна ли ячейка
# occupy_cell(grid_pos, tower) — занимает ячейку башней
# free_cell(grid_pos) — освобождает ячейку, сука
# reset_game() — сбрасывает всё к хуям, начинает заново
# ==========================================

extends Node

signal gold_changed(new_amount: int)
signal lives_changed(new_amount: int)
signal game_over
signal game_won
signal souls_changed(new_amount: int)

var gold: int = 350:
	set(value):
		gold = value
		gold_changed.emit(gold)

var lives: int = 20:
	set(value):
		lives = max(0, value)
		lives_changed.emit(lives)
		if lives <= 0:
			game_over.emit()

var souls: int = 0:
	set(value):
		souls = value
		souls_changed.emit(souls)

var current_epoch: int = 1
var is_game_active: bool = true
var current_save_slot: int = 0
var current_map: String = "island"
var skip_tutorial: bool = false
var tutorial_wave: bool = false
var tutorial_completed: bool = false
var first_death_dialogue: bool = false  # Показали ли диалог первой смерти
var toolbar_keybinds: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]

# Grid-based tower placement
const GRID_SIZE = 32
var occupied_cells: Dictionary = {}  # Vector2i -> tower_ref


func _ready() -> void:
	_load_settings()


func _load_settings() -> void:
	var path = "user://settings.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	# Бинды
	var binds = data.get("toolbar_keybinds", [])
	if binds.size() == 9:
		for i in range(9):
			toolbar_keybinds[i] = int(binds[i])
	# Звук (AudioManager может быть ещё не готов, defer)
	call_deferred("_apply_audio_settings", data)


func _apply_audio_settings(data: Dictionary) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.set_master_volume(data.get("master_volume", 1.0))
		am.set_music_volume(data.get("music_volume", 0.5))
		am.set_sfx_volume(data.get("sfx_volume", 0.1))


func can_afford(cost: int) -> bool:
	return gold >= cost


func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false


func earn_gold(amount: int) -> void:
	var multiplier = get_gold_multiplier()
	gold += int(amount * multiplier)


# Считаем множитель золота от алтарей
func get_gold_multiplier() -> float:
	var altar_count = _count_buildings("altar_of_greed")
	if altar_count <= 0:
		return 1.0
	var mult = 1.0
	for i in range(altar_count):
		mult *= 1.5
	return mult


# Считаем бонус душ от шпилей
func get_soul_bonus() -> int:
	return _count_buildings("crystal_spire")


# Считаем сколько зданий определённого типа на карте
func _count_buildings(type: String) -> int:
	var bg = get_tree().current_scene.get_node_or_null("YSort/BuildingGrid") as BuildingGrid
	if not bg:
		return 0
	var count = 0
	for tile in bg.buildings:
		var b = bg.get_building(tile)
		if b and b is Building and b.building_type == type:
			count += 1
	return count


func lose_life(amount: int = 1) -> void:
	lives -= amount


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / GRID_SIZE),
		floori(world_pos.y / GRID_SIZE)
	)


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * GRID_SIZE + GRID_SIZE / 2.0,
		grid_pos.y * GRID_SIZE + GRID_SIZE / 2.0
	)


func is_cell_free(grid_pos: Vector2i) -> bool:
	return not occupied_cells.has(grid_pos)


func occupy_cell(grid_pos: Vector2i, tower: Node) -> void:
	occupied_cells[grid_pos] = tower


func free_cell(grid_pos: Vector2i) -> void:
	occupied_cells.erase(grid_pos)


func on_throne_destroyed() -> void:
	print("GameManager: Throne destroyed! Game Over!")
	is_game_active = false
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play("game_over")
		am.stop_music(2.0)

	# Clear pathfinding system
	var ps = get_node_or_null("/root/PathfindingSystem")
	if ps and ps.has_method("clear_throne"):
		ps.clear_throne()

	# Враги становятся бессмертными и празднуют
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		enemy.invincible_timer = 9999.0
		if enemy.has_method("set_victory_state"):
			enemy.set_victory_state()
	
	print("GameManager: Stopped %d enemies. Game Over signal emitted." % enemies.size())
	game_over.emit()
	
	# Show game over screen after a short delay
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = true
	_show_game_over_screen()

func _show_game_over_screen() -> void:
	var game_over_scene = preload("res://scenes/ui/game_over_screen.tscn")
	var game_over_instance = game_over_scene.instantiate()
	
	# Add to current scene's UI layer
	var current_scene = get_tree().current_scene
	var ui_layer = current_scene.get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(game_over_instance)
	else:
		current_scene.add_child(game_over_instance)


var is_paused: bool = false


func pause_game() -> void:
	is_paused = true
	get_tree().paused = true


func resume_game() -> void:
	is_paused = false
	get_tree().paused = false


func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()


func reset_game() -> void:
	gold = 350
	lives = 20
	current_epoch = 1
	is_game_active = true
	occupied_cells.clear()
