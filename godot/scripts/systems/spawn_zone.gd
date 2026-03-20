class_name SpawnZone
extends RefCounted

## Manages spawn locations — only on border (wheat/special) tiles from Ground TileMapLayer

enum Side { NORTH, EAST, SOUTH, WEST }


static func _get_border_tiles() -> Array[Vector2i]:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.current_scene:
		return []
	var ground = tree.current_scene.get_node_or_null("Ground") as TileMapLayer
	if not ground:
		return []

	var result: Array[Vector2i] = []
	var cells = ground.get_used_cells()
	for cell in cells:
		if ground is IsoGround and ground.is_border(cell.x, cell.y):
			result.append(cell)
	return result


static func _get_center() -> Vector2:
	var tiles = _get_border_tiles()
	if tiles.is_empty():
		return Vector2.ZERO
	var sum = Vector2.ZERO
	for t in tiles:
		sum += Vector2(t.x, t.y)
	return sum / tiles.size()


static func get_side_tiles(side: Side) -> Array[Vector2i]:
	var all_border = _get_border_tiles()
	if all_border.is_empty():
		return []

	var center = _get_center()
	var result: Array[Vector2i] = []

	for tile in all_border:
		var rel = Vector2(tile.x, tile.y) - center
		match side:
			Side.NORTH:
				if rel.y < 0 and absf(rel.x) < absf(rel.y):
					result.append(tile)
			Side.SOUTH:
				if rel.y > 0 and absf(rel.x) < absf(rel.y):
					result.append(tile)
			Side.WEST:
				if rel.x < 0 and absf(rel.y) <= absf(rel.x):
					result.append(tile)
			Side.EAST:
				if rel.x > 0 and absf(rel.y) <= absf(rel.x):
					result.append(tile)

	return result


static func get_all_perimeter_tiles() -> Array[Vector2i]:
	return _get_border_tiles()


static func pick_spawn_tile(side: Side) -> Vector2i:
	var tiles = get_side_tiles(side)
	if tiles.is_empty():
		# Фоллбэк — любой бордюрный тайл
		tiles = _get_border_tiles()
	if tiles.is_empty():
		return Vector2i(0, 0)
	var chosen = tiles[randi() % tiles.size()]
	return chosen
