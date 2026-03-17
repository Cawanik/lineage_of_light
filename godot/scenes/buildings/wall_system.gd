class_name WallSystem
extends Node2D

## AoE-style wall system
## Walls are edges between grid nodes, not nodes themselves
## Click two adjacent nodes to build a wall segment between them

var CELL_SIZE: int = 64
var ISO_RATIO: float = 0.5
var WALL_HEIGHT: float = 28.0
var WALL_THICK: float = 6.0

# Palette
var col_top: Color
var col_front: Color
var col_side: Color
var col_dark: Color
var col_brick: Color
var col_highlight: Color
var col_merlon: Color

# Nodes where walls meet: Vector2i -> true
var nodes: Dictionary = {}
# Edges (wall segments): StringName -> true (key = "x1,y1-x2,y2" sorted)
var edges: Dictionary = {}
# Collision bodies: StringName -> StaticBody2D
var collision_bodies: Dictionary = {}
# Visual child nodes
var visual_nodes: Array[Node2D] = []
var _needs_rebuild: bool = false
var _target: WallDrawNode = null
# Visual lookup: edge_key -> WallDrawNode, node Vector2i -> WallDrawNode
var wall_visuals: Dictionary = {}   # StringName -> WallDrawNode
var pillar_visuals: Dictionary = {} # Vector2i -> WallDrawNode
var player: Node2D = null
var FADE_RADIUS: float = 50.0
var DEMOLISH_SNAP_RADIUS: float = 16.0

var demolish_mode: bool = false
var hovered_node: Vector2i = Vector2i(-9999, -9999)

var build_mode: bool = false
var build_preview_node: Vector2i = Vector2i(-9999, -9999)
var build_preview_draw: Node2D = null  # draws the green preview


func _poly(points: PackedVector2Array, color: Color) -> void:
	if _target:
		_target.add_polygon(points, color)


func _line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	if _target:
		_target.add_line(from, to, color, width)


func _ready() -> void:
	y_sort_enabled = true
	_load_config()


func _load_config() -> void:
	var iso = Config.game.get("iso", {})
	CELL_SIZE = iso.get("cell_size", 64)
	ISO_RATIO = iso.get("iso_ratio", 0.5)

	var w = Config.buildings.get("wall", {})
	WALL_HEIGHT = w.get("height", 28.0)
	WALL_THICK = w.get("thickness", 6.0)
	FADE_RADIUS = w.get("fade_radius", 50.0)
	DEMOLISH_SNAP_RADIUS = w.get("demolish_snap_radius", 16.0)

	var wc = w.get("colors", {})
	col_top = Color(wc.get("top", "#6a6580"))
	col_front = Color(wc.get("front", "#4a4460"))
	col_side = Color(wc.get("side", "#2a2440"))
	col_dark = Color(wc.get("dark", "#1a1030"))
	col_brick = Color(wc.get("brick", "#1f1535"))
	col_highlight = Color(wc.get("highlight", "#7a7590"))
	col_merlon = Color(wc.get("merlon", "#5a5470"))


func _process(_delta: float) -> void:
	if _needs_rebuild:
		_needs_rebuild = false
		_rebuild_visuals()
	_update_transparency()
	if demolish_mode:
		_update_demolish_hover()
	if build_mode:
		_update_build_preview()


func _make_edge_key(a: Vector2i, b: Vector2i) -> StringName:
	# Ensure consistent key regardless of order
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return StringName("%d,%d-%d,%d" % [a.x, a.y, b.x, b.y])
	else:
		return StringName("%d,%d-%d,%d" % [b.x, b.y, a.x, a.y])


func place_wall_between(a: Vector2i, b: Vector2i) -> void:
	var key = _make_edge_key(a, b)
	if edges.has(key):
		return
	edges[key] = true
	nodes[a] = true
	nodes[b] = true
	_create_collision(key, a, b)
	_needs_rebuild = true


func _create_collision(key: StringName, a: Vector2i, b: Vector2i) -> void:
	var wa = grid_to_world(a)
	var wb = grid_to_world(b)
	var center = (wa + wb) * 0.5
	var length = wa.distance_to(wb)
	var angle = (wb - wa).angle()

	var body = StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(length, WALL_THICK * 2.0)
	shape.shape = rect
	shape.rotation = angle

	body.add_child(shape)
	add_child(body)
	collision_bodies[key] = body


