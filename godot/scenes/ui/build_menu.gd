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

@onready var item_list: GridContainer = $Margin/VBox/Scroll/ItemList

var is_open: bool = false
var selected_building: String = ""
var BUILDINGS: Dictionary = {}

var slot_bg: Texture2D = preload("res://assets/sprites/ui/slot_bg.png")


func _ready() -> void:
	visible = false
	BUILDINGS = Config.buildings
	_build_slots()


func _build_slots() -> void:
	for key in BUILDINGS:
		var data = BUILDINGS[key]
		if not data.has("hotkey"):
			continue

		# Слот-контейнер
		var slot = TextureRect.new()
		slot.texture = slot_bg
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.custom_minimum_size = Vector2(70, 70)
		slot.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		# Кнопка поверх слота
		var btn = Button.new()
		btn.anchor_left = 0.0
		btn.anchor_top = 0.0
		btn.anchor_right = 1.0
		btn.anchor_bottom = 1.0
		btn.offset_left = 4.0
		btn.offset_top = 4.0
		btn.offset_right = -4.0
		btn.offset_bottom = -4.0
		btn.flat = true
		btn.clip_contents = true

		# Иконка внутри кнопки
		var sprite_path = data.get("sprite", "")
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			var icon = TextureRect.new()
			icon.texture = load(sprite_path)
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.anchor_right = 1.0
			icon.anchor_bottom = 1.0
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(icon)

		# Тултип с инфой
		var hotkey = data.get("hotkey", "")
		var cost = data.get("cost", 0)
		var hp = data.get("hp", 0)
		var name_str = data.get("name", key)
		var desc = data.get("desc", "")
		btn.tooltip_text = "%s [%s]\nСтоимость: %d\nHP: %d\n%s" % [name_str, hotkey, cost, hp, desc]

		btn.pressed.connect(_on_slot_pressed.bind(key))
		slot.add_child(btn)
		item_list.add_child(slot)


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


func _on_slot_pressed(building_type: String) -> void:
	selected_building = building_type
	building_selected.emit(building_type)


func toggle_menu() -> void:
	is_open = not is_open
	visible = is_open


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			toggle_menu()
