# ==========================================
# iso_ground.gd — Изометрическая земля, трава и всякая хуйня
# ==========================================
# _ready() — грузит конфиг, тайлы, бордюры, генерит сетку и ставит на перерисовку
# _load_tiles() — загружает текстуры травы с весами из конфига, 8 вариантов, ёпт
# _load_border_tile() — загружает текстуру бордюра (пшеница), если есть
# is_border(x, y) — проверяет, тайл на границе карты или нет, блять
# _generate_grid() — генерит сетку тайлов по весам через seeded RNG, чтоб карта была одинаковая
# _draw() — рисует все тайлы в изометрии: бордюр на краях, рандомная трава внутри
# ==========================================

class_name IsoGround
extends Node2D

## Isometric tile ground with weighted random placement

var CELL_SIZE: int = 64
var ISO_RATIO: float = 0.5

var tiles_loaded: Array[Texture2D] = []
var tile_weights: Array[float] = []
var border_tile: Texture2D = null

var grid: Dictionary = {}

var grid_width: int = 32
var grid_height: int = 32
var ground_seed: int = 42
var tile_draw_offset_y: float = 0.0


func _ready() -> void:
	var iso = Config.game.get("iso", {})
	CELL_SIZE = iso.get("cell_size", 64)
	ISO_RATIO = iso.get("iso_ratio", 0.5)
	grid_width = iso.get("grid_width", 32)
	grid_height = iso.get("grid_height", 32)
	ground_seed = iso.get("ground_seed", 42)
	tile_draw_offset_y = iso.get("tile_draw_offset_y", 0.0)

	_load_tiles()
	_load_border_tile()
	_generate_grid()
	queue_redraw()


func _load_tiles() -> void:
	var tw = Config.game.get("tile_weights", {})
	var tile_defs = [
		{"path": "res://assets/sprites/tiles/iso_grass_0.png", "weight": tw.get("grass_wildflower", 15.0)},
		{"path": "res://assets/sprites/tiles/iso_grass_1.png", "weight": tw.get("grass_mushroom", 15.0)},
		{"path": "res://assets/sprites/tiles/iso_grass_2.png", "weight": tw.get("grass_leaves", 15.0)},
		{"path": "res://assets/sprites/tiles/iso_grass_3.png", "weight": tw.get("grass_sparse", 15.0)},
		{"path": "res://assets/sprites/tiles/iso_grass_4.png", "weight": tw.get("grass_dandelion", 10.0)},
		{"path": "res://assets/sprites/tiles/iso_grass_5.png", "weight": tw.get("grass_daisy", 10.0)},
		{"path": "res://assets/sprites/tiles/iso_grass_6.png", "weight": tw.get("grass_clover", 10.0)},
		{"path": "res://assets/sprites/tiles/iso_grass_7.png", "weight": tw.get("grass_twigs", 10.0)},
	]

	for def in tile_defs:
		if ResourceLoader.exists(def["path"]):
			tiles_loaded.append(load(def["path"]))
			tile_weights.append(def["weight"])


func _load_border_tile() -> void:
	var path = "res://assets/sprites/tiles/iso_wheat_0.png"
	if ResourceLoader.exists(path):
		border_tile = load(path)


func is_border(x: int, y: int) -> bool:
	return x <= 1 or y <= 1 or x >= grid_width - 2 or y >= grid_height - 2


func _generate_grid() -> void:
	# Build cumulative weights for weighted random
	var total_weight = 0.0
	var cumulative: Array[float] = []
	for w in tile_weights:
		total_weight += w
		cumulative.append(total_weight)

	# Use seeded RNG for consistent map
	var rng = RandomNumberGenerator.new()
	rng.seed = ground_seed

	for y in range(grid_height):
		for x in range(grid_width):
			if is_border(x, y):
				pass  # border uses single tile
			else:
				var roll = rng.randf() * total_weight
				var tile_idx = 0
				for i in range(cumulative.size()):
					if roll <= cumulative[i]:
						tile_idx = i
						break
				grid[Vector2i(x, y)] = tile_idx


func _draw() -> void:
	if tiles_loaded.is_empty():
		return

	for y in range(grid_height):
		for x in range(grid_width):
			# Isometric position: diamond layout
			var screen_x = (x - y) * (CELL_SIZE * 0.5)
			var screen_y = (x + y) * (CELL_SIZE * ISO_RATIO * 0.5) + 20.0

			var tex: Texture2D
			if is_border(x, y) and border_tile:
				tex = border_tile
			else:
				var tile_idx = grid.get(Vector2i(x, y), 0)
				if tile_idx >= tiles_loaded.size():
					continue
				tex = tiles_loaded[tile_idx]

			var draw_pos = Vector2(
				screen_x - tex.get_width() * 0.5,
				screen_y - tex.get_height() * 0.5
			)
			draw_texture(tex, draw_pos)
