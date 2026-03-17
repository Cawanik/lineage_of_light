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


func reset_game() -> void:
	gold = 150
	lives = 20
	current_epoch = 1
	is_game_active = true
	occupied_cells.clear()
