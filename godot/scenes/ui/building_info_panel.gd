# ==========================================
# building_info_panel.gd — Панель информации и улучшений здания
# ==========================================

class_name BuildingInfoPanel
extends Control

var _building: Building = null
var _world_offset: Vector2 = Vector2(0, 10)
var _panel_width: float = 680.0
var _panel_height: float = 240.0

static var _instance: BuildingInfoPanel = null


static func show_for(building: Building, world_pos: Vector2, tree: SceneTree) -> void:
	hide_panel(tree)

	var data = Config.buildings.get(building.building_type, {})
	if data.is_empty():
		return

	var panel = BuildingInfoPanel.new()
	panel._building = building

	# В UILayer чтобы не масштабировалось зумом
	var ui_layer = tree.current_scene.get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(panel)
	else:
		tree.current_scene.add_child(panel)

	panel._create_ui(data)
	panel._fade_in()
	_instance = panel


static func hide_panel(tree: SceneTree) -> void:
	if _instance and is_instance_valid(_instance):
		_instance._fade_out()
		_instance = null


func _process(_delta: float) -> void:
	if not is_instance_valid(_building):
		return
	# Пересчитываем позицию из мировых в экранные координаты
	var canvas = get_viewport().get_canvas_transform()
	var screen_pos = canvas * (_building.global_position + _world_offset)
	position = screen_pos - Vector2(_panel_width * 0.5, 0)


func _create_ui(data: Dictionary) -> void:
	var hw = _panel_width * 0.5

	# Фон
	var bg_tex = load("res://assets/sprites/ui/upgrade_panel_bg.png")
	var bg = TextureRect.new()
	bg.texture = bg_tex
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.custom_minimum_size = Vector2(_panel_width, _panel_height)
	bg.size = Vector2(_panel_width, _panel_height)
	bg.position = Vector2(0, 0)
	add_child(bg)

	# Контейнер
	var margin = MarginContainer.new()
	margin.position = Vector2(30, 40)
	margin.size = Vector2(_panel_width - 60, _panel_height - 45)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, _panel_height - 50)
	margin.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# === Верхняя строка: иконка + название + кнопка upgrade ===
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vbox.add_child(top_row)

	# Иконка
	var sprite_path = data.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var icon = TextureRect.new()
		icon.texture = load(sprite_path)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(60, 60)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top_row.add_child(icon)

	# Название + HP
	var name_vbox = VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_vbox.add_theme_constant_override("separation", 1)
	top_row.add_child(name_vbox)

	var name_label = Label.new()
	var bld_key = "BLD_" + _building.building_type.to_upper()
	var base_name = tr(bld_key + "_NAME")
	var upgrades = data.get("upgrades", [])
	var upgrade_level = _building.upgrade_level
	if upgrade_level > 0 and upgrade_level <= upgrades.size():
		var last_upgrade = upgrades[upgrade_level - 1]
		name_label.text = tr("UI_TIER_FORMAT") % [last_upgrade.get("name", base_name), upgrade_level]
	else:
		name_label.text = base_name
	name_label.add_theme_color_override("font_color", Color("#e8e0ff"))
	name_label.add_theme_font_size_override("font_size", 16)
	name_vbox.add_child(name_label)

	var hp_label = Label.new()
	hp_label.text = tr("UI_HP_FORMAT") % [int(_building.hp), int(_building.max_hp)]
	hp_label.add_theme_color_override("font_color", Color("#66cc66"))
	hp_label.add_theme_font_size_override("font_size", 12)
	name_vbox.add_child(hp_label)

	# Кнопка апгрейда (если есть и навык открыт)
	if upgrades.size() > upgrade_level:
		var sm = get_node_or_null("/root/SkillManager")
		var max_lvl = 999
		if sm and sm.has_method("get_max_upgrade_level"):
			max_lvl = sm.get_max_upgrade_level(_building.building_type)
		if upgrade_level < max_lvl:
			var next_upgrade = upgrades[upgrade_level]
			var upgrade_btn = _create_upgrade_button(next_upgrade, upgrade_level)
			top_row.add_child(upgrade_btn)

	# === Описание ===
	var desc = tr(bld_key + "_DESC")
	if desc != "":
		var desc_label = Label.new()
		desc_label.text = desc
		desc_label.add_theme_color_override("font_color", Color("#9988bb"))
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(desc_label)

	# === Характеристики ===
	var stats = VBoxContainer.new()
	stats.add_theme_constant_override("separation", 2)
	vbox.add_child(stats)

	var stats_row = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 10)
	stats.add_child(stats_row)

	if _building.attack_speed > 0:
		_add_stat(stats_row, "Атака: %.1f/с" % _building.attack_speed, "#ff8866")
	if _building.attack_range_cardinal > 0:
		_add_stat(stats_row, "Радиус: %d" % _building.attack_range_cardinal, "#6699ff")
	if _building.contact_damage > 0:
		_add_stat(stats_row, "Шипы: %.0f" % _building.contact_damage, "#ff6666")

	# Список применённых апгрейдов
	if upgrade_level > 0:
		for i in range(upgrade_level):
			if i < upgrades.size():
				var u = upgrades[i]
				var u_label = Label.new()
				u_label.text = "+ %s" % u.get("desc", u.get("name", ""))
				u_label.add_theme_color_override("font_color", Color("#88cc88"))
				u_label.add_theme_font_size_override("font_size", 10)
				stats.add_child(u_label)

	# Счётчик апгрейдов
	if upgrades.size() > 0:
		var upgrades_label = Label.new()
		var applied = mini(upgrade_level, upgrades.size())
		upgrades_label.text = tr("UI_UPGRADES_COUNT") % [applied, upgrades.size()]
		upgrades_label.add_theme_color_override("font_color", Color("#f0d060"))
		upgrades_label.add_theme_font_size_override("font_size", 10)
		stats.add_child(upgrades_label)


