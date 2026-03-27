# ==========================================
# game_over_screen.gd — Экран Game Over при разрушении трона
# ==========================================

extends Control

const PORTRAIT_OWNER = "res://assets/sprites/ui/portraits/portrait_owner.png"
const PORTRAIT_BOOK = "res://assets/sprites/ui/skills/icon_grimoire.png"
const PORTRAIT_PLAYER = "res://assets/sprites/ui/portraits/portrait_player.png"

@onready var background: ColorRect = $Background
@onready var vbox: VBoxContainer = $VBox

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ставим игру на паузу
	get_tree().paused = true

	# Start invisible
	background.modulate = Color(1, 1, 1, 0)
	vbox.modulate = Color(1, 1, 1, 0)

	# Connect buttons
	$VBox/ButtonContainer/RestartButton.pressed.connect(_on_restart_pressed)
	$VBox/ButtonContainer/ExitButton.pressed.connect(_on_exit_pressed)

	# Стилизация кнопок
	_stylize_buttons()

	# Fade in
	var tween = create_tween().set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.8, 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(vbox, "modulate", Color(1, 1, 1, 1), 1.2).set_ease(Tween.EASE_OUT).set_delay(0.3)

	# Первая смерть после обучения — диалог
	if GameManager.tutorial_completed and not GameManager.first_death_dialogue:
		# Скрываем кнопки пока идёт диалог
		$VBox/ButtonContainer.visible = false
		tween.chain().tween_callback(_show_first_death_dialogue)


func _show_first_death_dialogue() -> void:
	DialogueBox.say([
		{"name": "Книга", "text": "НЕЕЕТ! Трон! Мой прекрасный выходной! Всё пропало!", "portrait": PORTRAIT_BOOK, "voice": "book"},
		{"name": "Книга", "text": "Ну ты и архитектор. \"Лучший из мира людей\", значит? Страшно представить худшего.", "portrait": PORTRAIT_BOOK, "voice": "book"},
		{"name": "Владыка", "text": "...", "portrait": PORTRAIT_OWNER, "voice": "owner"},
		{"name": "Книга", "text": "В-владыка?! Вы уже вернулись?! Мы всё исправим, клянусь корешком!", "portrait": PORTRAIT_BOOK, "voice": "book"},
		{"name": "Владыка", "text": "Спокойно. Я не злюсь.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
		{"name": "Книга", "text": "...Не злитесь?", "portrait": PORTRAIT_BOOK, "voice": "book"},
		{"name": "Владыка", "text": "Я произвожу эти троны. У меня их на складе ещё штук двадцать. Знаешь, сколько раз мои братья теряли свои? Некоторые — ежемесячно.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
		{"name": "Вы", "text": "То есть... я не умер?", "portrait": PORTRAIT_PLAYER, "voice": "player"},
		{"name": "Владыка", "text": "Ты бессмертный, помнишь? Я не могу тебя убить, даже если бы захотел. А я не хочу. Я не человек — у нас не принято наказывать за первую ошибку.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
		{"name": "Вы", "text": "...Это лучшее, что мне говорили за долгое время.", "portrait": PORTRAIT_PLAYER, "voice": "player"},
		{"name": "Владыка", "text": "Держи новый трон. Поставь его на то же место — мне нравится, как там падает лунный свет.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
		{"name": "Книга", "text": "Вам... нравится лунный свет?", "portrait": PORTRAIT_BOOK, "voice": "book"},
		{"name": "Владыка", "text": "Ещё одно слово — и следующий трон будет из твоих страниц.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
		{"name": "Книга", "text": "Молчу-молчу.", "portrait": PORTRAIT_BOOK, "voice": "book"},
		{"name": "Владыка", "text": "В этот раз строй умнее. У людей короткая память, но длинные мечи. Они вернутся.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
		{"name": "Книга", "text": "Ладно, слышал босса? Трон на место, стены покрепче. И на этот раз — постарайся.", "portrait": PORTRAIT_BOOK, "voice": "book"},
	])

	var db = DialogueBox.instance()
	if db:
		db.dialogue_finished.connect(_on_first_death_dialogue_finished, CONNECT_ONE_SHOT)


func _on_first_death_dialogue_finished() -> void:
	GameManager.first_death_dialogue = true
	# Сохраняем
	_autosave_flag()
	# Показываем кнопки
	$VBox/ButtonContainer.visible = true
	var tween = create_tween()
	$VBox/ButtonContainer.modulate = Color(1, 1, 1, 0)
	tween.tween_property($VBox/ButtonContainer, "modulate:a", 1.0, 0.3)


func _autosave_flag() -> void:
	var slot = GameManager.current_save_slot
	var save_path = "user://saves/slot_%d.json" % slot
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			data["first_death_dialogue"] = true
			data["tutorial_completed"] = true
			DirAccess.make_dir_recursive_absolute("user://saves/")
			var wfile = FileAccess.open(save_path, FileAccess.WRITE)
			wfile.store_string(JSON.stringify(data, "\t"))


func _stylize_buttons() -> void:
	var btn_tex_path = "res://assets/sprites/ui/btn_large.png"
	if not ResourceLoader.exists(btn_tex_path):
		return
	var btn_tex = load(btn_tex_path)
	for btn in [$VBox/ButtonContainer/RestartButton, $VBox/ButtonContainer/ExitButton]:
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


func _on_restart_pressed() -> void:
	# Сбрасываем состояние но сохраняем прогресс (навыки, души)
	GameManager.gold = 350
	GameManager.lives = 20
	GameManager.is_game_active = true
	PhaseManager._initialized = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_exit_pressed() -> void:
	GameManager.is_game_active = true
	PhaseManager._initialized = false
	get_tree().paused = false
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.stop_music(1.0)
	var al = get_node_or_null("/root/AlertSystem")
	if al:
		al.hide_persistent()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