func place_wall_line(from: Vector2i, to: Vector2i) -> void:
	## Place walls along a line between two grid points
	var diff = to - from
	var steps = maxi(absi(diff.x), absi(diff.y))
	if steps == 0:
		return
	var step = Vector2i(signi(diff.x), signi(diff.y))
	var current = from
	for i in range(steps):
		var next = current + step
		place_wall_between(current, next)
		current = next


func remove_wall_between(a: Vector2i, b: Vector2i) -> void:
	var key = _make_edge_key(a, b)
	edges.erase(key)
	if collision_bodies.has(key):
		collision_bodies[key].queue_free()
		collision_bodies.erase(key)
	# Clean up orphan nodes
	if not _node_has_edges(a):
		nodes.erase(a)
	if not _node_has_edges(b):
		nodes.erase(b)
	_needs_rebuild = true


func _node_has_edges(node: Vector2i) -> bool:
	for neighbor in _get_neighbors(node):
		if edges.has(_make_edge_key(node, neighbor)):
			return true
	return false


func _get_neighbors(pos: Vector2i) -> Array:
	return [
		pos + Vector2i(1, 0),
		pos + Vector2i(-1, 0),
		pos + Vector2i(0, 1),
		pos + Vector2i(0, -1),
		pos + Vector2i(1, -1),  # NE
		pos + Vector2i(-1, 1),  # SW
		pos + Vector2i(-1, -1), # NW
		pos + Vector2i(1, 1),   # SE
	]


func _node_edge_count(node: Vector2i) -> int:
	var count = 0
	for neighbor in _get_neighbors(node):
		if edges.has(_make_edge_key(node, neighbor)):
			count += 1
	return count


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	# Isometric projection matching IsoGround, offset to tile center
	# Center of tile (x,y) — offset +0.5 to go from corner to center of diamond
	var cx = grid_pos.x + 0.5
	var cy = grid_pos.y + 0.5
	var screen_x = (cx - cy) * (CELL_SIZE * 0.5)
	var screen_y = (cx + cy) * (CELL_SIZE * ISO_RATIO * 0.5) + 8.0
	return Vector2(screen_x, screen_y)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	# Reverse isometric projection
	var fx = world_pos.x / (CELL_SIZE * 0.5)
	var fy = world_pos.y / (CELL_SIZE * ISO_RATIO * 0.5)
	var gx = (fx + fy) * 0.5
	var gy = (fy - fx) * 0.5
	return Vector2i(roundi(gx), roundi(gy))


func _get_ysort() -> Node2D:
	return get_parent()


func _update_demolish_hover() -> void:
	var mouse_pos = get_global_mouse_position()
	var closest_node = Vector2i(-9999, -9999)
	var closest_dist = DEMOLISH_SNAP_RADIUS

	for node_pos in nodes:
		var wpos = grid_to_world(node_pos)
		var dist = mouse_pos.distance_to(wpos)
		if dist < closest_dist:
			closest_dist = dist
			closest_node = node_pos

	if closest_node != hovered_node:
		# Reset old highlight
		_set_node_highlight(hovered_node, false)
		hovered_node = closest_node
		# Set new highlight
		_set_node_highlight(hovered_node, true)


func _set_node_highlight(node_pos: Vector2i, highlighted: bool) -> void:
	if node_pos == Vector2i(-9999, -9999):
		return
	var tint = Color(1.0, 0.3, 0.3) if highlighted else Color.WHITE

	# Tint pillar
	if pillar_visuals.has(node_pos) and is_instance_valid(pillar_visuals[node_pos]):
		pillar_visuals[node_pos].self_modulate = tint

	# Tint connected walls
	for neighbor in _get_neighbors(node_pos):
		var key = _make_edge_key(node_pos, neighbor)
		if wall_visuals.has(key) and is_instance_valid(wall_visuals[key]):
			wall_visuals[key].self_modulate = tint


func demolish_hovered() -> void:
	if hovered_node == Vector2i(-9999, -9999):
		return

	var target = hovered_node
	hovered_node = Vector2i(-9999, -9999)

	# Collect all edges connected to this node
	var edges_to_remove: Array = []
	for neighbor in _get_neighbors(target):
		var key = _make_edge_key(target, neighbor)
		if edges.has(key):
			edges_to_remove.append(key)

	# Remove edges and collisions
	for key in edges_to_remove:
		edges.erase(key)
		if collision_bodies.has(key):
			collision_bodies[key].queue_free()
			collision_bodies.erase(key)

	# Remove only this node, keep neighbors
	nodes.erase(target)

	_needs_rebuild = true


