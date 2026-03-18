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

const CONFIG_DIR = "res://config/"


func _ready() -> void:
	player = _load_json(CONFIG_DIR + "player.json")
	buildings = _load_json(CONFIG_DIR + "buildings.json")
	game = _load_json(CONFIG_DIR + "game.json")


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
