# ==========================================
# locale_manager.gd — Обёртка над TranslationServer
# ==========================================
# L.set_locale("en") — сменить язык
# L.get_locale() — текущий язык
# В коде использовать tr("KEY") — стандартный метод Godot
# ==========================================

extends Node

const DEFAULT_LOCALE = "en"

const LOCALE_NAMES: Dictionary = {
	"en": "English",
	"ru": "Русский",
	"de": "Deutsch",
	"fr": "Français",
	"es": "Español",
	"pt": "Português",
	"zh": "中文",
	"ja": "日本語",
	"ko": "한국어",
}

signal locale_changed(locale: String)


func _ready() -> void:
	var saved = _load_saved_locale()
	var locale = saved if saved != "" else DEFAULT_LOCALE
	TranslationServer.set_locale(locale)


func set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
	locale_changed.emit(locale)


func get_locale() -> String:
	return TranslationServer.get_locale()


func get_locale_name(locale: String) -> String:
	return LOCALE_NAMES.get(locale, locale)


func get_available_locales() -> Array[String]:
	var locales: Array[String] = []
	for t in TranslationServer.get_loaded_locales():
		locales.append(t)
	if locales.is_empty():
		locales = ["en", "ru"]
	locales.sort()
	return locales


func _load_saved_locale() -> String:
	var path = "user://settings.json"
	if not FileAccess.file_exists(path):
		return ""
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		return json.data.get("locale", "")
	return ""
