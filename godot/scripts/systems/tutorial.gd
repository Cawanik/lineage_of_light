# ==========================================
# tutorial.gd — Система обучения, стейт-машина
# ==========================================

class_name Tutorial
extends Node

signal tutorial_finished

enum Step {
	INTRO,
	WAIT_MOVE,
	EXPLAIN_QUEST,
	WAIT_SKILL_TREE,
	GIVE_CRYSTALS,
	WAIT_SKILLS_UNLOCKED,
	BOOK_INTRO,
	OWNER_LEAVES,
	WAIT_BUILD_ARCHERS,
	ENEMY_ARRIVES,
	WAIT_ENEMY_DEAD,
	OUTRO,
	DONE
}

var current_step: Step = Step.INTRO
var _player_moved: bool = false
var _skill_tree_opened: bool = false
var _required_skills_unlocked: bool = false
var _archers_placed: bool = false
var _tutorial_enemy_dead: bool = false
var _dialogue_box: DialogueBox = null
var tutorial_restrict_placement: bool = false
var tutorial_allowed_tiles: Array[Vector2i] = []
var _block_layer: CanvasLayer = null
var _block_rect: ColorRect = null

const REQUIRED_SKILLS = ["build_plan", "archers", "flat_view", "magic_abilities"]
const PORTRAIT_OWNER = "res://assets/sprites/ui/portraits/portrait_owner.png"
const PORTRAIT_BOOK = "res://assets/sprites/ui/skills/icon_grimoire.png"
const PORTRAIT_KNIGHT = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

	# Отложенный старт чтобы всё загрузилось (включая DialogueBox)
	call_deferred("_start_tutorial")


func _start_tutorial() -> void:
	_dialogue_box = DialogueBox.instance()
	if not _dialogue_box:
		push_warning("Tutorial: DialogueBox not found, retrying...")
		call_deferred("_start_tutorial")
		return

	# Убираем стартовые навыки — туториал сам выдаст
	SkillManager.unlocked.clear()
	GameManager.souls = 0

	# Блокируем таймер строительства
	PhaseManager._build_timer = 999999.0

	_advance(Step.INTRO)


func _process(_delta: float) -> void:
	match current_step:
		Step.WAIT_MOVE:
			if not _player_moved:
				var player = get_tree().current_scene.get_node_or_null("YSort/Player") as Player
				if player and player.velocity.length() > 1.0:
					_player_moved = true
					_advance(Step.EXPLAIN_QUEST)

		Step.WAIT_SKILL_TREE:
			var st = get_tree().current_scene.get_node_or_null("SkillTree")
			if st and not _skill_tree_opened and st.visible:
				_skill_tree_opened = true
				_advance(Step.GIVE_CRYSTALS)

		Step.WAIT_SKILLS_UNLOCKED:
			var all_unlocked = true
			for skill_id in REQUIRED_SKILLS:
				if not SkillManager.is_unlocked(skill_id):
					all_unlocked = false
					break
			if all_unlocked:
				_required_skills_unlocked = true
				_hide_hint()
				# Закрываем дерево и показываем диалог книги
				var st = get_tree().current_scene.get_node_or_null("SkillTree")
				if st and st.visible:
					st.close()
				_advance(Step.BOOK_INTRO)

		Step.WAIT_BUILD_ARCHERS:
			if not _archers_placed:
				var bg = get_tree().current_scene.get_node_or_null("YSort/BuildingGrid") as BuildingGrid
				if bg:
					for tile in bg.buildings:
						var b = bg.get_building(tile)
						if b and b is Building and b.building_type == "archer_tower":
							_archers_placed = true
							tutorial_restrict_placement = false
							tutorial_allowed_tiles.clear()
							# Выкидываем из режима строительства
							var main = get_tree().current_scene
							if main:
								if main.active_tool:
									main.active_tool.deactivate()
								main.active_tool = null
								main.active_tool_name = ""
								var bm = main.get_node_or_null("UILayer/BuildMenu")
								if bm:
									bm.visible = false
									bm.is_open = false
							_advance(Step.ENEMY_ARRIVES)
							break

		Step.WAIT_ENEMY_DEAD:
			if not _tutorial_enemy_dead:
				var enemies = get_tree().get_nodes_in_group("enemies")
				# Ослабляем врага при первом обнаружении
				if not _enemy_weakened and not enemies.is_empty():
					for e in enemies:
						e.hp = 1.0
						e.max_hp = 1.0
					_enemy_weakened = true
				# Проверяем смерть
				var all_dead = true
				for e in enemies:
					if not e.is_dead:
						all_dead = false
						break
				if not enemies.is_empty() and all_dead:
					_tutorial_enemy_dead = true
					_advance(Step.OUTRO)


