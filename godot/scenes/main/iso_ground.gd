class_name IsoGround
extends Node2D

## Isometric tile ground with weighted random placement

const CELL_SIZE = 64
const ISO_RATIO = 0.5  # Y squash for isometric

var tiles_loaded: Array[Texture2D] = []
var tile_weights: Array[float] = []

# Grid data: Vector2i -> tile_index
var grid: Dictionary = {}

var grid_width: int = 30
var grid_height: int = 30


func _ready() -> void:
	_load_tiles()
	_generate_grid()
	queue_redraw()


func _load_tiles() -> void:
	var tile_defs = [
		# Grass variants (~60%)
		{"path": "res://assets/sprites/tiles/iso_tile_0.png", "weight": 12.0},   # grass + purple flowers
		{"path": "res://assets/sprites/tiles/iso_grass_0.png", "weight": 12.0},   # wildflowers
		{"path": "res://assets/sprites/tiles/iso_grass_1.png", "weight": 12.0},   # mushrooms
		{"path": "res://assets/sprites/tiles/iso_grass_2.png", "weight": 12.0},   # fallen leaves
		{"path": "res://assets/sprites/tiles/iso_grass_3.png", "weight": 12.0},   # sparse grass
		# Dirt (~20%)
		{"path": "res://assets/sprites/tiles/iso_tile_2.png", "weight": 20.0},    # dirt + pebbles
		# Stone (~10%)
		{"path": "res://assets/sprites/tiles/iso_tile_1.png", "weight": 10.0},    # cobblestone
	]

	for def in tile_defs:
		if ResourceLoader.exists(def["path"]):
			tiles_loaded.append(load(def["path"]))
			tile_weights.append(def["weight"])


func _generate_grid() -> void:
	# Build cumulative weights for weighted random
	var total_weight = 0.0
	var cumulative: Array[float] = []
	for w in tile_weights:
		total_weight += w
		cumulative.append(total_weight)

	# Use seeded RNG for consistent map
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	for y in range(grid_height):
		for x in range(grid_width):
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
			var tile_idx = grid.get(Vector2i(x, y), 0)
			if tile_idx >= tiles_loaded.size():
				continue

			# Isometric position: diamond layout
			var screen_x = (x - y) * (CELL_SIZE * 0.5)
			var screen_y = (x + y) * (CELL_SIZE * ISO_RATIO * 0.5)

			var tex = tiles_loaded[tile_idx]
			var draw_pos = Vector2(
				screen_x - tex.get_width() * 0.5,
				screen_y - tex.get_height() * 0.5
			)
			draw_texture(tex, draw_pos)
