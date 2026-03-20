# ==========================================
# occlusion_fade.gd — Затухание объектов перед игроком и курсором
# ==========================================
# find_player(tree) — ищет Player в YSort
# should_fade(object_world_pos) — надо ли фейдить
# is_under_cursor(object_world_pos) — объект прямо под курсором
# update_node_fade(node) — обновляет прозрачность ноды
# ==========================================

class_name OcclusionFade
extends RefCounted

static var player: Node2D = null
static var fade_radius: float = 50.0
static var fade_alpha: float = 0.2
static var cursor_pos: Vector2 = Vector2.ZERO
static var cursor_fade_active: bool = true
static var cursor_fade_radius: float = 80.0
static var cursor_highlight_radius: float = 20.0
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


static func should_fade(object_world_pos: Vector2) -> bool:
	if player == null:
		return false
	var diff_y = object_world_pos.y - player.position.y
	var diff_x = absf(object_world_pos.x - player.position.x)
	var player_fade = diff_y > 0 and diff_y < fade_radius and diff_x < fade_radius

	if cursor_fade_active:
		var cdiff_y = object_world_pos.y - cursor_pos.y
		var cdiff_x = absf(object_world_pos.x - cursor_pos.x)
		var cursor_fade = cdiff_y > 0 and cdiff_y < cursor_fade_radius and cdiff_x < cursor_fade_radius
		return player_fade or cursor_fade

	return player_fade


static func is_under_cursor(object_world_pos: Vector2) -> bool:
	var dx = absf(object_world_pos.x - cursor_pos.x)
	var dy = absf(object_world_pos.y - cursor_pos.y)
	return dx < cursor_highlight_radius and dy < cursor_highlight_radius


static func update_node_fade(node: Node2D) -> void:
	if focus_mode:
		return
	var pos = node.global_position
	if is_under_cursor(pos):
		if node.modulate.a != 1.0:
			node.modulate.a = 1.0
	elif should_fade(pos):
		if node.modulate.a != fade_alpha:
			node.modulate.a = fade_alpha
	else:
		if node.modulate.a != 1.0:
			node.modulate.a = 1.0
