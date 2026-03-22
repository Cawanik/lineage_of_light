class_name DustEffect
extends Node2D

## Спавнит анимированные частицы пыли при постройке


static func spawn(tree: SceneTree, world_pos: Vector2, effect_type: String = "build_dust") -> void:
	var data = Config.effects.get(effect_type, {})
	var count = int(data.get("particle_count", 6))
	var spread = data.get("spread_radius", 32.0)
	var speed_min = data.get("speed_min", 15.0)
	var speed_max = data.get("speed_max", 40.0)
	var lifetime = data.get("lifetime", 0.6)
	var scale_min = data.get("scale_min", 0.6)
	var scale_max = data.get("scale_max", 1.2)
	var fps_val = data.get("fps", 10.0)
	var fade_out = data.get("fade_out", true)

	# Загружаем фреймы по индексу (работает в билде)
	var frames_path = data.get("frames_path", "")
	var textures: Array[Texture2D] = []
	if frames_path != "":
		for i in range(100):
			# Пробуем разные форматы имён
			var paths = [
				frames_path + "frame_%03d.png" % i,
				frames_path + "dust_puff_%04d.png" % (i + 1),
			]
			var found = false
			for p in paths:
				if ResourceLoader.exists(p):
					textures.append(load(p))
					found = true
					break
			if not found and i > 0:
				break

	# Фоллбэк на статичный спрайт
	if textures.is_empty():
		var sprite_path = data.get("sprite", "")
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			textures.append(load(sprite_path))

	if textures.is_empty():
		return

	var ysort = tree.current_scene.get_node_or_null("YSort")
	if not ysort:
		return

	for i in range(count):
		var t = float(i) / float(count)  # равномерно по периметру
		var particle = _create_particle(world_pos, spread, speed_min, speed_max, lifetime, scale_min, scale_max, fps_val, fade_out, textures, t)
		ysort.add_child(particle)


static func _create_particle(origin: Vector2, spread: float, speed_min: float, speed_max: float, lifetime: float, scale_min: float, scale_max: float, fps_val: float, fade_out: bool, textures: Array[Texture2D], t: float = 0.0) -> Node2D:
	var particle = AnimatedSprite2D.new()
	particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle.z_index = 80

	# SpriteFrames
	var sf = SpriteFrames.new()
	sf.add_animation("puff")
	sf.set_animation_speed("puff", fps_val)
	sf.set_animation_loop("puff", false)
	for tex in textures:
		sf.add_frame("puff", tex)
	if sf.has_animation("default"):
		sf.remove_animation("default")
	particle.sprite_frames = sf

	# Спавн на краю изометрического ромба тайла (равномерно)
	var hw = 32.0  # полуширина тайла
	var hh = 16.0  # полувысота тайла
	var edge_pos: Vector2
	if t < 0.25:
		edge_pos = Vector2(0, -hh).lerp(Vector2(hw, 0), t * 4.0)
	elif t < 0.5:
		edge_pos = Vector2(hw, 0).lerp(Vector2(0, hh), (t - 0.25) * 4.0)
	elif t < 0.75:
		edge_pos = Vector2(0, hh).lerp(Vector2(-hw, 0), (t - 0.5) * 4.0)
	else:
		edge_pos = Vector2(-hw, 0).lerp(Vector2(0, -hh), (t - 0.75) * 4.0)
	particle.position = origin + edge_pos
	var angle = edge_pos.angle()

	var sc = randf_range(scale_min, scale_max)
	particle.scale = Vector2(sc, sc)

	# Скрипт движения и исчезновения
	var speed = randf_range(speed_min, speed_max)
	var dir = Vector2(cos(angle), sin(angle))
	var max_life = lifetime + randf_range(-0.1, 0.1)

	particle.play("puff")
	particle.frame = randi() % max(sf.get_frame_count("puff"), 1)

	# Используем tween для движения и затухания
	var tween = particle.create_tween()
	tween.set_parallel(true)
	var end_pos = particle.position + dir * spread
	tween.tween_property(particle, "position", end_pos, max_life).set_ease(Tween.EASE_OUT)
	if fade_out:
		tween.tween_property(particle, "modulate:a", 0.0, max_life).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(particle.queue_free)

	return particle
