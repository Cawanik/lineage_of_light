# ==========================================
# wall_system.gd — Ёбаная система стен в стиле AoE, процедурная нахуй
# ==========================================
# _poly(points, color) — рисует полигон на текущем WallDrawNode, хуле
# _line(from, to, color, width) — рисует линию на текущем WallDrawNode
# _ready() — включает y_sort, грузит конфиг, находит BuildingGrid
# _load_config() — тащит все настройки стен из конфига: размеры, цвета, офсеты, вся хуйня
# _process(_delta) — каждый кадр: ребилд если надо, прозрачность, превью для build/demolish/move
# _make_edge_key(a, b) — делает уникальный ключ для ребра между двумя нодами, сортирует чтоб не ебаться с порядком
# place_wall_between(a, b) — ставит стену между двумя точками, создаёт коллизию, помечает на ребилд
# _create_collision(key, a, b) — создаёт StaticBody2D с прямоугольной коллизией вдоль стены
# place_wall_line(from, to) — строит линию стен от точки до точки, сука удобно
# remove_wall_between(a, b) — удаляет стену между точками, чистит осиротевшие ноды
# _node_has_edges(node) — проверяет, есть ли хоть одно ребро у ноды
# _get_neighbors(pos) — возвращает 8 соседей (кардинальные + диагональные), ёпт
# _node_edge_count(node) — считает сколько рёбер у ноды, пиздец простая функция
# grid_to_world(grid_pos) — конвертит координаты сетки в мировые, через BuildingGrid если есть
# world_to_grid(world_pos) — обратная конвертация, из мировых в сетку
# _get_ysort() — возвращает родителя (YSort), нахуй
# _update_demolish_hover() — подсвечивает ближайшую ноду при наведении в режиме сноса
# _set_node_highlight(node_pos, highlighted, color) — красит ноду и все подключённые стены
# demolish_hovered() — сносит подсвеченную ноду со всеми стенами, ёбаный бульдозер
# clear_demolish_mode() — выключает режим сноса, убирает подсветку
# _update_build_preview() — обновляет превью строительства по позиции мыши
# _redraw_build_preview() — перерисовывает превью: столб + стены к соседям, зелёное/жёлтое
# place_at_preview() — ставит ноду и соединяет стенами с соседями, хуяк и готово
# clear_build_mode() — выключает режим строительства, чистит превью
# _update_move_preview() — обновляет превью перемещения: фаза select или place
# _redraw_move_preview() — рисует синее превью столба и стен на новой позиции
# move_select() — фаза 1: выбираем ноду для перемещения
# move_place() — фаза 2: перемещаем ноду на новое место, переподключаем стены
# clear_move_mode() — выключает режим перемещения, чистит всё нахуй
# toggle_adjust() — дебаг: включает режим подгонки офсетов стен/столбов стрелками
# _update_adjust() — заглушка для дебаг-апдейта, пустая нахер
# _input(event) — обрабатывает клавиши в adjust-режиме: Tab переключает wall/pillar, стрелки двигают
# _apply_adjust(delta) — применяет дельту к офсету wall или pillar
# _update_transparency() — обновляет прозрачность стен/столбов рядом с игроком
# _rebuild_visuals() — перестраивает все визуальные ноды стен и столбов с нуля, жёстко
# _draw_wall_edge(from, to) — рисует сегмент стены: фасад, бока, верх, кирпичи, мерлоны — вся ебатория
# _draw_brick_lines(face) — рисует кирпичную кладку на фасаде стены, процедурно, сука красиво
# _draw_merlons(from, to, perp) — рисует зубцы (мерлоны) сверху стены, как в замке, блять
# _draw_pillar(pos) — рисует цилиндрический столб с кирпичами и мерлоном наверху, ебаный арт
# ==========================================

class_name WallSystem
extends Node2D

## AoE-style wall system
## Walls are edges between grid nodes, not nodes themselves
## Click two adjacent nodes to build a wall segment between them

