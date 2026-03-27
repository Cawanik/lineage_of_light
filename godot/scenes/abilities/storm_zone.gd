class_name StormZone
extends Node2D

const TILE_HW = 32.0
const TILE_HH = 16.0

var storm_tile: Vector2i = Vector2i(-1, -1)
var damage: float = 10.0
var duration: float = 5.0
var tick_interval: float = 0.5
var is_preview: bool = true
var grid_size: int = 1  # 1 = 1x1, 4 = 4x4

var _age: float = 0.0
var _tick_timer: float = 0.0
var _pulse: float = 0.0
var _tile_local_offsets: Array = []


func _ready() -> void:
	_rebuild_tile_data()


func _rebuild_tile_data() -> void:
	_tile_local_offsets.clear()
	var center_y = (grid_size - 1) * TILE_HH
	for y in range(grid_size):
		for x in range(grid_size):
			var world = Vector2((x - y) * TILE_HW, (x + y) * TILE_HH)
			_tile_local_offsets.append(world - Vector2(0.0, center_y))


var _lightning_player: AudioStreamPlayer = null

func activate() -> void:
	is_preview = false
	_age = 0.0
	_tick_timer = 0.0
	_start_lightning_sound()


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()

	if is_preview:
		return

	_age += delta
	_tick_timer += delta

	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_do_damage()

	if _age >= duration:
		_stop_lightning_sound()
		queue_free()


func _start_lightning_sound() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if not am:
		return
	var data = am.sounds.get("lightning_loop", {})
	var sound_path = data.get("path", "")
	if sound_path == "" or not ResourceLoader.exists(sound_path):
		return
	_lightning_player = AudioStreamPlayer.new()
	_lightning_player.stream = load(sound_path)
	_lightning_player.volume_db = linear_to_db(data.get("volume", 0.4) * am.sfx_volume * am.master_volume)
	_lightning_player.bus = "SFX"
	add_child(_lightning_player)
	_lightning_player.play()


func _stop_lightning_sound() -> void:
	if _lightning_player and is_instance_valid(_lightning_player):
		var tween = create_tween()
		tween.tween_property(_lightning_player, "volume_db", -40.0, 0.5)
		tween.tween_callback(_lightning_player.queue_free)


func _do_damage() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			var diff = e.get("current_tile") - storm_tile
			if diff.x >= 0 and diff.x < grid_size and diff.y >= 0 and diff.y < grid_size:
				e.take_damage(damage)


func _draw() -> void:
	var fade = 1.0 if is_preview else 1.0 - (_age / duration) * 0.4
	var base_a = 0.45 if is_preview else fade
	var pulse  = sin(_pulse * 5.0) * 0.15 + 0.85
	var pulse2 = sin(_pulse * 7.3 + 1.1) * 0.12 + 0.88

	# Размер зоны в экранных координатах
	var zone_rx = grid_size * TILE_HW
	var zone_ry = grid_size * TILE_HH

	# Свечение под всей зоной
	draw_circle(Vector2.ZERO, zone_rx * 1.05 * pulse,  Color(0.1,  0.25, 0.9,  0.10 * base_a))
	draw_circle(Vector2.ZERO, zone_rx * 0.7  * pulse2, Color(0.25, 0.5,  1.0,  0.15 * base_a))

	# Ромбы тайлов (яркость пульсирует)
	var border_col = Color(0.45, 0.7, 1.0, 0.6 * base_a)
	var fill_a = 0.13 * base_a * pulse
	for offset in _tile_local_offsets:
		var pts = PackedVector2Array([
			offset + Vector2(0, -TILE_HH),
			offset + Vector2(TILE_HW, 0),
			offset + Vector2(0,  TILE_HH),
			offset + Vector2(-TILE_HW, 0),
		])
		draw_colored_polygon(pts, Color(0.2, 0.45, 1.0, fill_a))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), border_col, 1.5)

	# Облако в центре — масштабируется с зоной
	var cloud_r = (7.0 + grid_size * 5.0) * pulse
	draw_circle(Vector2.ZERO, cloud_r + 6.0, Color(0.3, 0.55, 1.0, 0.22 * base_a))
	draw_circle(Vector2.ZERO, cloud_r,        Color(0.65, 0.83, 1.0, 0.7  * base_a))
	draw_circle(Vector2.ZERO, cloud_r * 0.38, Color(0.93, 0.97, 1.0, 0.9  * base_a))

	if is_preview:
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = int(_pulse * 15.0)

	# Молнии из каждого тайла — количество растёт с зоной
	var bolt_count = 2 + grid_size * 2
	for i in range(bolt_count):
		var origin = _tile_local_offsets[rng.randi() % _tile_local_offsets.size()]
		var angle  = rng.randf() * TAU
		var blen   = rng.randf_range(10.0, zone_rx * 0.75)
		var tip    = origin + Vector2(cos(angle) * blen, sin(angle) * blen * (TILE_HH / TILE_HW))
		var mid    = (origin + tip) * 0.5 + Vector2(
			rng.randf_range(-9.0, 9.0),
			rng.randf_range(-6.0, 6.0)
		)
		# Свечение (толстая полупрозрачная линия)
		draw_line(origin, mid, Color(0.35, 0.65, 1.0, 0.3 * fade), 5.0)
		draw_line(mid,   tip,  Color(0.35, 0.65, 1.0, 0.3 * fade), 5.0)
		# Сама молния
		draw_line(origin, mid, Color(0.82, 0.93, 1.0, 0.92 * fade), 1.8)
		draw_line(mid,   tip,  Color(0.82, 0.93, 1.0, 0.92 * fade), 1.8)

	# Молнии между тайлами (только если зона больше 1x1)
	if _tile_local_offsets.size() > 1:
		for i in range(grid_size):
			var ia = rng.randi() % _tile_local_offsets.size()
			var ib = rng.randi() % _tile_local_offsets.size()
			if ia == ib:
				continue
			var pa  = _tile_local_offsets[ia]
			var pb  = _tile_local_offsets[ib]
			var mid2 = (pa + pb) * 0.5 + Vector2(
				rng.randf_range(-14.0, 14.0),
				rng.randf_range(-8.0,  8.0)
			)
			draw_line(pa, mid2, Color(0.6, 0.82, 1.0, 0.55 * fade), 4.0)
			draw_line(mid2, pb, Color(0.6, 0.82, 1.0, 0.55 * fade), 4.0)
			draw_line(pa, mid2, Color(0.9, 0.97, 1.0, 0.85 * fade), 1.5)
			draw_line(mid2, pb, Color(0.9, 0.97, 1.0, 0.85 * fade), 1.5)