func _advance(step: Step) -> void:
	current_step = step
	match step:
		Step.INTRO:
			_block_input()
			_show_dialogue([
				{"name": "Владыка", "text": "Ох, слава мне, что это получилось!", "portrait": PORTRAIT_OWNER, "voice": ""},
				{"name": "Герой", "text": "Что, кто я? Где я?", "portrait": "", "voice": ""},
				{"name": "Владыка", "text": "Сложно будет тебе всё сразу объяснить, давай сначала посмотрим, что ты можешь. Подвигайся, пожалуйста.", "portrait": PORTRAIT_OWNER, "voice": ""},
			], func():
				_unblock_input()
				_advance(Step.WAIT_MOVE)
			)
			_show_hint("Используйте WASD для перемещения")

		Step.EXPLAIN_QUEST:
			_block_input()
			_hide_hint()
			_show_dialogue([
				{"name": "Владыка", "text": "Отлично! Я слышал, что люди уничтожили троны моих братьев, из-за этого я призвал тебя, лучшего архитектора из мира людей.", "portrait": PORTRAIT_OWNER, "voice": ""},
				{"name": "Владыка", "text": "Я дам тебе способности и не буду ставить жёстких дедлайнов, которые у тебя были в их мире, взамен прошу воссоздать мне неприступную крепость. Согласен?", "portrait": PORTRAIT_OWNER, "voice": ""},
				{"name": "Герой", "text": "...", "portrait": "", "voice": ""},
				{"name": "Герой", "text": "Да это всё, о чём я мечтал! Конечно.", "portrait": "", "voice": ""},
				{"name": "Владыка", "text": "Поздравляю. Теперь ты бессмертный и можешь распоряжаться всеми моими ресурсами, которые остались после призыва тебя.", "portrait": PORTRAIT_OWNER, "voice": ""},
				{"name": "Владыка", "text": "Давай научу тебя пользоваться твоими способностями. Загляни в омут древних знаний.", "portrait": PORTRAIT_OWNER, "voice": ""},
			], func():
				_unblock_input()
				_advance(Step.WAIT_SKILL_TREE)
			)
			_show_hint("Откройте древо навыков")

		Step.GIVE_CRYSTALS:
			_block_input()
			_hide_hint()
			GameManager.souls += 5
			SkillManager.allowed_skills = REQUIRED_SKILLS.duplicate()
			_show_dialogue([
				{"name": "Владыка", "text": "Отлично, теперь возьми мои кристаллы и потрать их на следующие навыки: Строительный план, Лучники, Смена вида, Магические способности.", "portrait": PORTRAIT_OWNER, "voice": ""},
			], func():
				_unblock_input()
				_show_hint("Прокачайте: Строительный план, Лучники, Смена вида, Магические способности")
				current_step = Step.WAIT_SKILLS_UNLOCKED
			)

		Step.BOOK_INTRO:
			_block_input()
			_hide_hint()
			SkillManager.allowed_skills = []  # Снимаем ограничение
			_show_dialogue([
				{"name": "Книга", "text": "Ах, вы, гады! Я здесь лежал 500 лет! А как понадобился — берете даже без \"как дела, как настроение\"?!", "portrait": PORTRAIT_BOOK, "voice": ""},
				{"name": "Владыка", "text": "О! Ты открыл моего старого фамильяра. Эта книга помогала мне, когда я был ещё маленьким принцем.", "portrait": PORTRAIT_OWNER, "voice": ""},
				{"name": "Книга", "text": "Да, помню тебя, сорванца такого.", "portrait": PORTRAIT_BOOK, "voice": ""},
				{"name": "Владыка", "text": "Сейчас договоришься!", "portrait": PORTRAIT_OWNER, "voice": ""},
				{"name": "Книга", "text": "...", "portrait": PORTRAIT_BOOK, "voice": ""},
				{"name": "Владыка", "text": "Я вас оставляю. Он подскажет тебе как и что здесь происходит.", "portrait": PORTRAIT_OWNER, "voice": ""},
			], func(): _advance(Step.OWNER_LEAVES))

		Step.OWNER_LEAVES:
			_block_input()
			_show_dialogue([
				{"name": "Книга", "text": "Дела обстоят так, нам нужно защитить его трон, если мы хотим НЕ БЫТЬ обезглавленными или сожжёнными.", "portrait": PORTRAIT_BOOK, "voice": ""},
				{"name": "Книга", "text": "Первое, что тебе нужно сделать — это взять лучников и поставить рядом с троном.", "portrait": PORTRAIT_BOOK, "voice": ""},
			], func():
				_unblock_input()
				# Ограничиваем размещение только вокруг трона
				_setup_throne_placement()
				_advance(Step.WAIT_BUILD_ARCHERS)
			)
			_show_hint("Постройте башню лучников рядом с троном")

		Step.ENEMY_ARRIVES:
			_block_input()
			_hide_hint()
			_show_dialogue([
				{"name": "Книга", "text": "Неплохо для человека! Смотри, там кто-то идёт...", "portrait": PORTRAIT_BOOK, "voice": ""},
			], func():
				_unblock_input()
				# Переводим в боевую фазу без запуска волны
				PhaseManager.current_phase = PhaseManager.Phase.COMBAT
				PhaseManager.phase_changed.emit(PhaseManager.Phase.COMBAT)
				PhaseManager._transition_to_day()
				_spawn_tutorial_enemy()
			)

		Step.OUTRO:
			_block_input()
			_show_dialogue([
				{"name": "Рыцарь", "text": "Чёртова нежить! Мои... Потомки... Придут отомстить.", "portrait": PORTRAIT_KNIGHT, "voice": ""},
				{"name": "Книга", "text": "Чёрт! Так всё и начинается. Эх, приятным отпуском и не пахнет.", "portrait": PORTRAIT_BOOK, "voice": ""},
				{"name": "Книга", "text": "А ты чего стоишь? Строй давай! Через одно их поколение придут ещё люди, так что поторопись, ненавижу дедлайны.", "portrait": PORTRAIT_BOOK, "voice": ""},
			], func(): _advance(Step.DONE))

		Step.DONE:
			_hide_hint()
			_unblock_input()
			SkillManager.allowed_skills = []
			# Возвращаем фазу строительства
			PhaseManager.current_phase = PhaseManager.Phase.BUILD
			PhaseManager._build_timer = PhaseManager.build_time
			PhaseManager.phase_changed.emit(PhaseManager.Phase.BUILD)
			PhaseManager._transition_to_night()
			# Обновляем тулбар
			var main = get_tree().current_scene
			if main and main.has_method("_set_toolbar_mode"):
				main._set_toolbar_mode("build")
			tutorial_finished.emit()
			queue_free()