func clear_demolish_mode() -> void:
	_set_node_highlight(hovered_node, false)
	hovered_node = Vector2i(-9999, -9999)
	demolish_mode = false


# === BUILD MODE ===

func _update_build_preview() -> void:
	var mouse_pos = get_global_mouse_position()
	var grid_pos = world_to_grid(mouse_pos)

	if grid_pos != build_preview_node:
		build_preview_node = grid_pos
		_redraw_build_preview()


func _redraw_build_preview() -> void:
	# Remove old preview nodes
	if is_instance_valid(build_preview_draw):
		build_preview_draw.queue_free()

	build_preview_draw = Node2D.new()
	get_tree().current_scene.add_child(build_preview_draw)

	var pos = build_preview_node
	var wpos = grid_to_world(pos)
	var already_exists = nodes.has(pos)

	# Draw pillar preview
	var pillar_wdn = WallDrawNode.new()
	pillar_wdn.position = Vector2(wpos.x, wpos.y + 0.5)
	pillar_wdn.z_index = 100
	pillar_wdn.modulate = Color(0.4, 1.0, 0.4, 0.7) if not already_exists else Color(1.0, 1.0, 0.4, 0.5)
	_target = pillar_wdn
	_draw_pillar(Vector2(0, -0.5))
	_target = null
	build_preview_draw.add_child(pillar_wdn)

	# Draw wall previews to adjacent existing nodes
	var cardinal = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir in cardinal:
		var neighbor = pos + dir
		if nodes.has(neighbor):
			var key = _make_edge_key(pos, neighbor)
			var edge_exists = edges.has(key)

			var nwpos = grid_to_world(neighbor)
			var draw_from = wpos
			var draw_to = nwpos
			# Shrink at upper end
			var shrink = 5.0
			if draw_from.y < draw_to.y:
				draw_from = wpos + (nwpos - wpos).normalized() * shrink
			elif draw_to.y < draw_from.y:
				draw_to = nwpos + (wpos - nwpos).normalized() * shrink

			var wall_wdn = WallDrawNode.new()
			var sort_y = minf(draw_from.y, draw_to.y)
			wall_wdn.position = Vector2(0, sort_y)
			wall_wdn.z_index = 99
			wall_wdn.modulate = Color(1.0, 1.0, 0.4, 0.4) if edge_exists else Color(0.4, 1.0, 0.4, 0.5)
			_target = wall_wdn
			_draw_wall_edge(draw_from - wall_wdn.position, draw_to - wall_wdn.position)
			_target = null
			build_preview_draw.add_child(wall_wdn)


func place_at_preview() -> void:
	if build_preview_node == Vector2i(-9999, -9999):
		return

	var pos = build_preview_node

	# Add node
	nodes[pos] = true

	# Connect to adjacent existing nodes (4 cardinal directions)
	var cardinal = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir in cardinal:
		var neighbor = pos + dir
		if nodes.has(neighbor):
			place_wall_between(pos, neighbor)

	_needs_rebuild = true


func clear_build_mode() -> void:
	build_mode = false
	build_preview_node = Vector2i(-9999, -9999)
	if is_instance_valid(build_preview_draw):
		build_preview_draw.queue_free()
		build_preview_draw = null




func _find_player() -> void:
	if player != null:
		return
	var ysort = _get_ysort()
	for child in ysort.get_children():
		if child is Player:
			player = child
			break


func _update_transparency() -> void:
	_find_player()
	if player == null:
		return

	# Find which nodes are close to player
	var fade_nodes: Dictionary = {}  # Vector2i -> true
	for node_pos in nodes:
		var wpos = grid_to_world(node_pos)
		var diff_y = wpos.y - player.position.y
		var diff_x = absf(wpos.x - player.position.x)
		# Node is "in front of" player and close
		if diff_y > 0 and diff_y < FADE_RADIUS and diff_x < FADE_RADIUS:
			fade_nodes[node_pos] = true

	# Apply transparency to pillars
	for node_pos in pillar_visuals:
		var wdn: WallDrawNode = pillar_visuals[node_pos]
		if is_instance_valid(wdn):
			wdn.modulate.a = 0.5 if fade_nodes.has(node_pos) else 1.0

	# Apply transparency to walls: fade if either endpoint is faded
	for key in wall_visuals:
		var wdn: WallDrawNode = wall_visuals[key]
		if not is_instance_valid(wdn):
			continue
		var parts = str(key).split("-")
		var a_parts = parts[0].split(",")
		var b_parts = parts[1].split(",")
		var a = Vector2i(int(a_parts[0]), int(a_parts[1]))
		var b = Vector2i(int(b_parts[0]), int(b_parts[1]))
		var should_fade = fade_nodes.has(a) or fade_nodes.has(b)
		wdn.modulate.a = 0.5 if should_fade else 1.0


