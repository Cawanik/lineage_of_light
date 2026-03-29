# ==========================================
# build_menu.gd — Меню строительства, компактное нахуй
# ==========================================
# _ready() — прячет меню, грузит конфиг, строит слоты
# _build_slots() — генерит слоты из конфига с иконками и тултипами
# _on_slot_pressed(building_type) — шлёт сигнал выбора здания
# toggle_menu() — открыть/закрыть
# _input(event) — B тоглит меню
# ==========================================

extends TextureRect

signal building_selected(building_type: String)

@export_group("Настройки слотов")
@export var slot_texture: Texture2D = preload("res://assets/sprites/ui/slot_bg.png")
@export var slot_size: Vector2 = Vector2(40, 40)
@export var slot_padding: float = 4.0
@export_group("Внутренние отступы")
@export var margin_left: int = 16
@export var margin_top: int = 20
@export var margin_right: int = 16
@export var margin_bottom: int = 20

@export_group("Заголовок")
@export var title_text: String = "СТРОЙ"
@export var font_size: int = 22
@export var cost_font_size: int = 22
@export var hotkey_font_size: int = 22

@onready var item_list: VBoxContainer = $Margin/VBox/Scroll/ItemList
@onready var title_label: Label = $Margin/VBox/Title

var is_open: bool = false
var selected_building: String = ""
var BUILDINGS: Dictionary = {}


func _ready() -> void:
	visible = false
	var margin = $Margin as MarginContainer
	if margin:
		margin.add_theme_constant_override("margin_left", margin_left)
		margin.add_theme_constant_override("margin_top", margin_top)
		margin.add_theme_constant_override("margin_right", margin_right)
		margin.add_theme_constant_override("margin_bottom", margin_bottom)
	if title_label:
		title_label.text = title_text
	if not Engine.is_editor_hint():
		BUILDINGS = Config.buildings
		_build_slots()


func _build_slots() -> void:
	for key in BUILDINGS:
		var data = BUILDINGS[key]
		if not data.has("hotkey"):
			continue
		# Скрываем заблокированные здания
		var sm = get_node_or_null("/root/SkillManager")
		if sm and not sm.is_building_unlocked(key):
			continue
		# Тир 2 здания — если навык требует epoch_gate, нужны врата на карте
		if sm:
			var skill_data = Config.skill_tree.get(key, {})
			var requires = skill_data.get("requires", [])
			if "epoch_gate" in requires and not sm.is_epoch_active():
				continue
		_add_building_row(key, data)


func _add_building_row(key: String, data: Dictionary) -> void:
	# Вся строка — кнопка
	var row_btn = Button.new()
	row_btn.flat = true
	row_btn.custom_minimum_size = Vector2(0, slot_size.y)
	row_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row_btn.pressed.connect(_on_slot_pressed.bind(key))
	row_btn.mouse_entered.connect(func(): row_btn.modulate = Color(1.2, 1.1, 1.3, 1.0))
	row_btn.mouse_exited.connect(func(): row_btn.modulate = Color.WHITE)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Иконка
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = slot_size
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sprite_path = data.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		icon_rect.texture = load(sprite_path)

	row.add_child(icon_rect)

	# Текст справа
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hotkey = data.get("hotkey", "")
	var bld_key = "BLD_" + key.to_upper()
	var name_str = tr(bld_key + "_NAME")

	# Название с clip — если длинное, обрезается
	var name_label = Label.new()
	name_label.text = name_str
	name_label.add_theme_color_override("font_color", Color("#e8e0ff"))
	name_label.add_theme_font_size_override("font_size", font_size)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_label)

	# Хоткей + стоимость в одной строке
	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 4)
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cost_label = Label.new()
	cost_label.text = "%d" % data.get("cost", 0)
	cost_label.add_theme_color_override("font_color", Color("#f0d060"))
	cost_label.add_theme_font_size_override("font_size", cost_font_size)
	bottom_row.add_child(cost_label)

	info.add_child(bottom_row)

	row.add_child(info)

	# Тултип
	var hp = data.get("hp", 0)
	var desc = tr(bld_key + "_DESC")
	row_btn.tooltip_text = "%s\nHP: %d\n%s" % [name_str, hp, desc]

	row_btn.add_child(row)
	item_list.add_child(row_btn)


func _add_empty_row() -> void:
	var row = HBoxContainer.new()

	var icon_container = TextureRect.new()
	icon_container.texture = slot_texture
	icon_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_container.custom_minimum_size = slot_size
	icon_container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_container.modulate = Color(1, 1, 1, 0.3)
	row.add_child(icon_container)

	var label = Label.new()
	label.text = "???"
	label.add_theme_color_override("font_color", Color("#666666"))
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	item_list.add_child(row)


func _create_wall_icon() -> TextureRect:
	# Рисуем столб стены процедурно в Image
	var size = 64
	var img = Image.create(size, size, true, Image.FORMAT_RGBA8)

	var cx = size / 2.0
	var cy = size * 0.7
	var r = 6.0
	var h = 36.0
	var col_front = Color(0.29, 0.27, 0.38)
	var col_side = Color(0.16, 0.14, 0.25)
	var col_top = Color(0.47, 0.46, 0.56)
	var col_dark = Color(0.1, 0.06, 0.19)

	# Рисуем прямоугольник тела столба
	for y in range(int(cy - h), int(cy)):
		for x in range(int(cx - r), int(cx + r)):
			if x >= 0 and x < size and y >= 0 and y < size:
				var t = float(x - (cx - r)) / (2.0 * r)
				var col = col_front.lerp(col_side, t)
				img.set_pixel(x, y, col)

	# Верхний овал
	for a in range(360):
		var rad = deg_to_rad(a)
		var px = int(cx + cos(rad) * r)
		var py = int(cy - h + sin(rad) * r * 0.5)
		if px >= 0 and px < size and py >= 0 and py < size:
			img.set_pixel(px, py, col_top)

	# Заливка верхнего овала
	for y in range(int(cy - h - r * 0.5), int(cy - h + r * 0.5)):
		for x in range(int(cx - r), int(cx + r)):
			if x >= 0 and x < size and y >= 0 and y < size:
				var dx = (x - cx) / r
				var dy = (y - (cy - h)) / (r * 0.5)
				if dx * dx + dy * dy <= 1.0:
					img.set_pixel(x, y, col_top)

	# Контур
	for y_i in range(int(cy - h), int(cy)):
		if int(cx - r) >= 0 and int(cx - r) < size and y_i >= 0 and y_i < size:
			img.set_pixel(int(cx - r), y_i, col_dark)
		if int(cx + r - 1) >= 0 and int(cx + r - 1) < size and y_i >= 0 and y_i < size:
			img.set_pixel(int(cx + r - 1), y_i, col_dark)

	var tex = ImageTexture.create_from_image(img)
	var icon = TextureRect.new()
	icon.texture = tex
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon


func rebuild() -> void:
	if not is_instance_valid(item_list):
		return
	for child in item_list.get_children():
		item_list.remove_child(child)
		child.queue_free()
	_build_slots()


func _on_slot_pressed(building_type: String) -> void:
	selected_building = building_type
	building_selected.emit(building_type)
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play("ui_click")


func toggle_menu() -> void:
	is_open = not is_open
	visible = is_open


func close_menu() -> void:
	if is_open:
		is_open = false
		visible = false


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_menu()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		close_menu()
		get_viewport().set_input_as_handled()
