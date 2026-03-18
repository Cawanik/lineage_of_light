class_name MapExporter

## Exports map as a 2D matrix of IDs with entity definitions header
## Format: { entities: { "1": {...}, "2": {...} }, matrix: [[0,1,2,...], ...] }
## 0 is always empty, IDs assigned dynamically per export

const SAVE_PATH = "user://map_export.json"


static func export_map(building_grid: BuildingGrid, wall_system: WallSystem) -> String:
	var iso = Config.game.get("iso", {})
	var width: int = iso.get("grid_width", 32)
	var height: int = iso.get("grid_height", 32)

	# Assign IDs: collect unique entity types
	# type_key -> { id, data }
	var entities: Dictionary = {}
	var next_id: int = 1

	# Spawn zone (border tiles)
	entities["spawn"] = {
		"id": next_id,
		"data": {
			"type": "spawn",
			"name": "Зона спавна",
			"passable": true,
			"buildable": false,
		},
	}
	next_id += 1

	# Wall pillar entity
	var wall_config = Config.buildings.get("wall", {})
	entities["wall_pillar"] = {
		"id": next_id,
		"data": {
			"type": "wall_pillar",
			"name": wall_config.get("name", "Стена"),
			"hp": int(wall_config.get("hp", 0)),
			"cost": int(wall_config.get("cost", 10)),
		},
	}
	next_id += 1

	# Building entities
	for tile in building_grid.buildings:
		var building = building_grid.buildings[tile]
		var btype: String = building.building_type
		if not entities.has(btype):
			entities[btype] = {
				"id": next_id,
				"data": {
					"type": btype,
					"name": Config.buildings.get(btype, {}).get("name", btype),
					"hp": building.max_hp,
					"cost": int(Config.buildings.get(btype, {}).get("cost", 0)),
					"can_demolish": building.can_demolish,
					"can_move": building.can_move,
				},
			}
			next_id += 1

	# Build matrix
	var matrix: Array = []
	for y in range(height):
		var row: Array = []
		row.resize(width)
		row.fill(0)
		matrix.append(row)

	# Fill border as spawn zones
	var spawn_id: int = entities["spawn"]["id"]
	for y in range(height):
		for x in range(width):
			if x <= 1 or y <= 1 or x >= width - 2 or y >= height - 2:
				matrix[y][x] = spawn_id

	# Fill wall pillars
	var wall_id: int = entities["wall_pillar"]["id"]
	for node_pos in wall_system.nodes:
		if node_pos.x >= 0 and node_pos.x < width and node_pos.y >= 0 and node_pos.y < height:
			matrix[node_pos.y][node_pos.x] = wall_id

	# Fill buildings (overwrite if overlapping)
	for tile in building_grid.buildings:
		if tile.x >= 0 and tile.x < width and tile.y >= 0 and tile.y < height:
			var building = building_grid.buildings[tile]
			matrix[tile.y][tile.x] = entities[building.building_type]["id"]

	# Build entities header: id -> properties
	var entities_header: Dictionary = {}
	for key in entities:
		var entry = entities[key]
		entities_header[str(entry["id"])] = entry["data"]

	var data = {
		"version": 1,
		"width": width,
		"height": height,
		"entities": entities_header,
		"matrix": matrix,
	}

	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[MapExporter] Failed to open file: %s" % FileAccess.get_open_error())
		return ""

	file.store_string(json_string)
	file.close()

	var abs_path = ProjectSettings.globalize_path(SAVE_PATH)
	print("[MapExporter] Exported %dx%d matrix to: %s" % [width, height, abs_path])
	return abs_path