signal wall_segment_destroyed(edge_key: StringName)

var CELL_SIZE: int = 64
var ISO_RATIO: float = 0.5
var WALL_HEIGHT: float = 28.0
var WALL_THICK: float = 6.0
var WALL_SEGMENT_HP: float = 100.0

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
# Edge HP: StringName -> float
var edge_hp: Dictionary = {}
# Collision bodies: StringName -> StaticBody2D
var collision_bodies: Dictionary = {}
# Visual child nodes
var visual_nodes: Array[Node2D] = []
var _needs_rebuild: bool = false
var _target: WallDrawNode = null
var building_grid: BuildingGrid = null
var _adjust_mode: bool = false
var _adjust_target: String = "wall"  # "wall" or "pillar"
# Visual lookup: edge_key -> WallDrawNode, node Vector2i -> WallDrawNode
var wall_visuals: Dictionary = {}   # StringName -> WallDrawNode
var pillar_visuals: Dictionary = {} # Vector2i -> WallDrawNode
var FADE_RADIUS: float = 50.0
var DEMOLISH_SNAP_RADIUS: float = 16.0
var wall_offset: Vector2 = Vector2.ZERO
var pillar_offset: Vector2 = Vector2.ZERO

var demolish_mode: bool = false
var hovered_node: Vector2i = Vector2i(-9999, -9999)

var build_mode: bool = false
var build_preview_node: Vector2i = Vector2i(-9999, -9999)
var build_preview_draw: Node2D = null

var move_mode: bool = false
var move_selected_node: Vector2i = Vector2i(-9999, -9999)
var move_preview_node: Vector2i = Vector2i(-9999, -9999)
var move_phase: String = "select"  # "select" or "place"


func _poly(points: PackedVector2Array, color: Color) -> void:
	if _target:
		_target.add_polygon(points, color)


func _line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	if _target:
		_target.add_line(from, to, color, width)


func _ready() -> void:
	y_sort_enabled = true
	_load_config()
	# Find BuildingGrid sibling
	await get_tree().process_frame
	var parent = get_parent()
	if parent:
		building_grid = parent.get_node_or_null("BuildingGrid")


func _load_config() -> void:
	var iso = Config.game.get("iso", {})
	CELL_SIZE = iso.get("cell_size", 64)
	ISO_RATIO = iso.get("iso_ratio", 0.5)

	var w = Config.buildings.get("wall", {})
	WALL_HEIGHT = w.get("height", 28.0)
	WALL_THICK = w.get("thickness", 6.0)
	WALL_SEGMENT_HP = w.get("hp", 100.0)
	FADE_RADIUS = w.get("fade_radius", 50.0)
	OcclusionFade.fade_radius = FADE_RADIUS
	OcclusionFade.fade_alpha = w.get("transparency_alpha", 0.5)
	DEMOLISH_SNAP_RADIUS = w.get("demolish_snap_radius", 16.0)
	var wo = w.get("wall_offset", [0.0, 0.0])
	wall_offset = Vector2(wo[0], wo[1])
	var po = w.get("pillar_offset", [0.0, 0.0])
	pillar_offset = Vector2(po[0], po[1])

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
	if move_mode:
		_update_move_preview()
	if _adjust_mode:
		_update_adjust()


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
	edge_hp[key] = WALL_SEGMENT_HP
	nodes[a] = true
	nodes[b] = true
	_create_collision(key, a, b)
	
	print("WallSystem: Created wall edge %s between %s and %s" % [key, a, b])
	
	if Engine.has_singleton("PathfindingSystem") or get_node_or_null("/root/PathfindingSystem"):
		var ps = get_node_or_null("/root/PathfindingSystem")
		if ps:
			ps.disable_edge(a, b)
			print("WallSystem: Disabled pathfinding edge %s" % key)
	
	_needs_rebuild = true
	print("WallSystem: Total edges now: %d" % edges.size())


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
	edge_hp.erase(key)
	if collision_bodies.has(key):
		collision_bodies[key].queue_free()
		collision_bodies.erase(key)
	var ps = get_node_or_null("/root/PathfindingSystem")
	if ps:
		ps.enable_edge(a, b)
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
	if building_grid:
		return building_grid.tile_to_world(grid_pos)
	# Fallback
	var screen_x = float((grid_pos.x - grid_pos.y) * CELL_SIZE) * 0.5
	var screen_y = float((grid_pos.x + grid_pos.y) * CELL_SIZE) * ISO_RATIO * 0.5 + 15.0
	return Vector2(screen_x, screen_y)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	if building_grid:
		return building_grid.world_to_tile(world_pos)
	# Fallback
	var adjusted_y = world_pos.y - 15.0
	var fx = world_pos.x / (CELL_SIZE * 0.5)
	var fy = adjusted_y / (CELL_SIZE * ISO_RATIO * 0.5)
	return Vector2i(roundi((fx + fy) * 0.5), roundi((fy - fx) * 0.5))


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


