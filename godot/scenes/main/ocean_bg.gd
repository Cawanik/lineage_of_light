# ==========================================
# ocean_bg.gd — Анимированный океан за картой
# ==========================================
# Загружает фреймы из папки и тайлит по всей видимой области
# Каждый тайл стартует с рандомного фрейма — живое море
# Рисуется ПОД основным Ground слоем
# ==========================================

@tool
class_name OceanBG
extends Node2D

@export var ocean_frames: Array[Texture2D] = []:
	set(v):
		ocean_frames = v
		_reload()
@export var fill_radius: int = 40:
	set(v):
		fill_radius = v
		_generate_offsets()
		queue_redraw()
@export var fps: float = 4.0:
	set(v):
		fps = v
@export var tile_size: Vector2i = Vector2i(64, 32)
@export var tile_offset: Vector2 = Vector2(0, 0):
	set(v):
		tile_offset = v
		queue_redraw()
@export var camera_limit_padding: int = 50:
	set(v):
		camera_limit_padding = v
		if not Engine.is_editor_hint():
			_setup_camera_limits()

var _initialized: bool = false
var _frames: Array[Texture2D] = []
var _elapsed: float = 0.0
var _tile_time_offsets: Dictionary = {}
var _tile_frame_offsets: Dictionary = {}
var _redraw_accumulator: float = 0.0
const REDRAW_FPS: float = 60.0


func _ready() -> void:
	z_index = -100
	_initialized = true
	_reload()
	_generate_offsets()
	if not Engine.is_editor_hint():
		call_deferred("_setup_camera_limits")


func _setup_camera_limits() -> void:
	if not is_inside_tree():
		return
	var camera = get_tree().current_scene.get_node_or_null("YSort/Player/Camera2D") as Camera2D
	if not camera:
		return

	var hw = tile_size.x * 0.5
	var hh = tile_size.y * 0.5
	var pixel_w = fill_radius * hw
	var pixel_h = fill_radius * hh

	# Лимиты камеры обновляются динамически в _update_camera_limits_for_zoom()

	# Рассчитываем zoom_min: описываем прямоугольник экрана вокруг ромба
	# Ромб с полудиагоналями W (гориз) и H (верт)
	# Стороны ромба: уравнение x/W + y/H = 1
	# Описанный прямоугольник с пропорцией r = vw/vh касается всех 4 сторон
	# Полуширина a, полувысота b, a = r*b
	# Точка касания на стороне ромба: a/W + b/H = 1
	# r*b/W + b/H = 1 → b = W*H / (r*H + W)
	# Но это ВПИСАННЫЙ. Для ОПИСАННОГО нужно наоборот:
	# Ромб вписан в прямоугольник → a = W, b = H (прямоугольник по вершинам)
	# Но экран не квадратный, нужен с пропорцией r
	# Описанный прямоугольник с пропорцией r вокруг ромба:
	# Нужно чтобы весь ромб помещался → a >= W и b >= H
	# С пропорцией r=a/b: если a=W то b=W/r, нужно b>=H → W/r >= H → ok если W/r >= H
	# Иначе b=H, a=r*H, нужно a>=W → r*H >= W
	# Углы камеры должны быть ВНУТРИ ромба океана
	# Ромб полудиагонали: W = (2*R-1)*hw, H = (2*R-1)*hh
	# Условие: vw/(2*Z*W) + vh/(2*Z*H) <= 1
	# => Z >= vw/(2*W) + vh/(2*H)
	var diamond_w = (2.0 * fill_radius - 1.0) * hw
	var diamond_h = (2.0 * fill_radius - 1.0) * hh
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom_min = viewport_size.x / (2.0 * diamond_w) + viewport_size.y / (2.0 * diamond_h)

	var player = get_tree().current_scene.get_node_or_null("YSort/Player") as Player
	if player:
		player.zoom_min = zoom_min



