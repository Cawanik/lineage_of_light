# ==========================================
# audio_manager.gd — Менеджер звуков, autoload
# ==========================================
# AudioManager.play("ui_click")
# AudioManager.play("build", 0.8)
# AudioManager.play_music("battle_theme")
# AudioManager.set_sfx_volume(0.5)
# AudioManager.set_music_volume(0.3)
# ==========================================

extends Node

# Громкость (0.0 — 1.0)
var sfx_volume: float = 0.1
var music_volume: float = 0.5
var master_volume: float = 1.0

# Пул SFX плееров (чтобы звуки не обрезали друг друга)
const SFX_POOL_SIZE = 64
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

# Музыка
var _music_player: AudioStreamPlayer = null
var _current_music: String = ""

# Кэш загруженных звуков
var _cache: Dictionary = {}  # path -> AudioStream

# Каталог звуков: id -> {path, volume, pitch_min, pitch_max}
var sounds: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Сначала создаём аудиобасы
	_ensure_bus("SFX")
	_ensure_bus("Music")

	# Пул SFX плееров
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

	# Музыкальный плеер (не паузится)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)

	# Загружаем каталог звуков
	_load_sound_catalog()

	# Загружаем настройки громкости
	_load_volume_settings()


func _load_volume_settings() -> void:
	var path = "user://settings.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	set_master_volume(data.get("master_volume", 1.0))
	set_music_volume(data.get("music_volume", 0.5))
	set_sfx_volume(data.get("sfx_volume", 0.1))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _load_sound_catalog() -> void:
	var path = "res://config/sounds.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		sounds = json.data


# === SFX ===

enum Ease { LINEAR, EASE_IN, EASE_OUT, EASE_IN_OUT }


func play(sound_id: String, volume_override: float = -1.0) -> void:
	var data = sounds.get(sound_id, {})
	var sound_path = data.get("path", "")
	if sound_path == "":
		# Пробуем как прямой путь
		sound_path = sound_id
	if sound_path == "" or not ResourceLoader.exists(sound_path):
		return

	var stream = _get_stream(sound_path)
	if not stream:
		return

	var player = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE

	player.stream = stream

	# Громкость
	var vol = data.get("volume", 1.0)
	if volume_override >= 0:
		vol = volume_override
	player.volume_db = linear_to_db(vol * sfx_volume * master_volume)

	# Рандомный питч для вариативности
	var pitch_min = data.get("pitch_min", 1.0)
	var pitch_max = data.get("pitch_max", 1.0)
	player.pitch_scale = randf_range(pitch_min, pitch_max)

	var start_from = data.get("start_from", 0.0)
	player.play(start_from)

	# Обрезка по максимальной длительности
	var max_dur = data.get("max_duration", 0.0)
	var fade_out_dur = data.get("fade_out", 0.2)
	if max_dur > 0:
		var tween = create_tween()
		tween.tween_interval(maxf(max_dur - fade_out_dur, 0))
		tween.tween_property(player, "volume_db", -40.0, fade_out_dur)
		tween.tween_callback(player.stop)


func play_range(sound_id: String, from_sec: float = 0.0, to_sec: float = -1.0, volume_override: float = -1.0, fade_in: float = 0.0, fade_out: float = 0.0, ease_type: Ease = Ease.LINEAR) -> void:
	var data = sounds.get(sound_id, {})
	var sound_path = data.get("path", sound_id)
	if not ResourceLoader.exists(sound_path):
		return
	var stream = _get_stream(sound_path)
	if not stream:
		return

	var player = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
	player.stream = stream

	var vol = data.get("volume", 1.0)
	if volume_override >= 0:
		vol = volume_override
	var target_db = linear_to_db(vol * sfx_volume * master_volume)

	if fade_in > 0:
		player.volume_db = -40.0
	else:
		player.volume_db = target_db

	player.play(from_sec)

	var duration = to_sec - from_sec if to_sec > 0 else stream.get_length() - from_sec

	var tween = create_tween()
	_apply_ease(tween, ease_type)

	if fade_in > 0:
		tween.tween_property(player, "volume_db", target_db, fade_in)

	# Ждём до начала fade_out
	var hold = maxf(duration - fade_in - fade_out, 0.0)
	if hold > 0:
		tween.tween_interval(hold)

	if fade_out > 0:
		tween.tween_property(player, "volume_db", -40.0, fade_out)
		tween.tween_callback(player.stop)
	else:
		tween.tween_callback(player.stop)


func play_fade_in(sound_id: String, duration: float = 0.5, ease_type: Ease = Ease.LINEAR, volume_override: float = -1.0) -> void:
	var data = sounds.get(sound_id, {})
	var sound_path = data.get("path", sound_id)
	if not ResourceLoader.exists(sound_path):
		return
	var stream = _get_stream(sound_path)
	if not stream:
		return

	var player = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
	player.stream = stream

	var vol = data.get("volume", 1.0)
	if volume_override >= 0:
		vol = volume_override
	var target_db = linear_to_db(vol * sfx_volume * master_volume)

	player.volume_db = -40.0
	player.play()

	var tween = create_tween()
	_apply_ease(tween, ease_type)
	tween.tween_property(player, "volume_db", target_db, duration)


func play_fade_out(sound_id: String, duration: float = 0.5, ease_type: Ease = Ease.LINEAR) -> void:
	# Находим играющий плеер с этим звуком
	for player in _sfx_players:
		if player.playing and player.stream and player.stream.resource_path.find(sound_id) != -1:
			var tween = create_tween()
			_apply_ease(tween, ease_type)
			tween.tween_property(player, "volume_db", -40.0, duration)
			tween.tween_callback(player.stop)
			return


