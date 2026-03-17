@tool
class_name WallSegment
extends Node2D

## Procedurally drawn isometric wall segment
## Connects along isometric axes: NE-SW (/) and NW-SE (\)

# Which connections this wall has
@export var connect_ne: bool = false:
	set(v): connect_ne = v; queue_redraw()
@export var connect_sw: bool = false:
	set(v): connect_sw = v; queue_redraw()
@export var connect_nw: bool = false:
	set(v): connect_nw = v; queue_redraw()
@export var connect_se: bool = false:
	set(v): connect_se = v; queue_redraw()

# Wall style
@export var wall_height: float = 24.0
@export var wall_thickness: float = 8.0
@export var show_pillar: bool = true

# Palette
var col_top = Color("#5a5570")       # light stone top
var col_front = Color("#3a3450")     # front face
var col_side = Color("#2a2440")      # dark side face
var col_dark = Color("#1a1030")      # shadow/outline
var col_highlight = Color("#6a6580") # top highlight
var col_moss = Color("#2d4a27")      # moss spots
var col_crack = Color("#151020")     # cracks

const HALF_TILE = 32.0  # half of 64px tile
const ISO_RATIO = 0.5   # isometric Y squash


func _draw() -> void:
	# Draw wall segments extending from center to each connected direction
	if connect_ne:
		_draw_wall_segment(Vector2(0, 0), Vector2(HALF_TILE, -HALF_TILE * ISO_RATIO), true)
	if connect_sw:
		_draw_wall_segment(Vector2(0, 0), Vector2(-HALF_TILE, HALF_TILE * ISO_RATIO), true)
	if connect_nw:
		_draw_wall_segment(Vector2(0, 0), Vector2(-HALF_TILE, -HALF_TILE * ISO_RATIO), false)
	if connect_se:
		_draw_wall_segment(Vector2(0, 0), Vector2(HALF_TILE, HALF_TILE * ISO_RATIO), false)

	# Center pillar (always drawn if any connection or standalone)
	if show_pillar:
		_draw_pillar(Vector2(0, 0))


func _draw_wall_segment(from: Vector2, to: Vector2, is_ne_axis: bool) -> void:
	var dir = (to - from).normalized()
	var perp = Vector2(-dir.y, dir.x) * wall_thickness * 0.5

	# Wall top surface (diamond shape)
	var top_points = PackedVector2Array([
		from + perp + Vector2(0, -wall_height),
		to + perp + Vector2(0, -wall_height),
		to - perp + Vector2(0, -wall_height),
		from - perp + Vector2(0, -wall_height),
	])
	draw_colored_polygon(top_points, col_top)

	# Front face
	var front_points: PackedVector2Array
	if is_ne_axis:
		# NE-SW axis: front face is on the right side
		front_points = PackedVector2Array([
			from - perp + Vector2(0, -wall_height),
			to - perp + Vector2(0, -wall_height),
			to - perp,
			from - perp,
		])
		draw_colored_polygon(front_points, col_front)
	else:
		# NW-SE axis: front face is on the left side
		front_points = PackedVector2Array([
			from + perp + Vector2(0, -wall_height),
			to + perp + Vector2(0, -wall_height),
			to + perp,
			from + perp,
		])
		draw_colored_polygon(front_points, col_front)

	# Side face (the other side, darker)
	var side_points: PackedVector2Array
	if is_ne_axis:
		side_points = PackedVector2Array([
			from + perp + Vector2(0, -wall_height),
			to + perp + Vector2(0, -wall_height),
			to + perp,
			from + perp,
		])
		draw_colored_polygon(side_points, col_side)
	else:
		side_points = PackedVector2Array([
			from - perp + Vector2(0, -wall_height),
			to - perp + Vector2(0, -wall_height),
			to - perp,
			from - perp,
		])
		draw_colored_polygon(side_points, col_side)

	# Outlines
	for i in range(top_points.size()):
		var next = (i + 1) % top_points.size()
		draw_line(top_points[i], top_points[next], col_dark, 1.0)

	# Brick lines on front face
	_draw_bricks(front_points, is_ne_axis)

	# Battlements on top
	_draw_battlements(from, to, perp)


func _draw_bricks(face: PackedVector2Array, is_ne_axis: bool) -> void:
	if face.size() < 4:
		return

	# Draw 2-3 horizontal brick lines
	for row in range(1, 4):
		var t = row / 4.0
		var left = face[3].lerp(face[0], t)
		var right = face[2].lerp(face[1], t)
		draw_line(left, right, col_crack, 1.0)

		# Vertical brick offsets
		var mid = left.lerp(right, 0.5 + (0.15 if row % 2 == 0 else -0.1))
		var next_t = (row + 1) / 4.0
		var next_left = face[3].lerp(face[0], next_t) if row < 3 else face[3]
		var next_mid = next_left.lerp(face[2].lerp(face[1], next_t) if row < 3 else face[2],
			0.5 + (0.15 if row % 2 == 0 else -0.1))
		draw_line(mid, next_mid, col_crack, 1.0)


func _draw_battlements(from: Vector2, to: Vector2, perp: Vector2) -> void:
	# Small notches on top of wall
	var steps = 3
	for i in range(steps):
		var t = (i + 0.5) / steps
		var pos = from.lerp(to, t) + Vector2(0, -wall_height)
		var merlon_size = Vector2(3, 4)
		# Small raised blocks
		draw_rect(Rect2(pos - merlon_size * 0.5 - Vector2(0, merlon_size.y), merlon_size), col_highlight)
		draw_rect(Rect2(pos - merlon_size * 0.5 - Vector2(0, merlon_size.y), merlon_size), col_dark, false, 1.0)


func _draw_pillar(pos: Vector2) -> void:
	# Center junction pillar
	var s = wall_thickness * 0.7
	var h = wall_height + 4

	# Pillar top
	var top = PackedVector2Array([
		pos + Vector2(-s, -h),
		pos + Vector2(s, -h),
		pos + Vector2(s, -h + s * 0.5),
		pos + Vector2(-s, -h + s * 0.5),
	])
	draw_colored_polygon(top, col_highlight)

	# Pillar front
	var front = PackedVector2Array([
		pos + Vector2(-s, -h + s * 0.5),
		pos + Vector2(s, -h + s * 0.5),
		pos + Vector2(s, 0),
		pos + Vector2(-s, 0),
	])
	draw_colored_polygon(front, col_front)

	# Outline
	for pts in [top, front]:
		for i in range(pts.size()):
			draw_line(pts[i], pts[(i + 1) % pts.size()], col_dark, 1.0)
