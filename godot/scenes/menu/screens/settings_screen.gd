extends ScrollContainer

signal back_pressed

@onready var master_slider: HSlider = $Center/VBox/MasterVolume/Slider
@onready var master_value: Label = $Center/VBox/MasterVolume/Value
@onready var music_slider: HSlider = $Center/VBox/MusicVolume/Slider
@onready var music_value: Label = $Center/VBox/MusicVolume/Value
@onready var sfx_slider: HSlider = $Center/VBox/SFXVolume/Slider
@onready var sfx_value: Label = $Center/VBox/SFXVolume/Value
@onready var toolbar_container: Control = $Center/VBox/ToolbarContainer

const FORBIDDEN_KEYS = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_ESCAPE]

var _keybind_buttons: Array = []
var _rebinding_slot: int = -1
var _rebinding_btn: Button = null


func _ready() -> void:
	master_slider.value = AudioManager.master_volume
	music_slider.value = AudioManager.music_volume
	sfx_slider.value = AudioManager.sfx_volume
	_update_labels()

	master_slider.value_changed.connect(func(v):
		AudioManager.set_master_volume(v)
		_update_labels()
	)
	music_slider.value_changed.connect(func(v):
		AudioManager.set_music_volume(v)
		_update_labels()
	)
	sfx_slider.value_changed.connect(func(v):
		AudioManager.set_sfx_volume(v)
		_update_labels()
	)
	sfx_slider.drag_ended.connect(func(_changed):
		AudioManager.play("build")
	)

	# Разрешение экрана
	$Center/VBox/WindowButtons/Res720.pressed.connect(func(): _set_resolution(1280, 720))
	$Center/VBox/WindowButtons/Res900.pressed.connect(func(): _set_resolution(1600, 900))
	$Center/VBox/WindowButtons/Res1080.pressed.connect(func(): _set_resolution(1920, 1080))
	$Center/VBox/Fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	$Center/VBox/Fullscreen.toggled.connect(func(on):
		if on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)

	_build_language_selector()
	_build_toolbar_binds()


func _build_language_selector() -> void:
	var vbox = $Center/VBox
	var lang_container = HBoxContainer.new()
	lang_container.name = "LanguageContainer"
	lang_container.add_theme_constant_override("separation", 10)
	lang_container.alignment = BoxContainer.ALIGNMENT_CENTER

	var lang_label = Label.new()
	lang_label.text = "Language:"
	lang_label.add_theme_font_size_override("font_size", 14)
	lang_container.add_child(lang_label)

	var lang_btn = OptionButton.new()
	lang_btn.name = "LanguageButton"
	lang_btn.add_theme_font_size_override("font_size", 14)
	lang_btn.custom_minimum_size = Vector2(150, 30)

	var locales = L.get_available_locales()
	var current_idx = 0
	for i in range(locales.size()):
		lang_btn.add_item(L.get_locale_name(locales[i]), i)
		if locales[i] == L.get_locale():
			current_idx = i
	lang_btn.selected = current_idx

	lang_btn.item_selected.connect(func(idx):
		var locale = locales[idx]
		L.set_locale(locale)
	)
	lang_container.add_child(lang_btn)

	# Вставляем перед toolbar
	var toolbar_idx = toolbar_container.get_index()
	vbox.add_child(lang_container)
	vbox.move_child(lang_container, toolbar_idx)


func _update_labels() -> void:
	master_value.text = "%d%%" % int(master_slider.value * 100)
	music_value.text = "%d%%" % int(music_slider.value * 100)
	sfx_value.text = "%d%%" % int(sfx_slider.value * 100)