func _rebuild_visuals() -> void:
	# Remove old visual nodes
	for vn in visual_nodes:
		if is_instance_valid(vn):
			vn.queue_free()
	visual_nodes.clear()
	wall_visuals.clear()
	pillar_visuals.clear()
	var ysort = _get_ysort()

	# Create wall segment nodes
	for key in edges:
		var parts = str(key).split("-")
		var a_parts = parts[0].split(",")
		var b_parts = parts[1].split(",")
		var a = Vector2i(int(a_parts[0]), int(a_parts[1]))
		var b = Vector2i(int(b_parts[0]), int(b_parts[1]))
		var wa = grid_to_world(a)
		var wb = grid_to_world(b)

		# Shorten wall at the upper end (smaller Y) so pillar is visible
		var draw_from = wa
		var draw_to = wb
		var shrink = 5.0
		if wa.y < wb.y:
			draw_from = wa + (wb - wa).normalized() * shrink
		elif wb.y < wa.y:
			draw_to = wb + (wa - wb).normalized() * shrink
		else:
			draw_from = wa + (wb - wa).normalized() * shrink * 0.5
			draw_to = wb + (wa - wb).normalized() * shrink * 0.5

		var wdn = WallDrawNode.new()
		var sort_y = minf(draw_from.y, draw_to.y)
		wdn.position = Vector2(0, sort_y)
		_target = wdn
		_draw_wall_edge(draw_from - wdn.position, draw_to - wdn.position)
		_target = null
		ysort.add_child(wdn)
		visual_nodes.append(wdn)
		wall_visuals[key] = wdn

	# Create pillar nodes
	for node_pos in nodes:
		var _count = _node_edge_count(node_pos)
		if true:  # always draw pillar for every node
			var wpos = grid_to_world(node_pos)
			var wdn = WallDrawNode.new()
			wdn.position = Vector2(wpos.x, wpos.y + 0.5)
			_target = wdn
			_draw_pillar(Vector2(0, -0.5))
			_target = null
			ysort.add_child(wdn)
			visual_nodes.append(wdn)
			pillar_visuals[node_pos] = wdn


func _draw_wall_edge(from: Vector2, to: Vector2) -> void:
	var dir = (to - from).normalized()
	var perp = Vector2(-dir.y, dir.x) * WALL_THICK

	# 4 top corners
	var tl = from + perp + Vector2(0, -WALL_HEIGHT)
	var tr = to + perp + Vector2(0, -WALL_HEIGHT)
	var br = to - perp + Vector2(0, -WALL_HEIGHT)
	var bl = from - perp + Vector2(0, -WALL_HEIGHT)

	# 4 bottom corners (ground level)
	var gl = from + perp
	var gr = to + perp
	var gbr = to - perp
	var gbl = from - perp

	# Front face = the side facing the camera (bottom of screen = higher Y)
	# We always draw the face with higher Y as front
	var left_face = PackedVector2Array([tl, tr, gr, gl])   # +perp side
	var right_face = PackedVector2Array([bl, br, gbr, gbl]) # -perp side
	# Bottom face (connecting the two bottom edges) for horizontal walls
	var bottom_face = PackedVector2Array([gbl, gbr, gr, gl])

	# Determine visibility: the face facing "down" (toward camera) is front
	# perp points to the "left" of the wall direction
	if perp.y < -0.1:
		# +perp side faces up (away from camera) -> -perp is front
		_poly(right_face, col_front)
		_poly(left_face, col_side)
		_draw_brick_lines(right_face)
	elif perp.y > 0.1:
		# +perp side faces down (toward camera) -> +perp is front
		_poly(left_face, col_front)
		_poly(right_face, col_side)
		_draw_brick_lines(left_face)
	else:
		# Horizontal wall - both side faces are vertical, show bottom face as front
		_poly(left_face, col_side)
		_poly(right_face, col_side)
		# Draw the front-facing bottom panel
		var front_bottom = PackedVector2Array([
			br, bl,  # top edge of bottom face (at wall height)
			gbl, gbr # ground edge
		])
		_poly(front_bottom, col_front)
		_draw_brick_lines(front_bottom)

	# Top face (always visible from above)
	_poly(PackedVector2Array([tl, tr, br, bl]), col_top)

	# Outlines - top
	_line(tl, tr, col_dark, 1.0)
	_line(tr, br, col_dark, 1.0)
	_line(br, bl, col_dark, 1.0)
	_line(bl, tl, col_dark, 1.0)

	# Outlines - vertical edges (only visible ones)
	if perp.y <= 0.1:
		_line(bl, gbl, col_dark, 1.0)
		_line(br, gbr, col_dark, 1.0)
		_line(gbl, gbr, col_dark, 1.0)
	if perp.y >= -0.1:
		_line(tl, gl, col_dark, 1.0)
		_line(tr, gr, col_dark, 1.0)
		_line(gl, gr, col_dark, 1.0)

	# Battlements
	_draw_merlons(from, to, perp)


