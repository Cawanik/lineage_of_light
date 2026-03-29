# ==========================================
# main.gd — Главная сцена, тут всё начинается, ёб твою мать
# ==========================================
# _ready() — инициализирует инструменты (build/demolish/move/place), подключает сигналы, ставит трон и Лича
# _set_tool(tool_name) — переключает активный инструмент, деактивирует старый, активирует новый
# _on_build_button_pressed() — нажали кнопку строительства — открываем меню, нахуй
# _on_demolish_button_pressed() — включает инструмент сноса
# _on_move_button_pressed() — включает инструмент перемещения
# _on_building_selected(building_type) — выбрали здание в меню: wall -> build tool, остальное -> place tool
# _on_menu_visibility_changed() — если меню закрылось а build tool активен — деактивируем его
# _process(_delta) — каждый кадр дёргает update() активного инструмента
# _input(event) — F7 экспорт карты, F5 adjust стен, F6 adjust трона, ЛКМ -> клик инструмента
# ==========================================

extends Node2D

@export var throne_start_tile: Vector2i = Vector2i(14, 15)

@onready var placement_grid = $PlacementGrid
@onready var build_menu = $UILayer/BuildMenu
@onready var build_button: TextureButton = $UILayer/Toolbar/Grid/Slot1/BuildButton
@onready var demolish_button: TextureButton = $UILayer/Toolbar/Grid/Slot2/DemolishButton
@onready var move_button: TextureButton = $UILayer/Toolbar/Grid/Slot3/MoveButton
@onready var upgrade_button: TextureButton = $UILayer/Toolbar/Grid/Slot4/UpgradeButton
@onready var flat_view_button: TextureButton = $UILayer/Toolbar/Grid/Slot5/FlatViewButton
@onready var wall_system: WallSystem = $YSort/WallSystem
@onready var building_grid: BuildingGrid = $YSort/BuildingGrid

var active_tool: BaseTool = null
var active_tool_name: String = ""
var tools: Dictionary = {}
var place_tool: PlaceBuildingTool = PlaceBuildingTool.new()
const SLOT_ACTIVE_COLOR = Color(0.7, 0.4, 1.0, 1.0)
const SLOT_DEFAULT_COLOR = Color(1.0, 1.0, 1.0, 1.0)

# Хоткеи тулбара: слот -> действие. Клавиши 1-9
const BUILD_HOTKEYS: Array[Dictionary] = [
	{"key": KEY_1, "action": "build"},
	{"key": KEY_2, "action": "demolish"},
	{"key": KEY_3, "action": "move"},
	{"key": KEY_4, "action": "upgrade"},
	{"key": KEY_5, "action": "flat_view"},
	{"key": KEY_6, "action": ""},
	{"key": KEY_7, "action": ""},
	{"key": KEY_8, "action": ""},
	{"key": KEY_9, "action": ""},
]

var throne_scene: PackedScene = preload("res://scenes/buildings/throne.tscn")
var _camera_focused: bool = false
var _focus_building: Node2D = null
var _focus_range_highlights: Array[Node2D] = []
var _flat_view: bool = false
var _flat_labels: Array[Node2D] = []