func _set_node_highlight(node_pos: Vector2i, highlighted: bool, color: Color = Color(1.0, 0.3, 0.3)) -> void:
	if node_pos == Vector2i(-9999, -9999):
		return
	var tint = color if highlighted else Color.WHITE

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

	# Draw pillar preview (with pillar_offset)
	var ppos = wpos + pillar_offset
	var pillar_wdn = WallDrawNode.new()
	pillar_wdn.position = Vector2(ppos.x, ppos.y + 0.5)
	pillar_wdn.z_index = 100
	pillar_wdn.modulate = Color(0.4, 1.0, 0.4, 0.7) if not already_exists else Color(1.0, 1.0, 0.4, 0.5)
	_target = pillar_wdn
	_draw_pillar(Vector2(0, -0.5))
	_target = null
	build_preview_draw.add_child(pillar_wdn)

	# Draw wall previews to adjacent existing nodes (with wall_offset)
	var cardinal = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir in cardinal:
		var neighbor = pos + dir
		if nodes.has(neighbor):
			var key = _make_edge_key(pos, neighbor)
			var edge_exists = edges.has(key)

			var nwpos = grid_to_world(neighbor)
			var draw_from = wpos + wall_offset
			var draw_to = nwpos + wall_offset
			# Shrink at upper end
			var shrink = 5.0
			if draw_from.y < draw_to.y:
				draw_from = wpos + wall_offset + (nwpos - wpos).normalized() * shrink
			elif draw_to.y < draw_from.y:
				draw_to = nwpos + wall_offset + (wpos - nwpos).normalized() * shrink

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


# === MOVE MODE ===

func _update_move_preview() -> void:
	var mouse_pos = get_global_mouse_position()

	if move_phase == "select":
		# Highlight nearest existing node
		var closest = Vector2i(-9999, -9999)
		var closest_dist = DEMOLISH_SNAP_RADIUS
		for node_pos in nodes:
			var wpos = grid_to_world(node_pos)
			var dist = mouse_pos.distance_to(wpos)
			if dist < closest_dist:
				closest_dist = dist
				closest = node_pos

		if closest != move_selected_node:
			_set_node_highlight(move_selected_node, false)
			move_selected_node = closest
			if move_selected_node != Vector2i(-9999, -9999):
				_set_node_highlight(move_selected_node, true, Color(0.3, 0.5, 1.0))

	elif move_phase == "place":
		# Show build preview at new location
		var grid_pos = world_to_grid(mouse_pos)
		if grid_pos != move_preview_node:
			move_preview_node = grid_pos
			_redraw_move_preview()