func play_with_fade(sound_id: String, fade_in: float = 0.3, fade_out: float = 0.3, hold: float = 1.0, ease_type: Ease = Ease.EASE_IN_OUT, volume_override: float = -1.0) -> void:
	var data = sounds.get(sound_id, {})
	var sound_path = data.get("path", sound_id)
	if not ResourceLoader.exists(sound_path):
		return
	var stream = _get_stream(sound_path)
	if not stream:
		return

	var player = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
	player.stream = stream

	var vol = data.get("volume", 1.0)
	if volume_override >= 0:
		vol = volume_override
	var target_db = linear_to_db(vol * sfx_volume * master_volume)

	player.volume_db = -40.0
	player.play()

	var tween = create_tween()
	_apply_ease(tween, ease_type)
	tween.tween_property(player, "volume_db", target_db, fade_in)
	tween.tween_interval(hold)
	tween.tween_property(player, "volume_db", -40.0, fade_out)
	tween.tween_callback(player.stop)


func _apply_ease(tween: Tween, ease_type: Ease) -> void:
	match ease_type:
		Ease.LINEAR:
			tween.set_trans(Tween.TRANS_LINEAR)
		Ease.EASE_IN:
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		Ease.EASE_OUT:
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		Ease.EASE_IN_OUT:
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func play_at(sound_id: String, position: Vector2, volume_override: float = -1.0) -> void:
	# Для 2D позиционного звука — используем AudioStreamPlayer2D
	var data = sounds.get(sound_id, {})
	var sound_path = data.get("path", "")
	if sound_path == "":
		sound_path = sound_id
	if sound_path == "" or not ResourceLoader.exists(sound_path):
		return

	var stream = _get_stream(sound_path)
	if not stream:
		return

	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.position = position

	var vol = data.get("volume", 1.0)
	if volume_override >= 0:
		vol = volume_override
	player.volume_db = linear_to_db(vol * sfx_volume * master_volume)

	var pitch_min = data.get("pitch_min", 1.0)
	var pitch_max = data.get("pitch_max", 1.0)
	player.pitch_scale = randf_range(pitch_min, pitch_max)

	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


# === Музыка ===

func play_music(music_id: String, fade_in: float = 1.0, ease_type: Ease = Ease.EASE_IN_OUT) -> void:
	if music_id == _current_music:
		return

	var data = sounds.get(music_id, {})
	var music_path = data.get("path", music_id)
	if not ResourceLoader.exists(music_path):
		return

	var stream = _get_stream(music_path)
	if not stream:
		return

	# Убиваем предыдущие tweens музыки
	if _music_trim_tween and _music_trim_tween.is_valid():
		_music_trim_tween.kill()
	if _music_stop_tween and _music_stop_tween.is_valid():
		_music_stop_tween.kill()

	_current_music = music_id
	print("[AudioManager] Playing music: %s (%s)" % [music_id, music_path])

	var target_db = linear_to_db(music_volume * master_volume)

	var trim_end = data.get("trim_end", 0.0)
	var play_duration = stream.get_length() - trim_end if trim_end > 0 else 0.0

	if _music_player.playing:
		var tween = create_tween()
		_apply_ease(tween, ease_type)
		tween.tween_property(_music_player, "volume_db", -40.0, fade_in * 0.5)
		tween.tween_callback(func():
			_music_player.stream = stream
			_music_player.volume_db = -40.0
			_music_player.play()
			if play_duration > 0:
				_start_music_trim_timer(play_duration)
		)
		tween.tween_property(_music_player, "volume_db", target_db, fade_in * 0.5)
	else:
		_music_player.stream = stream
		_music_player.volume_db = -40.0
		_music_player.play()
		if play_duration > 0:
			_start_music_trim_timer(play_duration)
		var tween = create_tween()
		_apply_ease(tween, ease_type)
		tween.tween_property(_music_player, "volume_db", target_db, fade_in)


var _music_trim_tween: Tween = null
var _music_stop_tween: Tween = null

func _start_music_trim_timer(play_duration: float) -> void:
	if _music_trim_tween and _music_trim_tween.is_valid():
		_music_trim_tween.kill()
	_music_trim_tween = create_tween()
	# За 1.5 сек до конца — fade out и перезапуск
	_music_trim_tween.tween_interval(maxf(play_duration - 1.5, 0))
	_music_trim_tween.tween_property(_music_player, "volume_db", -40.0, 1.5)
	_music_trim_tween.tween_callback(func():
		_music_player.play(0.0)
		_music_player.volume_db = linear_to_db(music_volume * master_volume)
		# Рестарт таймера для следующего цикла
		_start_music_trim_timer(play_duration)
	)


func stop_music(fade_out: float = 1.0, ease_type: Ease = Ease.EASE_OUT) -> void:
	if _music_trim_tween and _music_trim_tween.is_valid():
		_music_trim_tween.kill()
	if not _music_player.playing:
		return
	_current_music = ""
	if _music_stop_tween and _music_stop_tween.is_valid():
		_music_stop_tween.kill()
	_music_stop_tween = create_tween()
	_apply_ease(_music_stop_tween, ease_type)
	_music_stop_tween.tween_property(_music_player, "volume_db", -40.0, fade_out)
	_music_stop_tween.tween_callback(_music_player.stop)


# === Настройки громкости ===

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)


func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	if _music_player.playing:
		_music_player.volume_db = linear_to_db(music_volume * master_volume)


func set_master_volume(vol: float) -> void:
	master_volume = clampf(vol, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))


# === Кэш ===

func _get_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var stream = load(path) as AudioStream
	if stream:
		_cache[path] = stream
	return stream