func _ready() -> void:
	PhaseManager.init_game()
	tools = {
		"build": BuildTool.new(),
		"demolish": DemolishTool.new(),
		"move": MoveTool.new(),
		"place": place_tool,
		"upgrade": UpgradeTool.new(),
	}

	build_menu.building_selected.connect(_on_building_selected)
	build_menu.visibility_changed.connect(_on_menu_visibility_changed)
	build_button.pressed.connect(_on_build_button_pressed)
	demolish_button.pressed.connect(_on_demolish_button_pressed)
	move_button.pressed.connect(_on_move_button_pressed)
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	flat_view_button.pressed.connect(_on_flat_view_button_pressed)

	# Тултипы и ховер-эффекты
	build_button.tooltip_text = tr("TOOLTIP_BUILD")
	demolish_button.tooltip_text = tr("TOOLTIP_DEMOLISH")
	move_button.tooltip_text = tr("TOOLTIP_MOVE")
	upgrade_button.tooltip_text = tr("TOOLTIP_UPGRADE")
	flat_view_button.tooltip_text = tr("TOOLTIP_FLAT_VIEW")

	for btn in [build_button, demolish_button, move_button, upgrade_button, flat_view_button]:
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_entered.connect(func():
			btn.modulate = Color(1.3, 1.1, 1.4, 1.0)
			var am = get_node_or_null("/root/AudioManager")
			if am and am.sounds.has("ui_hover"):
				am.play("ui_hover")
		)
		btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func():
			var am = get_node_or_null("/root/AudioManager")
			if am:
				am.play("ui_click")
		)

	# Кнопка паузы в правом верхнем углу с подложкой slot_bg
	var pause_container = TextureRect.new()
	pause_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/sprites/ui/slot_bg.png"):
		pause_container.texture = load("res://assets/sprites/ui/slot_bg.png")
	pause_container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pause_container.stretch_mode = TextureRect.STRETCH_SCALE
	pause_container.anchors_preset = Control.PRESET_TOP_RIGHT
	pause_container.anchor_left = 1.0
	pause_container.anchor_right = 1.0
	pause_container.offset_left = -42
	pause_container.offset_top = 5
	pause_container.offset_right = -5
	pause_container.offset_bottom = 42
	pause_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UILayer.add_child(pause_container)

	var pause_btn = Button.new()
	pause_btn.text = "☰"
	pause_btn.add_theme_font_size_override("font_size", 18)
	pause_btn.flat = true
	pause_btn.add_theme_color_override("font_color", Color("#e8e0ff"))
	pause_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	pause_btn.anchors_preset = Control.PRESET_FULL_RECT
	pause_btn.anchor_right = 1.0
	pause_btn.anchor_bottom = 1.0
	pause_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(_toggle_pause_menu)
	pause_container.add_child(pause_btn)

	# Загружаем абилки из player.json
	_load_combat_abilities()

	# Лейблы хоткеев на слотах
	_add_hotkey_labels()

	# Place throne on tile (берём позицию из Ground)
	var ground = get_node_or_null("Ground") as IsoGround
	if ground:
		throne_start_tile = ground.throne_tile
	var throne = throne_scene.instantiate()
	building_grid.place_building(throne_start_tile, throne)

	# Спавним игрока рядом с троном
	var player_node = get_node_or_null("YSort/Player")
	if player_node:
		var free_tile = _find_free_tile_near(throne_start_tile)
		player_node.position = building_grid.tile_to_world(free_tile)

	# Connect throne destruction to game over
	throne.throne_destroyed.connect(GameManager.on_throne_destroyed)

	# Sync PathfindingSystem
	var ps = get_node_or_null("/root/PathfindingSystem")
	if ps:
		ps.throne_tile = throne_start_tile
		ps.set_tile_solid(throne_start_tile, false)

	# Connect wave signals
	if WaveManager:
		WaveManager.wave_started.connect(_on_wave_started)
		WaveManager.wave_completed.connect(_on_wave_completed)
		WaveManager.all_waves_completed.connect(_on_all_waves_completed)

	# Connect phase signals
	PhaseManager.phase_changed.connect(_on_phase_changed)

	# Применяем блокировку инструментов по навыкам
	call_deferred("_set_toolbar_mode", "build")

	# Туториал — запускаем если первый раз и не пройден
	if not GameManager.skip_tutorial and not GameManager.tutorial_completed and SkillManager.unlocked.size() == 0:
		var tutorial = Tutorial.new()
		tutorial.name = "Tutorial"
		add_child(tutorial)
	elif SkillManager.unlocked.size() == 0:
		# Без обучения — выдаём стартовые навыки
		for skill_id in SkillManager.DEFAULT_UNLOCKED:
			SkillManager.unlocked[skill_id] = true

	# Автосохранение при изменении кристаллов/навыков
	SkillManager.skill_unlocked.connect(_autosave)
	GameManager.connect("souls_changed", _autosave)

	# Перестраиваем меню при изменении зданий на карте
	building_grid.buildings_changed.connect(_on_buildings_changed)


# Маппинг id абилки из player.json -> id навыка в skill_tree.json
const ABILITY_TO_SKILL: Dictionary = {
	"magic_bolt": "magic_shot",
	"magic_missile": "magic_shot",
	"fireball": "fireball",
	"storm": "ball_lightning",
}


func _load_combat_abilities() -> void:
	_combat_abilities.clear()
	var abilities = Config.player.get("abilities", {})
	for id in abilities:
		if id == "magic_missile":
			continue  # замена magic_bolt через таланты, не отдельный слот
		var ab = abilities[id]
		var key_str = ab.get("key", "").to_upper()
		# Иконка из skill_tree через маппинг
		var icon = ""
		var skill_id = ABILITY_TO_SKILL.get(id, id)
		var st = Config.skill_tree.get(skill_id, {})
		if st.has("icon"):
			icon = st["icon"]
		_combat_abilities.append({
			"id": id,
			"name": ab.get("name", id),
			"key": key_str,
			"icon": icon,
		})