func _create_upgrade_button(upgrade: Dictionary, level: int) -> Control:
	var slot = Control.new()
	slot.custom_minimum_size = Vector2(60, 60)

	# Подложка
	var slot_tex = load("res://assets/sprites/ui/slot_bg.png")
	var bg_rect = TextureRect.new()
	bg_rect.texture = slot_tex
	bg_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg_rect)

	# Кнопка с иконкой
	var btn = Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.offset_left = 4
	btn.offset_top = 4
	btn.offset_right = -4
	btn.offset_bottom = -4

	var upgrade_icon_path = "res://assets/sprites/ui/upgrade_arrow.png"
	if ResourceLoader.exists(upgrade_icon_path):
		btn.icon = load(upgrade_icon_path)
		btn.expand_icon = true

	btn.tooltip_text = "%s\nЦена: %d\n%s" % [upgrade["name"], upgrade["cost"], upgrade["desc"]]
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_entered.connect(func(): slot.modulate = Color(1.3, 1.1, 1.4, 1.0))
	btn.mouse_exited.connect(func(): slot.modulate = Color.WHITE)

	btn.pressed.connect(func(): _apply_upgrade(upgrade, level))
	slot.add_child(btn)
	return slot


func _apply_upgrade(upgrade: Dictionary, level: int) -> void:
	if not is_instance_valid(_building):
		return
	var cost = int(upgrade.get("cost", 0))
	if not GameManager.spend_gold(cost):
		var as_node = get_node_or_null("/root/AlertSystem")
		if as_node:
			as_node.alert_error(tr("UI_NOT_ENOUGH_GOLD") % [cost])
		return

	# HP бонус
	var hp_bonus = upgrade.get("hp_bonus", 0)
	if hp_bonus > 0:
		_building.max_hp += hp_bonus
		_building.hp += hp_bonus

	# Смена спрайта (опционально)
	var new_sprite = upgrade.get("sprite", "")
	if new_sprite != "" and ResourceLoader.exists(new_sprite):
		_building.sprite.texture = load(new_sprite)

	# Урон при контакте (шипы)
	var dmg_bonus = upgrade.get("damage_bonus", 0)
	if dmg_bonus > 0:
		_building.contact_damage += dmg_bonus

	# Доп. юниты на башне (опционально)
	var extra_units = int(upgrade.get("extra_units", 0))
	if extra_units > 0:
		var data = Config.buildings.get(_building.building_type, {})
		for i in range(extra_units):
			_building._setup_unit(data)

	_building.upgrade_level = level + 1

	# Пуф + звук
	DustEffect.spawn(get_tree(), _building.global_position)
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play("upgrade")

	# Обновляем flat view если активен
	var main = get_tree().current_scene
	if main and main.has_method("refresh_flat_view") and main.get("_flat_view"):
		main.refresh_flat_view()

	# Переоткрываем панель чтобы обновить кнопки
	var b = _building
	var tree = get_tree()
	hide_panel(tree)
	show_for(b, b.global_position, tree)

	# Перерисовываем панель
	BuildingInfoPanel.show_for(_building, _building.global_position + Vector2(0, 30), get_tree())


func _add_stat(parent: Node, text: String, color: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(color))
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)


func _fade_in() -> void:
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)


func _fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
