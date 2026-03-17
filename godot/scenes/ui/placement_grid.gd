extends Node2D

## Shows a highlighted grid cell under the mouse for tower placement

const CELL_SIZE = 128
const GRID_COUNT = 30  # 30x30 tiles

var hovered_cell: Vector2i = Vector2i(-1, -1)
var placement_mode: bool = false

# Colors
var color_valid = Color(0.6, 0.2, 0.8, 0.25)       # purple fill
var color_valid_border = Color(0.6, 0.2, 0.8, 0.6)  # purple border
var color_invalid = Color(0.55, 0.0, 0.0, 0.25)     # red fill
var color_invalid_border = Color(0.55, 0.0, 0.0, 0.6)


func _process(_delta: float) -> void:
	if not placement_mode:
		if visible:
			visible = false
		return

	visible = true
	var mouse_pos = get_global_mouse_position()
	var new_cell = Vector2i(
		clampi(int(mouse_pos.x / CELL_SIZE), 0, GRID_COUNT - 1),
		clampi(int(mouse_pos.y / CELL_SIZE), 0, GRID_COUNT - 1)
	)

	if new_cell != hovered_cell:
		hovered_cell = new_cell
		queue_redraw()


func _draw() -> void:
	if not placement_mode or hovered_cell.x < 0:
		return

	var rect_pos = Vector2(hovered_cell.x * CELL_SIZE, hovered_cell.y * CELL_SIZE)
	var rect = Rect2(rect_pos, Vector2(CELL_SIZE, CELL_SIZE))

	# Check if cell is occupied (placeholder - always valid for now)
	var is_valid = true

	var fill = color_valid if is_valid else color_invalid
	var border = color_valid_border if is_valid else color_invalid_border

	# Fill
	draw_rect(rect, fill, true)
	# Border
	draw_rect(rect, border, false, 1.5)

	# Corner marks for pseudo-3D feel
	var s = 6.0
	var corners = [
		rect_pos,
		rect_pos + Vector2(CELL_SIZE, 0),
		rect_pos + Vector2(0, CELL_SIZE),
		rect_pos + Vector2(CELL_SIZE, CELL_SIZE),
	]
	for c in corners:
		draw_line(c, c + Vector2(s, 0), border, 1.5)
		draw_line(c, c + Vector2(0, s), border, 1.5)
		draw_line(c, c + Vector2(-s, 0), border, 1.5)
		draw_line(c, c + Vector2(0, -s), border, 1.5)


func toggle_placement() -> void:
	placement_mode = not placement_mode


func get_cell_world_center() -> Vector2:
	return Vector2(
		hovered_cell.x * CELL_SIZE + CELL_SIZE / 2.0,
		hovered_cell.y * CELL_SIZE + CELL_SIZE / 2.0
	)