func _key_label(keycode: int) -> String:
	if keycode == 0:
		return ""
	if keycode >= KEY_0 and keycode <= KEY_9:
		return str(keycode - KEY_0)
	if keycode >= KEY_A and keycode <= KEY_Z:
		return char(keycode)
	return OS.get_keycode_string(keycode)


func _add_hotkey_labels() -> void:
	var toolbar_grid = get_node_or_null("UILayer/Toolbar/Grid")
	if not toolbar_grid:
		return
	var slots = toolbar_grid.get_children()
	for i in range(mini(9, slots.size())):
		var slot = slots[i]
		var lbl = Label.new()
		lbl.name = "HotkeyLabel"
		lbl.text = _key_label(GameManager.toolbar_keybinds[i])
		lbl.add_theme_font_size_override("font_size", 7)
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		lbl.offset_left = 4
		lbl.offset_top = 3
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Добавляем отложенно чтобы лейбл был поверх иконки
		slot.call_deferred("add_child", lbl)


func _update_hotkey_labels(mode: String) -> void:
	var toolbar_grid = get_node_or_null("UILayer/Toolbar/Grid")
	if not toolbar_grid:
		return
	var slots = toolbar_grid.get_children()
	for i in range(slots.size()):
		var lbl = slots[i].get_node_or_null("HotkeyLabel")
		if not lbl:
			continue
		if mode == "combat":
			if i < _combat_abilities.size():
				lbl.text = _key_label(GameManager.toolbar_keybinds[i])
				lbl.visible = true
			else:
				lbl.visible = false
		else:
			lbl.text = _key_label(GameManager.toolbar_keybinds[i])
			lbl.visible = true


func _handle_toolbar_hotkey(key_index: int) -> void:
	if PhaseManager.is_build_phase():
		if key_index >= BUILD_HOTKEYS.size():
			return
		var action = BUILD_HOTKEYS[key_index]["action"]
		if action == "" or not SkillManager.is_tool_unlocked(action):
			return
		match action:
			"build":
				_on_build_button_pressed()
			"demolish":
				_on_demolish_button_pressed()
			"move":
				_on_move_button_pressed()
			"upgrade":
				_on_upgrade_button_pressed()
			"flat_view":
				_on_flat_view_button_pressed()
	elif PhaseManager.is_combat_phase():
		if key_index < _combat_abilities.size():
			_on_ability_pressed(_combat_abilities[key_index]["id"])


func _get_tool_slot(tool_name: String) -> Node:
	match tool_name:
		"build", "place":
			return $UILayer/Toolbar/Grid/Slot1
		"demolish":
			return $UILayer/Toolbar/Grid/Slot2
		"move":
			return $UILayer/Toolbar/Grid/Slot3
		"upgrade":
			return $UILayer/Toolbar/Grid/Slot4
	return null


func _update_slot_highlights() -> void:
	for i in range(1, 10):
		var slot = get_node_or_null("UILayer/Toolbar/Grid/Slot%d" % i)
		if slot:
			slot.modulate = SLOT_DEFAULT_COLOR
	if active_tool_name != "":
		var active_slot = _get_tool_slot(active_tool_name)
		if active_slot:
			active_slot.modulate = SLOT_ACTIVE_COLOR


func _set_tool(tool_name: String) -> void:
	var same = active_tool == tools.get(tool_name)
	if active_tool:
		active_tool.deactivate()
		active_tool = null
		active_tool_name = ""
	build_menu.visible = false
	if not same and tools.has(tool_name):
		active_tool = tools[tool_name]
		active_tool_name = tool_name
		active_tool.activate(wall_system)
	_update_slot_highlights()


func _on_build_button_pressed() -> void:
	if active_tool:
		active_tool.deactivate()
		active_tool = null
		active_tool_name = ""
	build_menu.toggle_menu()
	_update_slot_highlights()


func _on_demolish_button_pressed() -> void:
	_set_tool("demolish")


func _on_move_button_pressed() -> void:
	_set_tool("move")


func _on_upgrade_button_pressed() -> void:
	_set_tool("upgrade")


var _flat_view_tex_closed = preload("res://assets/sprites/ui/icon_flat_view_0001.png")
var _flat_view_tex_open = preload("res://assets/sprites/ui/icon_flat_view_0002.png")