func _redraw_move_preview() -> void:
	if is_instance_valid(build_preview_draw):
		build_preview_draw.queue_free()

	build_preview_draw = Node2D.new()
	get_tree().current_scene.add_child(build_preview_draw)

	var wpos = grid_to_world(move_preview_node)

	# Draw pillar preview at target (with pillar_offset)
	var ppos = wpos + pillar_offset
	var pillar_wdn = WallDrawNode.new()
	pillar_wdn.position = Vector2(ppos.x, ppos.y + 0.5)
	pillar_wdn.z_index = 100
	pillar_wdn.modulate = Color(0.4, 0.6, 1.0, 0.7)  # blue tint for move
	_target = pillar_wdn
	_draw_pillar(Vector2(0, -0.5))
	_target = null
	build_preview_draw.add_child(pillar_wdn)

	# Draw wall previews to adjacent existing nodes (excluding the one being moved, with wall_offset)
	var cardinal = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir in cardinal:
		var neighbor = move_preview_node + dir
		if nodes.has(neighbor) and neighbor != move_selected_node:
			var nwpos = grid_to_world(neighbor)
			var draw_from = wpos + wall_offset
			var draw_to = nwpos + wall_offset
			var shrink = 5.0
			if draw_from.y < draw_to.y:
				draw_from = wpos + wall_offset + (nwpos - wpos).normalized() * shrink
			elif draw_to.y < draw_from.y:
				draw_to = nwpos + wall_offset + (wpos - nwpos).normalized() * shrink

			var wall_wdn = WallDrawNode.new()
			var sort_y = minf(draw_from.y, draw_to.y)
			wall_wdn.position = Vector2(0, sort_y)
			wall_wdn.z_index = 99
			wall_wdn.modulate = Color(0.4, 0.6, 1.0, 0.5)
			_target = wall_wdn
			_draw_wall_edge(draw_from - wall_wdn.position, draw_to - wall_wdn.position)
			_target = null
			build_preview_draw.add_child(wall_wdn)


func move_select() -> void:
	## Phase 1: select a node to move
	if move_selected_node == Vector2i(-9999, -9999):
		return
	# Keep selected node highlighted light blue
	_set_node_highlight(move_selected_node, true, Color(0.5, 0.7, 1.0))
	move_phase = "place"


func move_place() -> void:
	## Phase 2: place the node at new location
	if move_preview_node == Vector2i(-9999, -9999) or move_selected_node == Vector2i(-9999, -9999):
		return
	if nodes.has(move_preview_node):
		return  # can't place on existing node

	var old_pos = move_selected_node
	var new_pos = move_preview_node

	# Collect old edges
	var old_neighbors: Array[Vector2i] = []
	for neighbor in _get_neighbors(old_pos):
		if edges.has(_make_edge_key(old_pos, neighbor)):
			old_neighbors.append(neighbor)

	# Remove old node and edges
	for neighbor in old_neighbors:
		var key = _make_edge_key(old_pos, neighbor)
		edges.erase(key)
		if collision_bodies.has(key):
			collision_bodies[key].queue_free()
			collision_bodies.erase(key)
	nodes.erase(old_pos)

	# Place new node
	nodes[new_pos] = true

	# Connect to adjacent existing nodes at new position
	var cardinal = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir in cardinal:
		var neighbor = new_pos + dir
		if nodes.has(neighbor):
			place_wall_between(new_pos, neighbor)

	# Reset move state
	move_phase = "select"
	move_selected_node = Vector2i(-9999, -9999)
	move_preview_node = Vector2i(-9999, -9999)
	if is_instance_valid(build_preview_draw):
		build_preview_draw.queue_free()
		build_preview_draw = null

	_needs_rebuild = true


func clear_move_mode() -> void:
	_set_node_highlight(move_selected_node, false)
	move_mode = false
	move_phase = "select"
	move_selected_node = Vector2i(-9999, -9999)
	move_preview_node = Vector2i(-9999, -9999)
	if is_instance_valid(build_preview_draw):
		build_preview_draw.queue_free()
		build_preview_draw = null


# === WALL DAMAGE ===

