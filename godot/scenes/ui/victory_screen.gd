# ==========================================
# victory_screen.gd — Экран завершения демоверсии
# ==========================================

extends CanvasLayer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_save_completed_map()

	# Фон с шейдером дымки
	var bg = ColorRect.new()
	bg.name = "BG"
	bg.color = Color.WHITE
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.modulate = Color(1, 1, 1, 0)
	var fog_shader = load("res://shaders/purple_fog.gdshader")
	if fog_shader:
		var mat = ShaderMaterial.new()
		mat.shader = fog_shader
		bg.material = mat
	else:
		bg.color = Color(0.05, 0.05, 0.08)
	add_child(bg)

	# Контент
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_CENTER
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -250
	vbox.offset_right = 250
	vbox.offset_top = -200
	vbox.offset_bottom = 200
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.modulate = Color(1, 1, 1, 0)
	add_child(vbox)

	# Заголовок
	var title = Label.new()
	title.text = "ПОБЕДА"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Основной текст
	var desc = Label.new()
	desc.text = "Вы прошли демоверсию игры Lineage of Light!\n\nСпасибо, что играли. Ваша поддержка и обратная связь\nочень важны для развития проекта."
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color("#e8e0ff"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)

	# Контакт
	var contact = Label.new()
	contact.text = "Идеи, поддержка, сотрудничество:\nTelegram: @cawanik"
	contact.add_theme_font_size_override("font_size", 14)
	contact.add_theme_color_override("font_color", Color("#b088dd"))
	contact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(contact)

	# Благодарность
	var thanks = Label.new()
	thanks.text = "Спасибо за игру!"
	thanks.add_theme_font_size_override("font_size", 18)
	thanks.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(thanks)

	# Кнопка выхода
	var btn_container = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)

	var exit_btn = Button.new()
	exit_btn.text = "Главное меню"
	exit_btn.custom_minimum_size = Vector2(200, 50)
	exit_btn.add_theme_font_size_override("font_size", 16)
	exit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	exit_btn.focus_mode = Control.FOCUS_NONE
	exit_btn.pressed.connect(_on_exit_pressed)
	btn_container.add_child(exit_btn)
	_stylize_button(exit_btn)

	# Fade in
	var tween = create_tween().set_parallel(true)
	tween.tween_property(bg, "modulate:a", 1.0, 1.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(vbox, "modulate", Color(1, 1, 1, 1), 1.5).set_ease(Tween.EASE_OUT).set_delay(0.5)


func _stylize_button(btn: Button) -> void:
	var btn_tex_path = "res://assets/sprites/ui/btn_large.png"
	if not ResourceLoader.exists(btn_tex_path):
		return
	var btn_tex = load(btn_tex_path)
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


func _save_completed_map() -> void:
	var slot = GameManager.current_save_slot
	var save_path = "user://saves/slot_%d.json" % slot
	if not FileAccess.file_exists(save_path):
		return
	var file = FileAccess.open(save_path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	var completed = data.get("completed_maps", [])
	if GameManager.current_map not in completed:
		completed.append(GameManager.current_map)
	data["completed_maps"] = completed
	DirAccess.make_dir_recursive_absolute("user://saves/")
	var wfile = FileAccess.open(save_path, FileAccess.WRITE)
	wfile.store_string(JSON.stringify(data, "\t"))


func _on_exit_pressed() -> void:
	get_tree().paused = false
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
