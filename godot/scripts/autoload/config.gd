# ==========================================
# config.gd — Глобальный загрузчик конфигов, autoload
# ==========================================
# _ready() — грузит все JSON-конфиги при старте: player, buildings, game
# _load_json(path) — парсит JSON файл, возвращает словарь.
#   Если файла нет или JSON кривой — орёт в консоль и возвращает
#   пустой словарь, ебать его в рот
# ==========================================

extends Node

## Global config loader — reads separate JSON files per category

var player: Dictionary = {}
var buildings: Dictionary = {}
var game: Dictionary = {}
var projectiles: Dictionary = {}
var effects: Dictionary = {}
var enemies: Dictionary = {}
var waves: Array = []

const CONFIG_DIR = "res://config/"


func _ready() -> void:
	player = _load_json(CONFIG_DIR + "player.json")
	buildings = _load_json(CONFIG_DIR + "buildings.json")
	game = _load_json(CONFIG_DIR + "game.json")
	projectiles = _load_json(CONFIG_DIR + "projectiles.json")
	effects = _load_json(CONFIG_DIR + "effects.json")
	enemies = _load_json(CONFIG_DIR + "enemies.json")
	# Конвертируем цвета из hex-строк в Color
	for key in enemies:
		var e = enemies[key]
		if e.has("color"):
			e["color"] = Color(e["color"])
		if e.has("accent"):
			e["accent"] = Color(e["accent"])
	waves = _load_json_array(CONFIG_DIR + "waves.json")


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Config not found: " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Failed to parse " + path + ": " + json.get_error_message())
		return {}
	return json.data


func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("Config not found: " + path)
		return []
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Failed to parse " + path + ": " + json.get_error_message())
		return []
	return json.data
