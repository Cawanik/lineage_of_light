# ==========================================
# skill_tree.gd — Экран дерева талантов с рендером узлов
# ==========================================

extends CanvasLayer

const NODE_RADIUS = 30.0
const LINE_COLOR = Color(0.3, 0.3, 0.3)
const LINE_COLOR_ACTIVE = Color(0.4, 0.8, 0.4)
const COLOR_UNLOCKED = Color(0.2, 0.8, 0.3)
const COLOR_AVAILABLE = Color(0.9, 0.8, 0.2)
const COLOR_HIDDEN = Color(0.3, 0.3, 0.3)
const COLOR_LOCKED = Color(0.5, 0.5, 0.5)
const BG_COLOR = Color(0.05, 0.05, 0.08)
const UNKNOWN_ICON_PATH = "res://assets/sprites/ui/icon_unknown_skill.png"
const UPGRADE_ICON_PATH = "res://assets/sprites/ui/upgrade_arrow.png"

var _canvas: Control
var _info_panel: Control
var _info_name: Label
var _info_desc: Label
var _info_cost: Label
var _unlock_btn: Button
var _souls_label: Label
var _selected_skill: String = ""

# Камера/скролл
var _offset: Vector2 = Vector2.ZERO
var _drag: bool = false
var _drag_start: Vector2 = Vector2.ZERO

# Кэш текстур
var _icon_cache: Dictionary = {}  # path -> Texture2D
var _unknown_icon: Texture2D = null
var _upgrade_icon: Texture2D = null


func _ready() -> void:
	visible = false
	layer = 100
	_preload_icons()

	# Убираем старые ноды из tscn
	for child in get_children():
		child.queue_free()

	# Фон
	var bg = ColorRect.new()
	bg.name = "BG"
	bg.color = BG_COLOR
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Canvas для отрисовки
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.anchors_preset = Control.PRESET_FULL_RECT
	_canvas.anchor_right = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.add_child(_canvas)
	_canvas.draw.connect(_on_canvas_draw)
	_canvas.gui_input.connect(_on_canvas_input)

	# Заголовок
	var title = Label.new()
	title.text = "Древо Талантов"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchors_preset = Control.PRESET_CENTER_TOP
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -100
	title.offset_right = 100
	title.offset_top = 10
	title.add_theme_font_size_override("font_size", 20)
	bg.add_child(title)

	# Souls counter top-right
	_souls_label = Label.new()
	_souls_label.anchors_preset = Control.PRESET_TOP_RIGHT
	_souls_label.anchor_left = 1.0
	_souls_label.anchor_right = 1.0
	_souls_label.offset_left = -200
	_souls_label.offset_right = -80
	_souls_label.offset_top = 15
	_souls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bg.add_child(_souls_label)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.anchors_preset = Control.PRESET_TOP_RIGHT
	close_btn.anchor_left = 1.0
	close_btn.anchor_right = 1.0
	close_btn.offset_left = -50
	close_btn.offset_right = -10
	close_btn.offset_top = 10
	close_btn.offset_bottom = 40
	close_btn.pressed.connect(close)
	bg.add_child(close_btn)

	# Info panel (bottom-left)
	_info_panel = PanelContainer.new()
	_info_panel.anchors_preset = Control.PRESET_BOTTOM_LEFT
	_info_panel.anchor_top = 1.0
	_info_panel.anchor_bottom = 1.0
	_info_panel.offset_left = 10
	_info_panel.offset_top = -130
	_info_panel.offset_right = 280
	_info_panel.offset_bottom = -10
	_info_panel.visible = false
	bg.add_child(_info_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_info_panel.add_child(vbox)

	_info_name = Label.new()
	_info_name.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_info_name)

	_info_desc = Label.new()
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_desc.custom_minimum_size.x = 250
	vbox.add_child(_info_desc)

	_info_cost = Label.new()
	vbox.add_child(_info_cost)

	_unlock_btn = Button.new()
	_unlock_btn.text = "Изучить"
	_unlock_btn.pressed.connect(_on_unlock_pressed)
	vbox.add_child(_unlock_btn)

	# Центрируем вид
	_offset = _calc_center_offset()

	SkillManager.skill_unlocked.connect(_on_skill_unlocked)


