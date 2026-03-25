# ==========================================
# main_menu.gd — Координатор экранов меню
# ==========================================

extends Control

const SAVE_PATH = "user://saves/"

var _save_data: Array[Dictionary] = [{}, {}, {}]
var _maps_data: Array = []
var _hub_slot: int = -1
var _current_screen: Control = null

# Экраны (подгружаются из tscn)
@onready var bg: ColorRect = $BG
@onready var logo: TextureRect = $Logo
@onready var main_buttons: Control = $MainButtons
@onready var slots_screen: Control = $SlotsScreen
@onready var hub_screen: Control = $HubScreen
@onready var map_screen: Control = $MapScreen
@onready var settings_screen: Control = $SettingsScreen


func _ready() -> void:
	_load_settings()
	_load_all_saves()
	_load_maps()

	# Шейдер дымки на фон
	var fog_shader = load("res://shaders/purple_fog.gdshader")
	if fog_shader:
		var mat = ShaderMaterial.new()
		mat.shader = fog_shader
		bg.material = mat

	# Стилизуем все кнопки подложками
	_stylize_all_buttons()

	# Скрываем все кроме главных кнопок
	slots_screen.visible = false
	hub_screen.visible = false
	map_screen.visible = false
	settings_screen.visible = false
	_current_screen = main_buttons

	# Сигналы главных кнопок
	main_buttons.get_node("NewGame").pressed.connect(func(): _show_slots("new"))
	main_buttons.get_node("Continue").pressed.connect(func(): _show_slots("load"))
	main_buttons.get_node("Settings").pressed.connect(_on_settings)
	main_buttons.get_node("Quit").pressed.connect(_on_quit)

	# Сигналы слотов
	slots_screen.slot_selected.connect(_on_slot_selected)
	slots_screen.slot_deleted.connect(_on_slot_deleted)
	slots_screen.back_pressed.connect(func(): _switch_to(main_buttons, true))

	# Сигналы хаба
	hub_screen.skill_tree_pressed.connect(_on_hub_skill_tree)
	hub_screen.map_pressed.connect(_on_hub_map)
	hub_screen.back_pressed.connect(func():
		_save_current_slot()
		_switch_to(main_buttons, true)
	)

	# Сигналы карты
	map_screen.map_selected.connect(_on_map_play)
	map_screen.back_pressed.connect(func(): _switch_to(hub_screen))

	# Сигналы настроек
	settings_screen.back_pressed.connect(func():
		_save_settings()
		_switch_to(main_buttons, true)
	)

	# Музыка
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_music("main_menu_theme", 2.0)


# === Стилизация ===

func _stylize_all_buttons() -> void:
	var btn_tex = load("res://assets/sprites/ui/btn_large.png") if ResourceLoader.exists("res://assets/sprites/ui/btn_large.png") else null
	if not btn_tex:
		return
	for screen in [main_buttons, slots_screen, hub_screen, map_screen, settings_screen]:
		_stylize_buttons_recursive(screen, btn_tex)


func _stylize_buttons_recursive(node: Node, btn_tex: Texture2D) -> void:
	if node is Button and not node is TextureButton and not node is CheckBox:
		var btn = node as Button
		# Создаём StyleBoxTexture
		var style = StyleBoxTexture.new()
		style.texture = btn_tex
		style.texture_margin_left = 10
		style.texture_margin_right = 10
		style.texture_margin_top = 5
		style.texture_margin_bottom = 5
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 8
		style.content_margin_bottom = 8

		var style_hover = style.duplicate()
		style_hover.modulate_color = Color(1.2, 1.1, 1.3)

		var style_pressed = style.duplicate()
		style_pressed.modulate_color = Color(0.8, 0.7, 0.9)

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.add_theme_stylebox_override("focus", style)
		btn.add_theme_color_override("font_color", Color("#e8e0ff"))
		btn.add_theme_color_override("font_hover_color", Color("#f0e8ff"))
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	for child in node.get_children():
		_stylize_buttons_recursive(child, btn_tex)


# === Навигация ===

func _switch_to(screen: Control, show_logo: bool = false) -> void:
	if _current_screen == screen:
		return
	var old = _current_screen
	_current_screen = screen

	# Fade out старого
	var tween = create_tween()
	if old:
		tween.tween_property(old, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func():
			old.visible = false
			old.modulate.a = 1.0
		)

	# Logo
	if show_logo and logo:
		tween.tween_callback(func(): logo.visible = true)
		tween.tween_property(logo, "modulate:a", 1.0, 0.2)
	elif logo and logo.visible:
		logo.modulate.a = 0.0
		logo.visible = false

	# Fade in нового
	tween.tween_callback(func():
		screen.modulate.a = 0.0
		screen.visible = true
	)
	tween.tween_property(screen, "modulate:a", 1.0, 0.2)