func _on_flat_view_button_pressed() -> void:
	if _flat_view:
		_disable_flat_view()
		flat_view_button.texture_normal = _flat_view_tex_closed
		flat_view_button.modulate = Color.WHITE
	else:
		_enable_flat_view()
		flat_view_button.texture_normal = _flat_view_tex_open
		flat_view_button.modulate = SLOT_ACTIVE_COLOR


func _on_building_selected(building_type: String) -> void:
	if building_type == "wall":
		_set_tool("build")
	else:
		place_tool.set_building_type(building_type)
		_set_tool("place")


func _on_menu_visibility_changed() -> void:
	if not build_menu.visible and active_tool == tools.get("build"):
		active_tool.deactivate()
		active_tool = null
		active_tool_name = ""
		_update_slot_highlights()


func _process(_delta: float) -> void:
	if active_tool:
		active_tool.update()

	# Обновляем оверлеи кулдаунов абилок
	if PhaseManager.is_combat_phase():
		_update_cooldown_overlays()

	# Автовозврат камеры при движении игрока
	if _camera_focused:
		var player_node = get_node_or_null("YSort/Player") as Player
		if player_node and player_node.velocity.length() > 1.0:
			_unfocus_camera()


func _input(event: InputEvent) -> void:
	# Хоткеи тулбара из настроек
	if event is InputEventKey and event.pressed:
		var key = event.keycode
		for i in range(GameManager.toolbar_keybinds.size()):
			if key == GameManager.toolbar_keybinds[i]:
				_handle_toolbar_hotkey(i)
				return

	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_unfocus_camera()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		var dev = get_node_or_null("UILayer/DevPanel")
		if dev:
			dev.visible = not dev.visible
		return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if active_tool:
				active_tool.click()
			else:
				_try_focus_building()
		else:
			# Отпускание ЛКМ — завершаем драг
			if active_tool and active_tool.has_method("on_release"):
				active_tool.on_release()

	# ПКМ — снять активный инструмент или закрыть меню строительства
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if active_tool:
			active_tool.deactivate()
			active_tool = null
			active_tool_name = ""
			_update_slot_highlights()
			if build_menu.is_open:
				build_menu.toggle_menu()
			get_viewport().set_input_as_handled()
			return
		elif build_menu.is_open:
			build_menu.toggle_menu()
			get_viewport().set_input_as_handled()
			return

	# ESC — снять инструмент, закрыть меню строительства или открыть меню паузы
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if active_tool:
			active_tool.deactivate()
			active_tool = null
			active_tool_name = ""
			_update_slot_highlights()
			if build_menu.is_open:
				build_menu.toggle_menu()
			get_viewport().set_input_as_handled()
			return
		elif build_menu.is_open:
			build_menu.toggle_menu()
			get_viewport().set_input_as_handled()
			return
		else:
			_toggle_pause_menu()
			get_viewport().set_input_as_handled()
			return


