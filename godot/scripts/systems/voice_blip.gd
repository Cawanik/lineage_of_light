# ==========================================
# voice_blip.gd — Процедурная генерация voice blips (Undertale-стиль)
# ==========================================
# VoiceBlip.play_blip("owner") — проиграть блип персонажа
# Настройки голосов в config/voices.json
# ==========================================

class_name VoiceBlip
extends Node

static var _instance: VoiceBlip = null
var _player: AudioStreamPlayer = null
var _voices: Dictionary = {}


static func instance() -> VoiceBlip:
	return _instance


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.bus = "SFX"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)

	_load_voices()


func _load_voices() -> void:
	var path = "res://config/voices.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_voices = json.data


func get_voice(voice_id: String) -> Dictionary:
	return _voices.get(voice_id, {})


func play_blip(voice_id: String) -> void:
	var voice = _voices.get(voice_id, {})
	if voice.is_empty():
		return

	var freq = voice.get("frequency", 200.0)
	var pitch_var = voice.get("pitch_variation", 0.1)
	var duration = voice.get("duration", 0.06)
	var volume = voice.get("volume", 0.5)
	var waveform = voice.get("waveform", "square")  # square, sine, saw

	# Рандомизация питча
	var pitch = freq * randf_range(1.0 - pitch_var, 1.0 + pitch_var)

	# Генерируем звук
	var sample_rate = 22050
	var samples = int(sample_rate * duration)
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data = PackedByteArray()
	data.resize(samples)

	for i in range(samples):
		var t = float(i) / sample_rate
		var val = 0.0

		match waveform:
			"square":
				val = 1.0 if fmod(t * pitch, 1.0) < 0.5 else -1.0
			"sine":
				val = sin(t * pitch * TAU)
			"saw":
				val = fmod(t * pitch, 1.0) * 2.0 - 1.0
			"noise":
				val = randf_range(-1.0, 1.0)

		# Огибающая — быстрый attack, плавный release
		var env = 1.0
		var attack = 0.005
		var release_start = duration * 0.6
		if t < attack:
			env = t / attack
		elif t > release_start:
			env = 1.0 - (t - release_start) / (duration - release_start)

		val *= env * volume
		data[i] = int(clampf(val * 127.0 + 128.0, 0, 255))

	audio.data = data

	_player.stream = audio
	_player.volume_db = linear_to_db(volume * AudioManager.sfx_volume * AudioManager.master_volume)
	_player.play()


# === Статический хелпер ===

static func blip(voice_id: String) -> void:
	if _instance:
		_instance.play_blip(voice_id)
