# ==========================================
# occlusion_fade.gd — Затухание зданий, перекрывающих игрока/врагов/курсор
# ==========================================
# Каждое здание имеет occlusion rect на основе спрайта.
# Игрок и враги — точки. Курсор — круг.
# Если точка/круг попадает в occlusion rect здания — оно фейдится.
# ==========================================

class_name OcclusionFade
extends RefCounted

static var player: Node2D = null
static var fade_alpha: float = 0.1
static var cursor_pos: Vector2 = Vector2.ZERO
static var cursor_radius: float = 40.0
static var focus_mode: bool = false


static func find_player(tree: SceneTree) -> void:
	if player != null:
		return
	var scene = tree.current_scene
	if scene == null:
		return
	var ysort = scene.get_node_or_null("YSort")
	if ysort:
		for child in ysort.get_children():
			if child is Player:
				player = child
				return


# Возвращает occlusion rect здания в мировых координатах
static func get_building_rect(building: Node2D) -> Rect2:
	var spr = building.get_node_or_null("Sprite2D") as Sprite2D
	if not spr or not spr.texture:
		return Rect2()
	var tex_size = spr.texture.get_size() * spr.scale
	var pos = building.global_position + spr.position
	# Sprite2D centered по умолчанию
	return Rect2(pos.x - tex_size.x * 0.5, pos.y - tex_size.y * 0.5, tex_size.x, tex_size.y)


# Проверяет, попадает ли точка в rect
static func _point_in_rect(point: Vector2, rect: Rect2) -> bool:
	return rect.has_point(point)


# Проверяет, пересекается ли круг с rect
static func _circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest_x = clampf(center.x, rect.position.x, rect.end.x)
	var closest_y = clampf(center.y, rect.position.y, rect.end.y)
	var dx = center.x - closest_x
	var dy = center.y - closest_y
	return (dx * dx + dy * dy) <= (radius * radius)


# Для стен — проверяет точку стены против игрока/курсора/врагов
static func should_fade(wall_world_pos: Vector2) -> bool:
	# Курсор точно на стене — не фейдим
	if cursor_pos.distance_to(wall_world_pos) < 15.0:
		return false

	# Игрок — точка рядом, только если выше стены
	if player and is_instance_valid(player):
		if player.global_position.y < wall_world_pos.y and player.global_position.distance_to(wall_world_pos) < 60.0:
			return true

	# Курсор — круг, только если центр выше стены
	if cursor_pos.y < wall_world_pos.y and cursor_pos.distance_to(wall_world_pos) < cursor_radius:
		return true

	# Враги — точки рядом, только если выше стены
	if player and player.get_tree():
		var enemies = player.get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.global_position.y < wall_world_pos.y and enemy.global_position.distance_to(wall_world_pos) < 60.0:
				return true

	return false


static func should_fade_building(building: Node2D) -> bool:
	var rect = get_building_rect(building)
	if rect.size == Vector2.ZERO:
		return false
	var building_y = building.global_position.y

	# Курсор точно на здании — не фейдим (игрок целится в него)
	if rect.has_point(cursor_pos):
		return false

	# Игрок — точка, только если выше здания (за ним)
	if player and is_instance_valid(player):
		if player.global_position.y < building_y and _point_in_rect(player.global_position, rect):
			return true

	# Курсор — круг, только если центр выше здания
	if cursor_pos.y < building_y and _circle_intersects_rect(cursor_pos, cursor_radius, rect):
		return true

	# Враги — точки, только если выше здания
	if player and player.get_tree():
		var enemies = player.get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.global_position.y < building_y and _point_in_rect(enemy.global_position, rect):
				return true

	return false


static func update_node_fade(node: Node2D) -> void:
	if focus_mode:
		return
	if should_fade_building(node):
		if node.modulate.a != fade_alpha:
			node.modulate.a = fade_alpha
	else:
		if node.modulate.a != 1.0:
			node.modulate.a = 1.0
