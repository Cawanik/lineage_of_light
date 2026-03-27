# ==========================================
# skill_tree_button.gd — Кнопка дерева развития, растёт с прокачкой
# ==========================================

extends TextureRect

const GROWTH_PATH = "res://assets/sprites/skill_tree/"
const SKILLS_PER_STAGE = 5
const MAX_STAGES = 14

var _stages: Array[Texture2D] = []
var _icon: TextureRect = null


func _ready() -> void:
	mouse_entered.connect(func(): modulate = Color(1.3, 1.1, 1.4, 1.0))
	mouse_exited.connect(func(): modulate = Color.WHITE)

	_icon = get_node_or_null("Icon")

	# Загружаем все стадии
	for i in range(1, MAX_STAGES + 1):
		var path = GROWTH_PATH + "growth_%02d.png" % i
		if ResourceLoader.exists(path):
			_stages.append(load(path))

	# Подписываемся на открытие навыков
	var sm = get_node_or_null("/root/SkillManager")
	if sm:
		sm.skill_unlocked.connect(_on_skill_unlocked)

	_update_icon()


func _on_skill_unlocked(_skill_id: String) -> void:
	_update_icon()


func _update_icon() -> void:
	if _stages.is_empty() or not _icon:
		return
	var sm = get_node_or_null("/root/SkillManager")
	var unlocked_count = sm.unlocked.size() if sm else 0
	var stage_index = clampi(unlocked_count / SKILLS_PER_STAGE, 0, _stages.size() - 1)
	_icon.texture = _stages[stage_index]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not PhaseManager.is_build_phase():
			return
		var am = get_node_or_null("/root/AudioManager")
		if am:
			am.play("ui_click")
		var skill_tree = get_tree().current_scene.get_node_or_null("SkillTree")
		if skill_tree:
			skill_tree.open()
