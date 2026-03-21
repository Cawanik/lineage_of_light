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

var gold: int = 150:
	set(value):
		gold = value
		gold_changed.emit(gold)

var lives: int = 20:
	set(value):
		lives = max(0, value)
		lives_changed.emit(lives)
		if lives <= 0:
			game_over.emit()

var current_epoch: int = 1
var is_game_active: bool = true

# Grid-based tower placement
const GRID_SIZE = 32
var occupied_cells: Dictionary = {}  # Vector2i -> tower_ref


func _ready() -> void:
	pass


func can_afford(cost: int) -> bool:
	return gold >= cost


func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false


func earn_gold(amount: int) -> void:
	gold += amount


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
	
	# Clear pathfinding system
	var ps = get_node_or_null("/root/PathfindingSystem")
	if ps and ps.has_method("clear_throne"):
		ps.clear_throne()
	
	# Stop all enemy AI immediately
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("set_victory_state"):
			enemy.set_victory_state()
	
	print("GameManager: Stopped %d enemies. Game Over signal emitted." % enemies.size())
	game_over.emit()
	
	# Show game over screen after a short delay
	await get_tree().create_timer(1.5).timeout
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
	gold = 150
	lives = 20
	current_epoch = 1
	is_game_active = true
	occupied_cells.clear()
