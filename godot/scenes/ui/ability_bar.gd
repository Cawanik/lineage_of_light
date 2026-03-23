# ==========================================
# ability_bar.gd — Панель абилок, видна только в бою
# ==========================================

extends HBoxContainer

const SLOT_SIZE = 48
const SLOT_MARGIN = 4

# Абилки привязаны к клавишам Q, W, E
const ABILITY_SLOTS = [
	{"key": KEY_Q, "skill": "magic_shot", "projectile": "magic_bolt", "label": "Q"},
	{"key": KEY_W, "skill": "fireball", "projectile": "fireball", "label": "W"},
	{"key": KEY_E, "skill": "ball_lightning", "projectile": "ball_lightning", "label": "E"},
]

var _slots: Array[Dictionary] = []
var _cooldowns: Array[float] = [0.0, 0.0, 0.0]
const COOLDOWN_TIME = 1.0

@onready var _icon_cache: Dictionary = {}


func _skill_mgr() -> Node:
	return get_node_or_null("/root/SkillManager")


func _ready() -> void:
	visible = false
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", SLOT_MARGIN)

	_preload_icons()
	_build_slots()

	PhaseManager.phase_changed.connect(_on_phase_changed)


func _preload_icons() -> void:
	for slot_def in ABILITY_SLOTS:
		var skill_id = slot_def["skill"]
		var data = Config.skill_tree.get(skill_id, {})
		var icon_path = data.get("icon", "")
		if icon_path != "" and ResourceLoader.exists(icon_path) and not _icon_cache.has(icon_path):
			_icon_cache[icon_path] = load(icon_path)


func _build_slots() -> void:
	for child in get_children():
		child.queue_free()
	_slots.clear()

	for i in range(ABILITY_SLOTS.size()):
		var slot_def = ABILITY_SLOTS[i]

		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

		var tex_rect = TextureRect.new()
		tex_rect.name = "Icon"
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.custom_minimum_size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
		panel.add_child(tex_rect)

		# Лейбл клавиши
		var key_label = Label.new()
		key_label.text = slot_def["label"]
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.position = Vector2(2, 0)
		panel.add_child(key_label)

		# Кулдаун оверлей
		var cd_overlay = ColorRect.new()
		cd_overlay.name = "Cooldown"
		cd_overlay.color = Color(0, 0, 0, 0.5)
		cd_overlay.visible = false
		cd_overlay.anchors_preset = Control.PRESET_FULL_RECT
		cd_overlay.anchor_right = 1.0
		cd_overlay.anchor_bottom = 1.0
		cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(cd_overlay)

		add_child(panel)
		_slots.append({"panel": panel, "icon": tex_rect, "cooldown": cd_overlay, "def": slot_def})

	_refresh_icons()


func _refresh_icons() -> void:
	for slot in _slots:
		var skill_id = slot["def"]["skill"]
		var sm = _skill_mgr()
		var unlocked = sm.is_unlocked(skill_id) if sm else false
		var data = Config.skill_tree.get(skill_id, {})
		var icon_path = data.get("icon", "")

		slot["panel"].visible = true
		if _icon_cache.has(icon_path):
			slot["icon"].texture = _icon_cache[icon_path]

		if unlocked:
			slot["icon"].modulate = Color.WHITE
			slot["cooldown"].visible = false
		else:
			slot["icon"].modulate = Color(0.3, 0.3, 0.3)
			slot["cooldown"].visible = true


func _on_phase_changed(phase) -> void:
	if phase == PhaseManager.Phase.COMBAT:
		_refresh_icons()
		visible = true
	else:
		visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	# Кулдауны
	for i in range(_cooldowns.size()):
		if _cooldowns[i] > 0:
			_cooldowns[i] -= delta
			if _cooldowns[i] <= 0:
				_slots[i]["cooldown"].visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not PhaseManager.is_combat_phase():
		return
	if not (event is InputEventKey and event.pressed):
		return

	for i in range(ABILITY_SLOTS.size()):
		var slot_def = ABILITY_SLOTS[i]
		if event.keycode == slot_def["key"]:
			_cast_ability(i)
			get_viewport().set_input_as_handled()
			return


func _cast_ability(index: int) -> void:
	var slot_def = ABILITY_SLOTS[index]
	var skill_id = slot_def["skill"]

	# Проверяем что навык открыт
	var sm = _skill_mgr()
	if not sm or not sm.is_unlocked(skill_id):
		return

	# Проверяем кулдаун
	if _cooldowns[index] > 0:
		return

	# Находим игрока
	var player = get_tree().current_scene.get_node_or_null("YSort/Player")
	if not player:
		return

	# Кастуем
	var projectile_type = slot_def["projectile"]
	var mouse_pos = player.get_global_mouse_position()
	Projectile.spawn(get_tree(), projectile_type, player.global_position, mouse_pos)

	# Ставим кулдаун
	_cooldowns[index] = COOLDOWN_TIME
	_slots[index]["cooldown"].visible = true
