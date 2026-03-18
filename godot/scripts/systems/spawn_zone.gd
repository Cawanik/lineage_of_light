class_name SpawnZone
extends RefCounted

## Manages spawn locations on the map perimeter (edges of 30x30 grid)

enum Side { NORTH, EAST, SOUTH, WEST }

const GRID_SIZE: int = 30


static func get_side_tiles(side: Side) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	match side:
		Side.NORTH:
			for x in range(GRID_SIZE):
				tiles.append(Vector2i(x, 0))
		Side.SOUTH:
			for x in range(GRID_SIZE):
				tiles.append(Vector2i(x, GRID_SIZE - 1))
		Side.WEST:
			for y in range(GRID_SIZE):
				tiles.append(Vector2i(0, y))
		Side.EAST:
			for y in range(GRID_SIZE):
				tiles.append(Vector2i(GRID_SIZE - 1, y))
	return tiles


static func get_all_perimeter_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for side in [Side.NORTH, Side.EAST, Side.SOUTH, Side.WEST]:
		tiles.append_array(get_side_tiles(side))
	return tiles


static func pick_spawn_tile(side: Side) -> Vector2i:
	var tiles = get_side_tiles(side)
	var chosen = tiles[randi() % tiles.size()]
	print("SpawnZone.pick_spawn_tile: side=%d, available=%d, chosen=%s" % [side, tiles.size(), chosen])
	return chosen
