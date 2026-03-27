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

	# Intro fade — только при первом запуске
	_play_intro()

	# Сигналы главных кнопок
	main_buttons.get_node("VBox/NewGame").pressed.connect(func(): _show_slots("new"))
	main_buttons.get_node("VBox/Continue").pressed.connect(func(): _show_slots("load"))
	main_buttons.get_node("VBox/Settings").pressed.connect(_on_settings)
	main_buttons.get_node("VBox/Quit").pressed.connect(_on_quit)

	# Сигналы слотов (скрипт на Inner)
	var slots_inner = slots_screen.get_node("Inner")
	slots_inner.slot_selected.connect(_on_slot_selected)
	slots_inner.slot_deleted.connect(_on_slot_deleted)
	slots_inner.back_pressed.connect(func(): _switch_to(main_buttons, true))

	# Сигналы хаба (скрипт на Inner)
	var hub_inner = hub_screen.get_node("Inner")
	hub_inner.skill_tree_pressed.connect(_on_hub_skill_tree)
	hub_inner.map_pressed.connect(_on_hub_map)
	hub_inner.back_pressed.connect(func():
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

	# Музыка — отложена до конца intro
	if not _is_intro:
		var am = get_node_or_null("/root/AudioManager")
		if am:
			am.play_music("main_menu_theme", 2.0)


var _is_intro: bool = false

func _play_intro() -> void:
	_is_intro = true

	# Чёрный оверлей поверх всего
	var overlay = ColorRect.new()
	overlay.name = "IntroOverlay"
	overlay.color = Color.BLACK
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Прячем UI до конца intro
	main_buttons.modulate.a = 0.0
	if logo:
		logo.modulate.a = 0.0

	var tween = create_tween()
	# Пауза на чёрном
	tween.tween_interval(0.5)
	# Fade in лого
	tween.tween_callback(func():
		if logo:
			logo.visible = true
	)
	tween.tween_property(logo, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_OUT)
	# Убираем чёрный оверлей — показываем фон
	tween.tween_property(overlay, "color:a", 0.0, 1.0).set_ease(Tween.EASE_IN_OUT)
	# Пауза с лого на фоне
	tween.tween_interval(0.5)
	# Fade in кнопок
	tween.tween_property(main_buttons, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	# Убираем оверлей и запускаем музыку
	tween.tween_callback(func():
		overlay.queue_free()
		_is_intro = false
		var am = get_node_or_null("/root/AudioManager")
		if am:
			am.play_music("main_menu_theme", 2.0)
	)


# === Стилизация ===

func _stylize_all_buttons() -> void:
	var btn_tex = load("res://assets/sprites/ui/btn_large.png") if ResourceLoader.exists("res://assets/sprites/ui/btn_large.png") else null
	if not btn_tex:
		return
	for screen in [main_buttons, slots_screen, hub_screen, map_screen, settings_screen]:
		_stylize_buttons_recursive(screen, btn_tex)


func _stylize_buttons_recursive(node: Node, btn_tex: Texture2D) -> void:
	# Пропускаем кнопки разрешения
	if node.get_parent() and node.get_parent().name == "WindowButtons":
		return
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

		var style_disabled = style.duplicate()
		style_disabled.modulate_color = Color(0.5, 0.5, 0.5)

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.add_theme_stylebox_override("disabled", style_disabled)
		btn.add_theme_stylebox_override("hover_pressed", style_hover)
		btn.add_theme_stylebox_override("focus", style)
		btn.add_theme_color_override("font_color", Color("#e8e0ff"))
		btn.add_theme_color_override("font_hover_color", Color("#f0e8ff"))
		btn.add_theme_color_override("font_disabled_color", Color("#666666"))
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func():
			var am = get_node_or_null("/root/AudioManager")
			if am:
				am.play("ui_click")
		)
		btn.mouse_entered.connect(func():
			var am = get_node_or_null("/root/AudioManager")
			if am and am.sounds.has("ui_hover"):
				am.play("ui_hover")
		)

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
		tween.tween_callback(func():
			logo.visible = true
			logo.modulate.a = 0.0
		)
		tween.tween_property(logo, "modulate:a", 1.0, 0.2)
	elif logo and logo.visible:
		tween.tween_property(logo, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): logo.visible = false)

	# Fade in нового
	tween.tween_callback(func():
		screen.modulate.a = 0.0
		screen.visible = true
	)
	tween.tween_property(screen, "modulate:a", 1.0, 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _current_screen == slots_screen:
			_switch_to(main_buttons, true)
		elif _current_screen == hub_screen:
			_save_current_slot()
			_switch_to(main_buttons, true)
		elif _current_screen == map_screen:
			_switch_to(hub_screen)
		elif _current_screen == settings_screen:
			_save_settings()
			_switch_to(main_buttons, true)
		get_viewport().set_input_as_handled()


# === Главное меню ===

func _show_slots(mode: String) -> void:
	slots_screen.get_node("Inner").show_slots(mode, _save_data)
	_switch_to(slots_screen)


func _on_settings() -> void:
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
		_save_data[slot] = {"souls": 0, "wave": 0, "unlocked_skills": [], "completed_maps": []}
		_save_slot(slot)
	_open_hub(slot)


func _on_slot_deleted(slot: int) -> void:
	_save_data[slot] = {}
	var path = SAVE_PATH + "slot_%d.json" % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	slots_screen.get_node("Inner").show_slots(slots_screen.get_node("Inner")._mode, _save_data)


# === Хаб ===

func _open_hub(slot: int) -> void:
	_hub_slot = slot
	var data = _save_data[slot]
	GameManager.current_save_slot = slot
	GameManager.souls = data.get("souls", 0)
	GameManager.tutorial_completed = data.get("tutorial_completed", false)
	GameManager.first_death_dialogue = data.get("first_death_dialogue", false)
	SkillManager.reset()
	for skill_id in data.get("unlocked_skills", []):
		SkillManager.unlocked[skill_id] = true

	hub_screen.get_node("Inner").update_info("Остров")
	_switch_to(hub_screen)


func _on_hub_skill_tree() -> void:
	var skill_tree_scene = load("res://scenes/ui/skill_tree.tscn")
	var skill_tree = skill_tree_scene.instantiate()
	add_child(skill_tree)
	skill_tree.open()
	skill_tree.visibility_changed.connect(func():
		if not skill_tree.visible:
			_save_current_slot()
			hub_screen.get_node("Inner").update_info("Остров")
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
	GameManager.skip_tutorial = false
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
	var now = Time.get_datetime_dict_from_system()
	var date_str = "%04d-%02d-%02d %02d:%02d:%02d" % [now["year"], now["month"], now["day"], now["hour"], now["minute"], now["second"]]
	_save_data[slot]["last_saved"] = date_str
	print("[Save] Slot %d saved at %s" % [slot, date_str])
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