func _calc_center_offset() -> Vector2:
	# Находим центр всех навыков
	var min_pos = Vector2(99999, 99999)
	var max_pos = Vector2(-99999, -99999)
	for id in Config.skill_tree:
		var pos_arr = Config.skill_tree[id].get("position", [0, 0])
		var pos = Vector2(pos_arr[0], pos_arr[1])
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
	var center = (min_pos + max_pos) * 0.5
	var vp = get_viewport().get_visible_rect().size
	return vp * 0.5 - center


func open() -> void:
	visible = true
	_selected_skill = ""
	_info_panel.visible = false
	_offset = _calc_center_offset()
	_update_souls_label()
	_canvas.queue_redraw()
	GameManager.pause_game()


func close() -> void:
	visible = false
	GameManager.resume_game()
	# Обновляем тулбар и меню строительства после возможных изменений
	var main = get_tree().current_scene
	if main:
		main.call("_set_toolbar_mode", "build")
		var bm = main.get_node_or_null("UILayer/BuildMenu")
		if bm:
			bm.call("rebuild")


func _update_souls_label() -> void:
	_souls_label.text = "Души: %d" % GameManager.souls


func _on_skill_unlocked(_skill_id: String) -> void:
	_update_souls_label()
	_update_info_panel()
	_canvas.queue_redraw()


func _on_canvas_draw() -> void:
	var tree = Config.skill_tree

	# Рисуем линии связей
	for id in tree:
		var data = tree[id]
		var pos = Vector2(data["position"][0], data["position"][1]) + _offset
		var requires = data.get("requires", [])
		for req_id in requires:
			if not tree.has(req_id):
				continue
			var req_data = tree[req_id]
			var req_pos = Vector2(req_data["position"][0], req_data["position"][1]) + _offset
			var both_unlocked = SkillManager.is_unlocked(id) and SkillManager.is_unlocked(req_id)
			var col = LINE_COLOR_ACTIVE if both_unlocked else LINE_COLOR
			_canvas.draw_line(req_pos, pos, col, 2.0)

	# Рисуем узлы
	for id in tree:
		var data = tree[id]
		var pos = Vector2(data["position"][0], data["position"][1]) + _offset
		var state = SkillManager.get_state(id)

		var fill_color: Color
		var outline_color: Color
		match state:
			"unlocked":
				fill_color = Color(0.1, 0.3, 0.15)
				outline_color = COLOR_UNLOCKED
			"available":
				fill_color = Color(0.25, 0.22, 0.1)
				outline_color = COLOR_AVAILABLE
			_:
				fill_color = Color(0.12, 0.12, 0.12)
				outline_color = COLOR_HIDDEN

		# Круг заливка
		_canvas.draw_circle(pos, NODE_RADIUS, fill_color)
		# Круг обводка
		_draw_circle_outline(pos, NODE_RADIUS, outline_color, 2.0)

		# Иконка
		var icon_path = data.get("icon", "")
		var has_icon = icon_path != "" and ResourceLoader.exists(icon_path)

		if has_icon and state != "hidden":
			_draw_icon(pos, icon_path, NODE_RADIUS * 1.4)
			# Бейдж улучшения — если иконка совпадает с родительской
			if _is_upgrade_node(id, data) and _upgrade_icon:
				var badge_pos = pos + Vector2(-NODE_RADIUS * 0.45, -NODE_RADIUS * 0.45)
				var badge_size = Vector2(16, 16)
				_canvas.draw_texture_rect(_upgrade_icon, Rect2(badge_pos - badge_size * 0.5, badge_size), false)
		else:
			_draw_icon(pos, UNKNOWN_ICON_PATH, NODE_RADIUS * 1.2)

		# Подсветка выделенного
		if id == _selected_skill:
			_draw_circle_outline(pos, NODE_RADIUS + 4, Color.WHITE, 2.0)