var _current_dialogue_callback: Callable

func _show_dialogue(lines: Array[Dictionary], on_finish: Callable) -> void:
	print("[Tutorial] Step %d: Showing dialogue, lines: %d" % [current_step, lines.size()])
	DialogueBox.say(lines)
	if _dialogue_box:
		# Отключаем предыдущий callback
		if _current_dialogue_callback.is_valid() and _dialogue_box.dialogue_finished.is_connected(_current_dialogue_callback):
			_dialogue_box.dialogue_finished.disconnect(_current_dialogue_callback)
		_current_dialogue_callback = on_finish
		_dialogue_box.dialogue_finished.connect(on_finish, CONNECT_ONE_SHOT)


var _hint_label: Label = null

func _create_block_layer() -> void:
	_block_layer = CanvasLayer.new()
	_block_layer.layer = 105  # Над SkillTree (100), под DialogueBox (110) и Hint (120)
	add_child(_block_layer)

	_block_rect = ColorRect.new()
	_block_rect.color = Color(0, 0, 0, 0.5)
	_block_rect.anchors_preset = Control.PRESET_FULL_RECT
	_block_rect.anchor_right = 1.0
	_block_rect.anchor_bottom = 1.0
	_block_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # Блокирует весь инпут под собой
	_block_layer.add_child(_block_rect)
	_block_layer.visible = false


func _block_input() -> void:
	if not _block_layer:
		_create_block_layer()
	_block_layer.visible = true


func _unblock_input() -> void:
	if _block_layer:
		_block_layer.visible = false


var _hint_layer: CanvasLayer = null

func _show_hint(text: String) -> void:
	if not _hint_label:
		# Свой CanvasLayer чтобы подсказка была поверх всего
		_hint_layer = CanvasLayer.new()
		_hint_layer.layer = 120
		add_child(_hint_layer)

		_hint_label = Label.new()
		_hint_label.anchors_preset = Control.PRESET_CENTER_TOP
		_hint_label.anchor_left = 0.5
		_hint_label.anchor_right = 0.5
		_hint_label.offset_left = -200
		_hint_label.offset_right = 200
		_hint_label.offset_top = 50
		_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint_label.add_theme_font_size_override("font_size", 14)
		_hint_label.add_theme_color_override("font_color", Color("#f0d060"))
		_hint_layer.add_child(_hint_label)
	_hint_label.text = text
	_hint_label.visible = true


func _hide_hint() -> void:
	if _hint_label:
		_hint_label.visible = false


var _enemy_weakened: bool = false


func _setup_throne_placement() -> void:
	tutorial_restrict_placement = true
	tutorial_allowed_tiles.clear()
	var main = get_tree().current_scene
	var throne_tile = main.throne_start_tile if main else Vector2i(14, 15)
	# 8 тайлов вокруг трона
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			tutorial_allowed_tiles.append(throne_tile + Vector2i(dx, dy))

func _spawn_tutorial_enemy() -> void:
	WaveManager.spawn_test_enemy("hero_knight")
	_enemy_weakened = false
	current_step = Step.WAIT_ENEMY_DEAD