func _draw_brick_lines(face: PackedVector2Array) -> void:
	if face.size() < 4:
		return

	var seed_base = face[0].x * 31.0 + face[0].y * 17.0

	for row in range(4):
		var t_top = row / 4.0
		var t_bot = (row + 1) / 4.0
		var tl = face[3].lerp(face[0], t_top)
		var tr = face[2].lerp(face[1], t_top)
		var bl = face[3].lerp(face[0], t_bot)
		var br = face[2].lerp(face[1], t_bot)

		# Generate random vertical splits for this row
		var seed_v = seed_base + float(row) * 53.0
		var splits: Array[float] = [0.0]
		for j in range(3):
			var ct = fmod(abs(sin(seed_v + float(j) * 97.0) * 999.0), 0.7) + 0.15
			splits.append(ct)
		splits.append(1.0)
		splits.sort()

		# Draw each brick with slight color variation
		for b in range(splits.size() - 1):
			var left_t = splits[b]
			var right_t = splits[b + 1]

			var brick_tl = tl.lerp(tr, left_t)
			var brick_tr = tl.lerp(tr, right_t)
			var brick_bl = bl.lerp(br, left_t)
			var brick_br = bl.lerp(br, right_t)

			# Random brightness per brick
			var brick_seed = seed_v + float(b) * 71.0
			var variation = fmod(abs(sin(brick_seed) * 999.0), 1.0) * 0.12 - 0.06
			var brick_col = Color(
				col_front.r + variation,
				col_front.g + variation,
				col_front.b + variation,
				col_front.a
			)
			_poly(PackedVector2Array([brick_tl, brick_tr, brick_br, brick_bl]), brick_col)

		# Horizontal line between rows
		if row > 0:
			_line(tl, tr, col_brick, 1.0)

		# Vertical joint lines
		for b in range(1, splits.size() - 1):
			var st = splits[b]
			_line(tl.lerp(tr, st), bl.lerp(br, st), col_brick, 1.0)


func _draw_merlons(from: Vector2, to: Vector2, perp: Vector2) -> void:
	var dist = from.distance_to(to)
	var count = int(dist / (CELL_SIZE * 0.3))
	if count < 1:
		count = 1

	var dir = (to - from).normalized()
	var mw = 3.0  # merlon half-width along wall
	var mh = 5.0  # merlon height
	var md = 2.0  # merlon iso depth

	for i in range(count):
		var t = (i + 0.5) / count
		var base = from.lerp(to, t) + Vector2(0, -WALL_HEIGHT)

		# Isometric merlon block
		var along = dir * mw
		var depth = perp.normalized() * md

		# Top face (diamond)
		var m_top = PackedVector2Array([
			base - along + Vector2(0, -mh),          # back
			base + depth + Vector2(0, -mh),           # right
			base + along + Vector2(0, -mh),           # front
			base - depth + Vector2(0, -mh),           # left
		])

		# Front-right face
		var m_fr = PackedVector2Array([
			base + depth + Vector2(0, -mh),
			base + along + Vector2(0, -mh),
			base + along,
			base + depth,
		])

		# Front-left face
		var m_fl = PackedVector2Array([
			base - along + Vector2(0, -mh),
			base + depth + Vector2(0, -mh),
			base + depth,
			base - along,
		])

		_poly(m_fl, col_front)
		_poly(m_fr, col_side)
		_poly(m_top, col_highlight)

		for pts in [m_top, m_fr, m_fl]:
			for j in range(pts.size()):
				_line(pts[j], pts[(j + 1) % pts.size()], col_dark, 1.0)