func _is_upgrade_node(id: String, data: Dictionary) -> bool:
	var icon = data.get("icon", "")
	if icon == "":
		return false
	var requires = data.get("requires", [])
	for req_id in requires:
		var req_data = Config.skill_tree.get(req_id, {})
		if req_data.get("icon", "") == icon:
			return true
	return false


func _preload_icons() -> void:
	# Unknown icon
	if ResourceLoader.exists(UNKNOWN_ICON_PATH):
		_unknown_icon = load(UNKNOWN_ICON_PATH)
	if ResourceLoader.exists(UPGRADE_ICON_PATH):
		_upgrade_icon = load(UPGRADE_ICON_PATH)
	# Все иконки из конфига
	for id in Config.skill_tree:
		var icon_path = Config.skill_tree[id].get("icon", "")
		if icon_path != "" and ResourceLoader.exists(icon_path) and not _icon_cache.has(icon_path):
			_icon_cache[icon_path] = load(icon_path)


func _draw_icon(center: Vector2, path: String, target_size: float) -> void:
	var tex: Texture2D = null
	if path == UNKNOWN_ICON_PATH:
		tex = _unknown_icon
	else:
		tex = _icon_cache.get(path)
	if not tex:
		return
	var tex_size = tex.get_size()
	var scale_factor = target_size / max(tex_size.x, tex_size.y)
	var draw_size = tex_size * scale_factor
	_canvas.draw_texture_rect(tex, Rect2(center - draw_size * 0.5, draw_size), false)


func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points = 32
	for i in range(points):
		var a1 = TAU * i / points
		var a2 = TAU * (i + 1) / points
		_canvas.draw_line(
			center + Vector2(cos(a1), sin(a1)) * radius,
			center + Vector2(cos(a2), sin(a2)) * radius,
			color, width
		)


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Проверяем клик по узлу
				var clicked = _get_skill_at(event.position)
				if clicked != "":
					_selected_skill = clicked
					_update_info_panel()
					_canvas.queue_redraw()
				else:
					_drag = true
					_drag_start = event.position
			else:
				_drag = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_selected_skill = ""
			_info_panel.visible = false
			_canvas.queue_redraw()

	elif event is InputEventMouseMotion and _drag:
		_offset += event.relative
		_canvas.queue_redraw()


func _get_skill_at(pos: Vector2) -> String:
	var tree = Config.skill_tree
	for id in tree:
		var data = tree[id]
		var node_pos = Vector2(data["position"][0], data["position"][1]) + _offset
		if pos.distance_to(node_pos) <= NODE_RADIUS:
			return id
	return ""


func _update_info_panel() -> void:
	if _selected_skill == "":
		_info_panel.visible = false
		return

	var data = Config.skill_tree.get(_selected_skill, {})
	if data.is_empty():
		_info_panel.visible = false
		return

	_info_panel.visible = true
	_info_name.text = data.get("name", "")
	_info_desc.text = data.get("desc", "")

	var state = SkillManager.get_state(_selected_skill)
	var cost = int(data.get("cost", 1))

	match state:
		"unlocked":
			_info_cost.text = "Изучено"
			_unlock_btn.visible = false
		"available":
			_info_cost.text = "Стоимость: %d душ" % cost
			_unlock_btn.visible = true
			_unlock_btn.disabled = not SkillManager.can_unlock(_selected_skill)
		_:
			_info_cost.text = "???"
			_unlock_btn.visible = false


func _on_unlock_pressed() -> void:
	if _selected_skill != "":
		SkillManager.unlock(_selected_skill)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
