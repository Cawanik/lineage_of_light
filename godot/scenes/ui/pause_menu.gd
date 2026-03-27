# ==========================================
# pause_menu.gd — Меню паузы
# ==========================================

extends CanvasLayer

var _is_open: bool = false
var _settings_screen: Control = null
var _main_vbox: Control = null


func _ready() -> void:
	layer = 109
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	$Center/VBox/Resume.pressed.connect(close)
	$Center/VBox/MainMenu.pressed.connect(_on_main_menu)
	$Center/VBox/Quit.pressed.connect(_on_quit)
	$Center/VBox/Settings.pressed.connect(_on_settings)

	# Стилизация кнопок
	var btn_tex_path = "res://assets/sprites/ui/btn_large.png"
	if ResourceLoader.exists(btn_tex_path):
		var btn_tex = load(btn_tex_path)
		for btn in [$Center/VBox/Resume, $Center/VBox/Settings, $Center/VBox/MainMenu, $Center/VBox/Quit]:
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
			btn.add_theme_stylebox_override("hover_pressed", style_pressed)
			btn.add_theme_stylebox_override("focus", style)
			btn.add_theme_color_override("font_color", Color("#e8e0ff"))
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.focus_mode = Control.FOCUS_NONE


func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	GameManager.pause_game()
	# Приглушаем музыку
	var am = get_node_or_null("/root/AudioManager")
	if am and am._music_player.playing:
		var tween = am.create_tween()
		tween.tween_property(am._music_player, "volume_db", am._music_player.volume_db - 5.0, 0.3)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	if _settings_screen and _settings_screen.visible:
		_settings_screen.visible = false
		if _main_vbox:
			_main_vbox.visible = true
		_save_settings()
	_refresh_toolbar_labels()
	GameManager.resume_game()
	var am = get_node_or_null("/root/AudioManager")
	if am and am._music_player.playing:
		var target_db = linear_to_db(am.music_volume * am.master_volume)
		var tween = am.create_tween()
		tween.tween_property(am._music_player, "volume_db", target_db, 0.3)


func _refresh_toolbar_labels() -> void:
	var main = get_tree().current_scene
	if not main:
		return
	var toolbar_grid = main.get_node_or_null("UILayer/Toolbar/Grid")
	if not toolbar_grid:
		return
	var slots = toolbar_grid.get_children()
	for i in range(slots.size()):
		var lbl = slots[i].get_node_or_null("HotkeyLabel")
		if lbl and main.has_method("_key_label"):
			lbl.text = main._key_label(GameManager.toolbar_keybinds[i])


func _on_main_menu() -> void:
	close()
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _on_settings() -> void:
	if not _settings_screen:
		var scene = load("res://scenes/menu/screens/settings_screen.tscn")
		_settings_screen = scene.instantiate()
		_settings_screen.visible = false
		_settings_screen.back_pressed.connect(_on_settings_back)
		add_child(_settings_screen)
		# Стилизация кнопок настроек
		_stylize_buttons_in(_settings_screen)
	_main_vbox = $Center
	_main_vbox.visible = false
	_settings_screen.visible = true


func _on_settings_back() -> void:
	_settings_screen.visible = false
	_main_vbox.visible = true
	_save_settings()
	_refresh_toolbar_labels()


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


func _stylize_buttons_in(node: Node) -> void:
	var btn_tex_path = "res://assets/sprites/ui/btn_large.png"
	if not ResourceLoader.exists(btn_tex_path):
		return
	var btn_tex = load(btn_tex_path)
	_stylize_recursive(node, btn_tex)


func _stylize_recursive(node: Node, btn_tex: Texture2D) -> void:
	if node.get_parent() and node.get_parent().name == "WindowButtons":
		return
	if node is Button and not node is TextureButton and not node is CheckBox:
		var btn = node as Button
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
		var style_disabled = style.duplicate()
		style_disabled.modulate_color = Color(0.5, 0.5, 0.5)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("disabled", style_disabled)
		btn.add_theme_stylebox_override("focus", style)
		btn.add_theme_color_override("font_color", Color("#e8e0ff"))
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_stylize_recursive(child, btn_tex)


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