func _try_focus_building() -> void:
	if PhaseManager.is_combat_phase():
		return
	var mouse_pos = get_global_mouse_position()
	var tile = building_grid.find_nearest_building(mouse_pos, 30.0)
	if tile == Vector2i(-9999, -9999):
		if _camera_focused:
			_unfocus_camera()
		return
	var building = building_grid.get_building(tile)
	if not building:
		return

	var player_node = get_node_or_null("YSort/Player") as Player
	if not player_node or not player_node.camera:
		return

	# Сбрасываем предыдущий фокус если был
	if _camera_focused:
		for t in building_grid.buildings:
			var b2 = building_grid.get_building(t)
			if b2:
				b2.modulate = Color.WHITE
		BuildingInfoPanel.hide_panel(get_tree())

	_focus_building = building
	_camera_focused = true

	var target_pos = building_grid.tile_to_world(tile)
	var camera_offset = target_pos - player_node.global_position
	# Ограничиваем offset чтобы не вылезти за лимиты камеры
	var cam = player_node.camera
	var viewport_size = get_viewport().get_visible_rect().size
	var half_w = viewport_size.x / (2.0 * cam.zoom.x)
	var half_h = viewport_size.y / (2.0 * cam.zoom.y)
	var max_offset_x = maxf(0, (cam.limit_right - cam.limit_left) / 2.0 - half_w)
	var max_offset_y = maxf(0, (cam.limit_bottom - cam.limit_top) / 2.0 - half_h)
	camera_offset.x = clampf(camera_offset.x, -max_offset_x, max_offset_x)
	camera_offset.y = clampf(camera_offset.y, -max_offset_y, max_offset_y)

	var tween = create_tween()
	tween.tween_property(cam, "offset", camera_offset, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Отключаем occlusion fade и затемняем все здания кроме выбранного
	OcclusionFade.focus_mode = true
	for t in building_grid.buildings:
		var b = building_grid.get_building(t)
		if b and b != building:
			b.modulate = Color(1, 1, 1, 0.3)
	building.modulate = Color(1, 1, 1, 1)

	# Показываем инфо-панель и радиус атаки
	BuildingInfoPanel.show_for(building, target_pos, get_tree())
	_show_focus_range(tile, building.building_type)


func _show_focus_range(tile: Vector2i, btype: String) -> void:
	_clear_focus_range()
	var data = Config.buildings.get(btype, {})
	var range_cardinal = int(data.get("attack_range_cardinal", 0))
	var range_diagonal = int(data.get("attack_range_diagonal", 0))
	if range_cardinal == 0 and range_diagonal == 0:
		return

	var ground = get_node_or_null("Ground") as TileMapLayer
	var ysort = get_node_or_null("YSort")
	if not ground or not ysort:
		return

	var r = float(range_cardinal) + 0.5
	for dx in range(-range_cardinal, range_cardinal + 1):
		for dy in range(-range_cardinal, range_cardinal + 1):
			if dx == 0 and dy == 0:
				continue
			if sqrt(float(dx * dx + dy * dy)) > r:
				continue
			var t = tile + Vector2i(dx, dy)
			if not building_grid.is_on_ground(t):
				continue

			var marker = Node2D.new()
			marker.position = ground.map_to_local(t) + ground.position
			marker.z_index = 85
			marker.modulate = Color(1, 1, 1, 0.4)
			var draw_node = marker
			draw_node.draw.connect(func():
				var hw = 32.0
				var hh = 16.0
				var diamond = PackedVector2Array([
					Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
				])
				draw_node.draw_colored_polygon(diamond, Color(0.3, 0.6, 1.0, 0.3))
				for i in range(4):
					draw_node.draw_line(diamond[i], diamond[(i + 1) % 4], Color(0.4, 0.7, 1.0, 0.6), 1.5)
			)
			ysort.add_child(marker)
			marker.queue_redraw()
			_focus_range_highlights.append(marker)


func _clear_focus_range() -> void:
	for h in _focus_range_highlights:
		if is_instance_valid(h):
			h.queue_free()
	_focus_range_highlights.clear()


func _unfocus_camera() -> void:
	if not _camera_focused:
		return
	var player_node = get_node_or_null("YSort/Player") as Player
	if not player_node or not player_node.camera:
		return

	_camera_focused = false
	_focus_building = null
	BuildingInfoPanel.hide_panel(get_tree())
	_clear_focus_range()

	# Восстанавливаем прозрачность и occlusion
	OcclusionFade.focus_mode = false
	for tile in building_grid.buildings:
		var b = building_grid.get_building(tile)
		if b:
			b.modulate = Color.WHITE

	var tween = create_tween()
	tween.tween_property(player_node.camera, "offset", Vector2.ZERO, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_phase_changed(phase) -> void:
	if phase == PhaseManager.Phase.COMBAT:
		# Сбрасываем фокус
		if _camera_focused:
			_unfocus_camera()
		# Сбрасываем активный инструмент
		if active_tool:
			active_tool.deactivate()
			active_tool = null
			active_tool_name = ""
		# Выключаем flat view
		if _flat_view:
			_disable_flat_view()
		# Закрываем меню строительства
		build_menu.visible = false
		build_menu.is_open = false
		_update_slot_highlights()
		# Скрываем кнопки строительства
		_set_toolbar_mode("combat")
	elif phase == PhaseManager.Phase.BUILD:
		_set_toolbar_mode("build")


var _combat_abilities: Array[Dictionary] = []
var _ability_nodes: Array[Node] = []


func _set_toolbar_mode(mode: String) -> void:
	var toolbar_grid = get_node_or_null("UILayer/Toolbar/Grid")
	if not toolbar_grid:
		return

	# Убираем старые абилки
	for node in _ability_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_ability_nodes.clear()

	if mode == "combat":
		# Скрываем инструменты, но оставляем HotkeyLabel
		for slot in toolbar_grid.get_children():
			for child in slot.get_children():
				if child.name != "HotkeyLabel":
					child.visible = false
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Заполняем слоты только открытыми абилками
		var sm = get_node_or_null("/root/SkillManager")
		var visible_abilities: Array[Dictionary] = []
		for ab in _combat_abilities:
			if sm and sm.is_ability_unlocked(ab["id"]):
				visible_abilities.append(ab)
			elif not sm:
				visible_abilities.append(ab)

		var slots = toolbar_grid.get_children()
		for i in range(mini(visible_abilities.size(), slots.size())):
			var ability = visible_abilities[i]
			var slot = slots[i]
			var icon_path = ability.get("icon", "")

			var tex_btn = TextureButton.new()
			tex_btn.name = "AbilityBtn"
			tex_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tex_btn.ignore_texture_size = true
			tex_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			tex_btn.anchors_preset = Control.PRESET_FULL_RECT
			tex_btn.anchor_right = 1.0
			tex_btn.anchor_bottom = 1.0
			tex_btn.offset_left = 4
			tex_btn.offset_top = 4
			tex_btn.offset_right = -4
			tex_btn.offset_bottom = -4

			if icon_path != "" and ResourceLoader.exists(icon_path):
				tex_btn.texture_normal = load(icon_path)

			var ability_id = ability["id"]
			tex_btn.set_meta("ability_id", ability_id)
			tex_btn.pressed.connect(_on_ability_pressed.bind(ability_id))
			slot.add_child(tex_btn)
			tex_btn.visible = true
			_ability_nodes.append(tex_btn)

			# Индикатор авто-каста для magic_bolt
			if ability_id == "magic_bolt" or ability_id == "magic_missile":
				var sm_ac = get_node_or_null("/root/SkillManager")
				if sm_ac and sm_ac.is_autocast_unlocked(ability_id):
					var indicator_script = load("res://scenes/ui/autocast_indicator.gd")
					var indicator = Control.new()
					indicator.set_script(indicator_script)
					indicator.name = "AutocastIndicator"
					indicator.set("ability_id", ability_id)
					indicator.anchors_preset = Control.PRESET_FULL_RECT
					indicator.anchor_right = 1.0
					indicator.anchor_bottom = 1.0
					indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
					slot.add_child(indicator)

			# Оверлей кулдауна — чёрный прямоугольник сверху вниз
			var cd_overlay = ColorRect.new()
			cd_overlay.name = "CooldownOverlay"
			cd_overlay.color = Color(0, 0, 0, 0.6)
			cd_overlay.anchors_preset = Control.PRESET_FULL_RECT
			cd_overlay.anchor_right = 1.0
			cd_overlay.anchor_bottom = 1.0
			cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cd_overlay.visible = false
			slot.add_child(cd_overlay)
			_ability_nodes.append(cd_overlay)

			# Оверлей ГКД — показывается когда нет личного кд, но активен глобальный кулдаун
			var gcd_overlay = ColorRect.new()
			gcd_overlay.name = "GCDOverlay"
			gcd_overlay.color = Color(0, 0, 0, 0.6)
			gcd_overlay.anchors_preset = Control.PRESET_FULL_RECT
			gcd_overlay.anchor_right = 1.0
			gcd_overlay.anchor_bottom = 1.0
			gcd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gcd_overlay.visible = false
			slot.add_child(gcd_overlay)
			_ability_nodes.append(gcd_overlay)

			slot.mouse_filter = Control.MOUSE_FILTER_STOP

		# Обновляем лейблы хоткеев для абилок
		_update_hotkey_labels("combat")

	elif mode == "build":
		var sm = get_node_or_null("/root/SkillManager")
		var tool_names = ["build", "demolish", "move", "upgrade", "flat_view"]
		var slots = toolbar_grid.get_children()
		for i in range(slots.size()):
			var slot = slots[i]
			if i < tool_names.size() and sm:
				var tool_unlocked = sm.is_tool_unlocked(tool_names[i])
				for child in slot.get_children():
					if child.name == "HotkeyLabel":
						child.visible = tool_unlocked
					else:
						child.visible = tool_unlocked
				slot.mouse_filter = Control.MOUSE_FILTER_STOP if tool_unlocked else Control.MOUSE_FILTER_IGNORE
			else:
				# Пустые слоты
				for child in slot.get_children():
					if child.name != "HotkeyLabel":
						child.visible = false
				slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_update_hotkey_labels("build")


func _update_cooldown_overlays() -> void:
	var player = get_node_or_null("YSort/Player")
	if not player or not is_instance_valid(player):
		return
	var toolbar_grid = get_node_or_null("UILayer/Toolbar/Grid")
	if not toolbar_grid:
		return
	var slots = toolbar_grid.get_children()
	for i in range(slots.size()):
		var slot = slots[i]
		var overlay = slot.get_node_or_null("CooldownOverlay")
		if not overlay:
			continue
		# Находим id абилки по кнопке в слоте
		var btn = slot.get_node_or_null("AbilityBtn")
		if not btn or not btn.visible:
			overlay.visible = false
			continue
		# Ищем ability_id через сигнал pressed
		var ability_id = ""
		for ab in _combat_abilities:
			if btn.pressed.is_connected(_on_ability_pressed):
				ability_id = ab["id"]
				break
		# Проще: храним id в meta
		if btn.has_meta("ability_id"):
			ability_id = btn.get_meta("ability_id")
		if ability_id == "":
			continue
		var gcd_overlay = slot.get_node_or_null("GCDOverlay")
		var cd = player._cooldowns.get(ability_id, 0.0)
		var max_cd = player._abilities.get(ability_id, {}).get("cooldown", 1.0)
		if cd > 0:
			overlay.visible = true
			var ratio = clampf(cd / max_cd, 0.0, 1.0)
			overlay.anchor_top = 0.0
			overlay.anchor_bottom = ratio
			if gcd_overlay:
				gcd_overlay.visible = false
		elif player._gcd > 0.0:
			overlay.visible = false
			if gcd_overlay:
				gcd_overlay.visible = true
				var gcd_ratio = clampf(player._gcd / 0.8, 0.0, 1.0)
				gcd_overlay.anchor_top = 0.0
				gcd_overlay.anchor_bottom = gcd_ratio
		else:
			overlay.visible = false
			if gcd_overlay:
				gcd_overlay.visible = false


func _autosave(_arg = null) -> void:
	var slot = GameManager.current_save_slot
	var save_path = "user://saves/slot_%d.json" % slot
	# Загружаем текущие данные
	var data: Dictionary = {}
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			data = json.data
	# Обновляем кристаллы и навыки
	data["souls"] = GameManager.souls
	var skills: Array = []
	for skill_id in SkillManager.unlocked:
		skills.append(skill_id)
	data["unlocked_skills"] = skills
	data["tutorial_completed"] = GameManager.tutorial_completed
	var now = Time.get_datetime_dict_from_system()
	data["last_saved"] = "%04d-%02d-%02d %02d:%02d:%02d" % [now["year"], now["month"], now["day"], now["hour"], now["minute"], now["second"]]
	# Сохраняем
	DirAccess.make_dir_recursive_absolute("user://saves/")
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	print("[Autosave] Slot %d: souls=%d, skills=%d at %s" % [slot, data["souls"], skills.size(), data["last_saved"]])


func _toggle_pause_menu() -> void:
	var pm = get_node_or_null("PauseMenu")
	if not pm:
		return
	if pm._is_open:
		pm.close()
	else:
		pm.open()


func _on_buildings_changed() -> void:
	if PhaseManager.is_build_phase():
		# Отложенный rebuild чтобы не ломать UI в процессе размещения
		call_deferred("_deferred_rebuild_menu")


func _deferred_rebuild_menu() -> void:
	var bm = get_node_or_null("UILayer/BuildMenu")
	if bm and is_instance_valid(bm):
		bm.rebuild()


func _on_ability_pressed(ability_id: String) -> void:
	var sm = get_node_or_null("/root/SkillManager")
	if sm and not sm.is_ability_unlocked(ability_id):
		return
	var player = get_node_or_null("YSort/Player") as Player
	if not player:
		return
	player._try_cast(ability_id)


func _on_wave_started(wave_number: int) -> void:
	print("Wave %d started!" % wave_number)


func _on_wave_completed(wave_number: int) -> void:
	print("Wave %d completed!" % wave_number)


func _on_all_waves_completed() -> void:
	print("All waves completed! Victory!")
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.stop_music(2.0)
	await get_tree().create_timer(2.0).timeout
	var victory = load("res://scenes/ui/victory_screen.gd").new()
	add_child(victory)


func _find_free_tile_near(center: Vector2i) -> Vector2i:
	# BFS от центра — находим ближайший свободный тайл
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [center]
	visited[center] = true
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var current = queue.pop_front()
		if not building_grid.is_occupied(current) and current != center:
			return current
		for d in dirs:
			var n = current + d
			if not visited.has(n) and building_grid.is_on_ground(n):
				visited[n] = true
				queue.append(n)

	return center


func _enable_flat_view() -> void:
	if _flat_view:
		return
	_flat_view = true

	# Скрываем все здания и стены
	for tile in building_grid.buildings:
		var b = building_grid.get_building(tile)
		if b:
			b.visible = false
	if wall_system:
		wall_system.visible = false

	# Лич Кинг
	var lk = get_node_or_null("YSort/LichKing")
	if lk:
		lk.visible = false

	_draw_flat_labels()


func _draw_flat_labels() -> void:
	_clear_flat_labels()
	var ground = get_node_or_null("Ground") as TileMapLayer
	var ysort = get_node_or_null("YSort")
	if not ground or not ysort:
		return

	for tile in building_grid.buildings:
		var b = building_grid.get_building(tile)
		if not b:
			continue
		var world_pos = ground.map_to_local(tile) + ground.position
		var label_node = Node2D.new()
		label_node.position = world_pos
		label_node.z_index = 200

		var data = Config.buildings.get(b.building_type, {})
		var short = tr("BLD_" + b.building_type.to_upper() + "_SHORT")
		var tier = b.upgrade_level
		var tile_color = Color(0.6, 0.2, 0.8, 0.5)  # фиолетовый для зданий
		if b.building_type == "throne":
			tile_color = Color(0.8, 0.1, 0.1, 0.5)  # красный для трона
		elif b.building_type == "wall_block":
			tile_color = Color(0.3, 0.3, 0.5, 0.5)  # серый для стен

		var draw_n = label_node
		var display_text = short
		var tier_text = str(tier) if tier > 0 else ""
		draw_n.draw.connect(func():
			var hw = 32.0
			var hh = 16.0
			# Окраска тайла
			var diamond = PackedVector2Array([
				Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
			])
			draw_n.draw_colored_polygon(diamond, tile_color)
			# Название постройки
			draw_n.draw_string(ThemeDB.fallback_font, Vector2(-12, 3), display_text, HORIZONTAL_ALIGNMENT_CENTER, 24, 10, Color.WHITE)
			# Тир (цифра снизу)
			if tier_text != "":
				draw_n.draw_string(ThemeDB.fallback_font, Vector2(-5, 14), tier_text, HORIZONTAL_ALIGNMENT_CENTER, 10, 11, Color.WHITE)
		)
		ysort.add_child(label_node)
		label_node.queue_redraw()
		_flat_labels.append(label_node)


func refresh_flat_view() -> void:
	if _flat_view:
		# Скрываем все здания (включая новые)
		for tile in building_grid.buildings:
			var b = building_grid.get_building(tile)
			if b:
				b.visible = false
		_clear_flat_labels()
		_draw_flat_labels()


func _clear_flat_labels() -> void:
	for l in _flat_labels:
		if is_instance_valid(l):
			l.queue_free()
	_flat_labels.clear()


func _disable_flat_view() -> void:
	if not _flat_view:
		return
	_flat_view = false

	# Показываем здания обратно
	for tile in building_grid.buildings:
		var b = building_grid.get_building(tile)
		if b:
			b.visible = true
	if wall_system:
		wall_system.visible = true

	var lk = get_node_or_null("YSort/LichKing")
	if lk:
		lk.visible = true

	_clear_flat_labels()
	flat_view_button.texture_normal = _flat_view_tex_closed
	flat_view_button.modulate = Color.WHITE


func _print_matrix() -> void:
	var iso = Config.game.get("iso", {})
	var w: int = iso.get("grid_width", 32)
	var h: int = iso.get("grid_height", 32)
	# Найти тайл трона
	var throne_pos = Vector2i(-9999, -9999)
	for tile in building_grid.buildings:
		var b = building_grid.buildings[tile]
		if b.building_type == "throne":
			throne_pos = tile
			break

	print("=== MAP MATRIX %dx%d === (throne at %s)" % [w, h, throne_pos])
	for y in range(h):
		var row = ""
		for x in range(w):
			var tile = Vector2i(x, y)
			if building_grid.buildings.has(tile):
				var b = building_grid.buildings[tile]
				if b.building_type == "throne":
					row += "T "
				else:
					row += "B "
			elif wall_system.nodes.has(tile):
				row += "W "
			elif building_grid.is_border(tile):
				row += "S "
			elif throne_pos != Vector2i(-9999, -9999) and absi(tile.x - throne_pos.x) <= 1 and absi(tile.y - throne_pos.y) <= 1:
				row += "L "
			else:
				row += ". "
		print(row)