func _update_camera_limits_for_zoom() -> void:
	if not is_inside_tree():
		return
	var camera = get_tree().current_scene.get_node_or_null("YSort/Player/Camera2D") as Camera2D
	if not camera:
		return

	var hw = tile_size.x * 0.5
	var hh = tile_size.y * 0.5
	var diamond_w = (2.0 * fill_radius - 1.0) * hw
	var diamond_h = (2.0 * fill_radius - 1.0) * hh
	var viewport_size = get_viewport().get_visible_rect().size
	var z = camera.zoom.x

	# При текущем зуме камера видит эту область
	var half_view_w = viewport_size.x / (2.0 * z)
	var half_view_h = viewport_size.y / (2.0 * z)

	# Максимальное перемещение камеры чтобы углы viewport оставались в ромбе
	# |cx + half_view_w| / diamond_w + |cy + half_view_h| / diamond_h <= 1
	# Упрощаем: max_cx = diamond_w * (1 - half_view_h/diamond_h) - half_view_w
	var max_move_x = diamond_w - half_view_w - diamond_w * half_view_h / diamond_h
	var max_move_y = diamond_h - half_view_h - diamond_h * half_view_w / diamond_w

	if max_move_x < 0:
		max_move_x = 0
	if max_move_y < 0:
		max_move_y = 0

	camera.limit_left = int(position.x - max_move_x)
	camera.limit_right = int(position.x + max_move_x)
	camera.limit_top = int(position.y - max_move_y)
	camera.limit_bottom = int(position.y + max_move_y)


func _generate_offsets() -> void:
	if _tile_frame_offsets == null:
		_tile_frame_offsets = {}
	if _tile_time_offsets == null:
		_tile_time_offsets = {}
	_tile_frame_offsets.clear()
	_tile_time_offsets.clear()
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	for y in range(-fill_radius, fill_radius):
		for x in range(-fill_radius, fill_radius):
			var key = Vector2i(x, y)
			_tile_frame_offsets[key] = rng.randi()
			_tile_time_offsets[key] = rng.randf()  # 0..1 сдвиг внутри фрейма


func _reload() -> void:
	_frames.clear()
	for tex in ocean_frames:
		if tex:
			_frames.append(tex)
	queue_redraw()


func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_elapsed += delta
	_redraw_accumulator += delta
	# Перерисовываем максимум REDRAW_FPS раз в секунду
	if _redraw_accumulator >= 1.0 / REDRAW_FPS:
		_redraw_accumulator = 0.0
		queue_redraw()

	if not Engine.is_editor_hint():
		_update_camera_limits_for_zoom()


func _get_visible_rect_local() -> Rect2:
	var vp = get_viewport()
	var vp_size = vp.get_visible_rect().size
	# Берём реальную трансформацию viewport — учитывает камеру, zoom и любые офсеты
	var inv = vp.get_canvas_transform().affine_inverse()
	var world_tl = inv * Vector2.ZERO
	var world_br = inv * vp_size
	# Переводим в локальное пространство ноды
	var local_tl = to_local(world_tl)
	var local_br = to_local(world_br)
	return Rect2(local_tl, local_br - local_tl)


func _draw() -> void:
	if _frames.is_empty():
		return
	if not _initialized:
		return

	var frame_count = _frames.size()
	var hw = tile_size.x * 0.5
	var hh = tile_size.y * 0.5
	var frame_duration = 1.0 / fps

	# Считаем видимую область один раз перед циклом
	var vis := _get_visible_rect_local()
	var margin_x = tile_size.x
	var margin_y = tile_size.y

	for y in range(-fill_radius, fill_radius):
		for x in range(-fill_radius, fill_radius):
			var screen_x = (x - y) * hw
			var screen_y = (x + y) * hh

			# Пропускаем тайлы за экраном
			if screen_x + margin_x < vis.position.x or screen_x - margin_x > vis.position.x + vis.size.x:
				continue
			if screen_y + margin_y < vis.position.y or screen_y - margin_y > vis.position.y + vis.size.y:
				continue

			var tile_key = Vector2i(x, y)
			var f_offset = _tile_frame_offsets[tile_key] if _tile_frame_offsets.has(tile_key) else 0
			var t_offset = _tile_time_offsets[tile_key] if _tile_time_offsets.has(tile_key) else 0.0
			var tile_time = _elapsed + t_offset * frame_duration * frame_count
			var frame_idx = (int(tile_time / frame_duration) + f_offset) % frame_count
			var tex = _frames[frame_idx]

			var draw_pos = Vector2(
				screen_x - tex.get_width() * 0.5 + tile_offset.x,
				screen_y - tex.get_height() * 0.5 + tile_offset.y
			)
			draw_texture(tex, draw_pos)