func damage_wall_edge(key: StringName, damage: float) -> bool:
	if not edge_hp.has(key):
		return false
	edge_hp[key] -= damage
	_update_wall_visual_damage(key)
	if edge_hp[key] <= 0:
		var parts = str(key).split("-")
		var a_parts = parts[0].split(",")
		var b_parts = parts[1].split(",")
		var a = Vector2i(int(a_parts[0]), int(a_parts[1]))
		var b = Vector2i(int(b_parts[0]), int(b_parts[1]))
		remove_wall_between(a, b)
		wall_segment_destroyed.emit(key)
		return true
	return false


func get_wall_hp(key: StringName) -> float:
	return edge_hp.get(key, 0.0)


func get_wall_hp_ratio(key: StringName) -> float:
	if not edge_hp.has(key):
		return 0.0
	return edge_hp[key] / WALL_SEGMENT_HP


func _update_wall_visual_damage(key: StringName) -> void:
	if not wall_visuals.has(key) or not is_instance_valid(wall_visuals[key]):
		return
	var ratio = get_wall_hp_ratio(key)
	var tint = Color.WHITE.lerp(Color(1.0, 0.3, 0.3), 1.0 - ratio)
	wall_visuals[key].self_modulate = tint


# === ADJUST MODE (debug) ===

func toggle_adjust() -> void:
	_adjust_mode = not _adjust_mode
	if _adjust_mode:
		print("[WallAdjust] ON — Tab to switch wall/pillar, Arrows to move, Enter to print")
	else:
		print("[WallAdjust] OFF")


func _update_adjust() -> void:
	pass


func _input(event: InputEvent) -> void:
	if not _adjust_mode:
		return
	if not (event is InputEventKey and event.pressed):
		return

	var s = 1.0 if not event.shift_pressed else 5.0

	match event.keycode:
		KEY_TAB:
			_adjust_target = "pillar" if _adjust_target == "wall" else "wall"
			print("[WallAdjust] target: %s | wall=%s pillar=%s" % [_adjust_target, wall_offset, pillar_offset])
		KEY_UP:
			_apply_adjust(Vector2(0, -s))
		KEY_DOWN:
			_apply_adjust(Vector2(0, s))
		KEY_LEFT:
			_apply_adjust(Vector2(-s, 0))
		KEY_RIGHT:
			_apply_adjust(Vector2(s, 0))
		KEY_ENTER:
			print("[WallAdjust] \"wall_offset\": [%.1f, %.1f]" % [wall_offset.x, wall_offset.y])
			print("[WallAdjust] \"pillar_offset\": [%.1f, %.1f]" % [pillar_offset.x, pillar_offset.y])


func _apply_adjust(delta: Vector2) -> void:
	if _adjust_target == "wall":
		wall_offset += delta
	else:
		pillar_offset += delta
	_needs_rebuild = true
	print("[WallAdjust] %s offset: %s" % [_adjust_target, wall_offset if _adjust_target == "wall" else pillar_offset])


func _update_transparency() -> void:
	OcclusionFade.find_player(get_tree())

	# Find which nodes are close to player
	var fade_nodes: Dictionary = {}
	for node_pos in nodes:
		var wpos = grid_to_world(node_pos)
		if OcclusionFade.should_fade(wpos):
			fade_nodes[node_pos] = true

	# Apply transparency to pillars
	for node_pos in pillar_visuals:
		var wdn: WallDrawNode = pillar_visuals[node_pos]
		if is_instance_valid(wdn):
			wdn.modulate.a = OcclusionFade.fade_alpha if fade_nodes.has(node_pos) else 1.0

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
		wdn.modulate.a = OcclusionFade.fade_alpha if should_fade else 1.0


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
		var wa = grid_to_world(a) + wall_offset
		var wb = grid_to_world(b) + wall_offset

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
			var wpos = grid_to_world(node_pos) + pillar_offset
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
