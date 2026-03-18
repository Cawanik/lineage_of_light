# ==========================================
# occlusion_fade.gd — Затухание объектов перед игроком
# ==========================================
# find_player(tree) — ищет Player в YSort, запоминает ссылку
# should_fade(object_world_pos) — проверяет, надо ли эту хуйню
#   делать прозрачной (объект ближе к камере и закрывает игрока)
# update_node_fade(node) — делает ноду полупрозрачной или возвращает
#   обратно, чтоб игрока было видно, блять
# ==========================================

class_name OcclusionFade
extends RefCounted

## Fades buildings/walls to transparent when player is behind them
## "Behind" = object's Y > player's Y (object closer to camera, blocking player)

static var player: Node2D = null
static var fade_radius: float = 50.0
static var fade_alpha: float = 0.5
static var build_mode_cursor: Vector2 = Vector2.ZERO
static var build_mode_active: bool = false


static func find_player(tree: SceneTree) -> void:
	if player != null:
		return
	var scene = tree.current_scene
	if scene == null:
		return
	# Search in YSort
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

	if build_mode_active:
		var cdiff_y = object_world_pos.y - build_mode_cursor.y
		var cdiff_x = absf(object_world_pos.x - build_mode_cursor.x)
		var cursor_fade = cdiff_y > 0 and cdiff_y < fade_radius and cdiff_x < fade_radius
		return player_fade or cursor_fade

	return player_fade


static func update_node_fade(node: Node2D) -> void:
	var target = fade_alpha if should_fade(node.global_position) else 1.0
	if node.modulate.a != target:
		node.modulate.a = target