func _draw_pillar(pos: Vector2) -> void:
	pos += Vector2(0, 4)  # shift down
	var r = WALL_THICK + 2.0
	var h = WALL_HEIGHT + 14
	var segments = 12

	# Cylinder body (front half visible) with brick lines
	var brick_rows = 6
	var row_height = h / brick_rows

	for i in range(segments):
		var a1 = PI * i / segments
		var a2 = PI * (i + 1) / segments
		var x1 = cos(a1) * r
		var y1 = sin(a1) * r * 0.5
		var x2 = cos(a2) * r
		var y2 = sin(a2) * r * 0.5

		# Shade based on angle
		var shade = lerpf(0.0, 1.0, float(i) / segments)
		var col = col_front.lerp(col_side, shade)

		# Draw each brick row as a separate strip
		for row in range(brick_rows):
			var top_y = row * row_height
			var bot_y = (row + 1) * row_height
			var strip = PackedVector2Array([
				pos + Vector2(x1, y1 - h + top_y),
				pos + Vector2(x2, y2 - h + top_y),
				pos + Vector2(x2, y2 - h + bot_y),
				pos + Vector2(x1, y1 - h + bot_y),
			])
			_poly(strip, col)

			# Horizontal brick line
			_line(
				pos + Vector2(x1, y1 - h + bot_y),
				pos + Vector2(x2, y2 - h + bot_y),
				col_brick, 1.0
			)

		# Vertical brick joint (offset every other row)
		for row in range(brick_rows):
			var joint_y = row * row_height + row_height * 0.5
			var offset_seg = (i + (1 if row % 2 == 0 else 0)) % 2
			if offset_seg == 0:
				var jx = (x1 + x2) * 0.5
				var jy = (y1 + y2) * 0.5
				_line(
					pos + Vector2(jx, jy - h + row * row_height),
					pos + Vector2(jx, jy - h + (row + 1) * row_height),
					col_brick, 1.0
				)

	# Top ellipse
	var top_points = PackedVector2Array()
	for i in range(segments * 2):
		var a = TAU * i / (segments * 2)
		top_points.append(pos + Vector2(cos(a) * r, sin(a) * r * 0.5 - h))
	_poly(top_points, col_highlight)
	for i in range(top_points.size()):
		_line(top_points[i], top_points[(i + 1) % top_points.size()], col_dark, 1.0)

	# One isometric merlon on top center (same style as wall merlons)
	var mw = 4.0
	var mh = 6.0
	var md = 3.0
	var mbase = pos + Vector2(0, -h)

	var m_top = PackedVector2Array([
		mbase + Vector2(0, -mh - md * 0.5),
		mbase + Vector2(mw, -mh),
		mbase + Vector2(0, -mh + md * 0.5),
		mbase + Vector2(-mw, -mh),
	])
	var m_fl = PackedVector2Array([
		mbase + Vector2(-mw, -mh),
		mbase + Vector2(0, -mh + md * 0.5),
		mbase + Vector2(0, md * 0.5),
		mbase + Vector2(-mw, 0),
	])
	var m_fr = PackedVector2Array([
		mbase + Vector2(0, -mh + md * 0.5),
		mbase + Vector2(mw, -mh),
		mbase + Vector2(mw, 0),
		mbase + Vector2(0, md * 0.5),
	])

	_poly(m_fl, col_front)
	_poly(m_fr, col_side)
	_poly(m_top, col_highlight)
	for pts in [m_top, m_fl, m_fr]:
		for j in range(pts.size()):
			_line(pts[j], pts[(j + 1) % pts.size()], col_dark, 1.0)

	# Bottom ellipse outline (front half only)
	for i in range(segments):
		var a1 = PI * i / segments
		var a2 = PI * (i + 1) / segments
		_line(
			pos + Vector2(cos(a1) * r, sin(a1) * r * 0.5),
			pos + Vector2(cos(a2) * r, sin(a2) * r * 0.5),
			col_dark, 1.0
		)

	# Side outlines
	_line(pos + Vector2(-r, -h), pos + Vector2(-r, 0), col_dark, 1.0)
	_line(pos + Vector2(r, -h), pos + Vector2(r, 0), col_dark, 1.0)