func _build_toolbar_binds() -> void:
	var toolbar_bg_tex = load("res://assets/sprites/ui/toolbar_bg.png") if ResourceLoader.exists("res://assets/sprites/ui/toolbar_bg.png") else null
	if toolbar_bg_tex:
		var tb_bg = TextureRect.new()
		tb_bg.texture = toolbar_bg_tex
		tb_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tb_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tb_bg.stretch_mode = TextureRect.STRETCH_SCALE
		tb_bg.anchors_preset = Control.PRESET_FULL_RECT
		tb_bg.anchor_right = 1.0
		tb_bg.anchor_bottom = 1.0
		tb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toolbar_container.add_child(tb_bg)

	var slot_tex = load("res://assets/sprites/ui/slot_bg.png") if ResourceLoader.exists("res://assets/sprites/ui/slot_bg.png") else null
	var grid = GridContainer.new()
	grid.columns = 3
	grid.anchors_preset = Control.PRESET_CENTER
	grid.anchor_left = 0.5
	grid.anchor_right = 0.5
	grid.anchor_top = 0.5
	grid.anchor_bottom = 0.5
	grid.offset_left = -95.5
	grid.offset_top = -95.5
	grid.offset_right = 102.5
	grid.offset_bottom = 102.5
	grid.scale = Vector2(1.4, 1.4)
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	toolbar_container.add_child(grid)

	_keybind_buttons = []
	for i in range(9):
		var slot = TextureRect.new()
		slot.custom_minimum_size = Vector2(44, 44)
		if slot_tex:
			slot.texture = slot_tex
			slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot.stretch_mode = TextureRect.STRETCH_SCALE

		var key_btn = Button.new()
		key_btn.text = _key_to_string(GameManager.toolbar_keybinds[i])
		key_btn.add_theme_font_size_override("font_size", 14)
		key_btn.flat = true
		key_btn.anchors_preset = Control.PRESET_FULL_RECT
		key_btn.anchor_right = 1.0
		key_btn.anchor_bottom = 1.0
		key_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		key_btn.pressed.connect(_on_rebind_pressed.bind(i, key_btn))
		slot.add_child(key_btn)
		_keybind_buttons.append(key_btn)

		grid.add_child(slot)


func _on_rebind_pressed(slot: int, btn: Button) -> void:
	_rebinding_slot = slot
	_rebinding_btn = btn
	btn.text = "..."


func _input(event: InputEvent) -> void:
	if _rebinding_slot >= 0 and event is InputEventKey and event.pressed:
		if event.keycode in FORBIDDEN_KEYS:
			if _rebinding_btn:
				_rebinding_btn.text = _key_to_string(GameManager.toolbar_keybinds[_rebinding_slot])
			_rebinding_slot = -1
			_rebinding_btn = null
			var al = get_node_or_null("/root/AlertSystem")
			if al:
				al.alert_error(tr("UI_KEY_RESERVED"))
			get_viewport().set_input_as_handled()
			return
		# Очищаем дубликат
		for i in range(GameManager.toolbar_keybinds.size()):
			if i != _rebinding_slot and GameManager.toolbar_keybinds[i] == event.keycode:
				GameManager.toolbar_keybinds[i] = 0
				if i < _keybind_buttons.size():
					_keybind_buttons[i].text = ""
		GameManager.toolbar_keybinds[_rebinding_slot] = event.keycode
		if _rebinding_btn:
			_rebinding_btn.text = _key_to_string(event.keycode)
		_rebinding_slot = -1
		_rebinding_btn = null
		get_viewport().set_input_as_handled()


func _key_to_string(keycode: int) -> String:
	if keycode == 0:
		return ""
	if keycode >= KEY_0 and keycode <= KEY_9:
		return str(keycode - KEY_0)
	if keycode >= KEY_A and keycode <= KEY_Z:
		return char(keycode)
	match keycode:
		KEY_SPACE: return "Space"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_TAB: return "Tab"
		KEY_ENTER: return "Enter"
		_: return OS.get_keycode_string(keycode)


func _set_resolution(w: int, h: int) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(w, h))
	DisplayServer.window_set_position((DisplayServer.screen_get_size() - Vector2i(w, h)) / 2)
	$Center/VBox/Fullscreen.button_pressed = false


func _on_back_pressed() -> void:
	back_pressed.emit()