# === Главное меню ===

func _show_slots(mode: String) -> void:
	slots_screen.show_slots(mode, _save_data)
	_switch_to(slots_screen)
	if logo:
		var t = create_tween()
		t.tween_property(logo, "modulate:a", 0.0, 0.2)


func _on_settings() -> void:
	if logo:
		var t = create_tween()
		t.tween_property(logo, "modulate:a", 0.0, 0.2)
	_switch_to(settings_screen)


func _on_quit() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.stop_music(1.0)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(get_tree().quit)


# === Слоты ===

func _on_slot_selected(slot: int, mode: String) -> void:
	if mode == "new":
		_save_data[slot] = {"souls": 0, "wave": 0, "unlocked_skills": SkillManager.DEFAULT_UNLOCKED.duplicate(), "completed_maps": []}
		_save_slot(slot)
	_open_hub(slot)


func _on_slot_deleted(slot: int) -> void:
	_save_data[slot] = {}
	var path = SAVE_PATH + "slot_%d.json" % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	slots_screen.show_slots(slots_screen._mode, _save_data)


# === Хаб ===

func _open_hub(slot: int) -> void:
	_hub_slot = slot
	var data = _save_data[slot]
	GameManager.current_save_slot = slot
	GameManager.souls = data.get("souls", 0)
	SkillManager.reset()
	for skill_id in data.get("unlocked_skills", []):
		SkillManager.unlocked[skill_id] = true

	hub_screen.update_info("Остров")
	_switch_to(hub_screen)


func _on_hub_skill_tree() -> void:
	var skill_tree_scene = load("res://scenes/ui/skill_tree.tscn")
	var skill_tree = skill_tree_scene.instantiate()
	add_child(skill_tree)
	skill_tree.open()
	skill_tree.visibility_changed.connect(func():
		if not skill_tree.visible:
			_save_current_slot()
			hub_screen.update_info("Остров")
			skill_tree.queue_free()
	)


func _on_hub_map() -> void:
	var completed = _save_data[_hub_slot].get("completed_maps", [])
	map_screen.build_map_list(_maps_data, completed)
	_switch_to(map_screen)


# === Карта ===

func _on_map_play(map: Dictionary) -> void:
	var scene_path = map.get("scene", "")
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		var al = get_node_or_null("/root/AlertSystem")
		if al:
			al.alert_error("Локация недоступна")
		return
	GameManager.current_map = map.get("id", "")
	_save_current_slot()
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.stop_music(2.0)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file(scene_path))


# === Сохранение ===

func _save_current_slot() -> void:
	if _hub_slot < 0:
		return
	_save_data[_hub_slot]["souls"] = GameManager.souls
	var skills: Array = []
	for skill_id in SkillManager.unlocked:
		skills.append(skill_id)
	_save_data[_hub_slot]["unlocked_skills"] = skills
	_save_slot(_hub_slot)


func _save_slot(slot: int) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)
	var path = SAVE_PATH + "slot_%d.json" % slot
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_save_data[slot], "\t"))


func _load_all_saves() -> void:
	for i in range(3):
		var path = SAVE_PATH + "slot_%d.json" % i
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				_save_data[i] = json.data
			else:
				_save_data[i] = {}
		else:
			_save_data[i] = {}


func _load_maps() -> void:
	var path = "res://config/maps.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_maps_data = json.data


func _save_settings() -> void:
	DirAccess.make_dir_recursive_absolute("user://")
	var data = {
		"master_volume": AudioManager.master_volume,
		"music_volume": AudioManager.music_volume,
		"sfx_volume": AudioManager.sfx_volume,
		"toolbar_keybinds": GameManager.toolbar_keybinds,
	}
	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))


func _load_settings() -> void:
	var path = "user://settings.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.data
		AudioManager.set_master_volume(data.get("master_volume", 1.0))
		AudioManager.set_music_volume(data.get("music_volume", 0.5))
		AudioManager.set_sfx_volume(data.get("sfx_volume", 0.1))
		var binds = data.get("toolbar_keybinds", [])
		if binds.size() == 9:
			for i in range(9):
				GameManager.toolbar_keybinds[i] = int(binds[i])
