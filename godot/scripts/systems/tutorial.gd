# ==========================================
# tutorial.gd — Система обучения, стейт-машина
# ==========================================

class_name Tutorial
extends Node

signal tutorial_finished

enum Step {
	INTRO,
	WAIT_MOVE,
	WAIT_ZOOM,
	EXPLAIN_QUEST,
	WAIT_SKILL_TREE,
	GIVE_CRYSTALS,
	WAIT_SKILLS_UNLOCKED,
	BOOK_INTRO,
	OWNER_LEAVES,
	FLAT_VIEW_ON,
	WAIT_FLAT_VIEW_ON,
	FLAT_VIEW_DIALOGUE,
	WAIT_FLAT_VIEW_OFF,
	WAIT_BUILD_ARCHERS,
	ENEMY_ARRIVES,
	WAIT_ENEMY_DEAD,
	OUTRO,
	DONE
}

var current_step: Step = Step.INTRO
var _player_moved: bool = false
var _player_zoomed: bool = false
var _flat_view_entered: bool = false
var _flat_view_dialogue_shown: bool = false
var _initial_zoom: float = 0.0
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
const PORTRAIT_PLAYER = "res://assets/sprites/ui/portraits/portrait_player.png"
const PORTRAIT_KNIGHT = "res://assets/sprites/ui/portraits/portrait_knight.png"


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

	# Скрываем кнопку пропуска фазы
	var wave_btn = get_tree().current_scene.get_node_or_null("UILayer/StartWaveButton")
	if wave_btn:
		wave_btn.force_hidden = true

	_advance(Step.INTRO)


func _process(_delta: float) -> void:
	match current_step:
		Step.WAIT_MOVE:
			if not _player_moved:
				var player = get_tree().current_scene.get_node_or_null("YSort/Player") as Player
				if player and player.velocity.length() > 1.0:
					_player_moved = true
					_advance(Step.WAIT_ZOOM)

		Step.WAIT_ZOOM:
			if not _player_zoomed:
				var player = get_tree().current_scene.get_node_or_null("YSort/Player") as Player
				if player and player.camera:
					if _initial_zoom == 0.0:
						_initial_zoom = player.camera.zoom.x
					if absf(player.camera.zoom.x - _initial_zoom) > 0.05:
						_player_zoomed = true
						_advance(Step.EXPLAIN_QUEST)

		Step.WAIT_SKILL_TREE:
			var st = get_tree().current_scene.get_node_or_null("SkillTree")
			if st and not _skill_tree_opened and st.visible:
				_skill_tree_opened = true
				_highlight_skill_tree_button(false)
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
				if SkillManager.skill_unlocked.is_connected(_on_tutorial_skill_unlocked):
					SkillManager.skill_unlocked.disconnect(_on_tutorial_skill_unlocked)
				# Закрываем дерево и показываем диалог книги
				var st = get_tree().current_scene.get_node_or_null("SkillTree")
				if st and st.visible:
					st.close()
				_advance(Step.BOOK_INTRO)

		Step.WAIT_FLAT_VIEW_ON:
			var main_fv = get_tree().current_scene
			if main_fv and main_fv.get("_flat_view") == true:
				_flat_view_entered = true
				_unhighlight_toolbar_slot()
				_advance(Step.FLAT_VIEW_DIALOGUE)

		Step.WAIT_FLAT_VIEW_OFF:
			var main_fv2 = get_tree().current_scene
			if main_fv2 and _flat_view_entered and main_fv2.get("_flat_view") == false and not _flat_view_dialogue_shown:
				_flat_view_dialogue_shown = true
				_unhighlight_toolbar_slot()
				_advance(Step.WAIT_BUILD_ARCHERS)

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
							_unhighlight_toolbar_slot()
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
							_restore_full_block()
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
			_show_hint("Нажмите на диалоговое окно для продолжения")
			_show_dialogue([
				{"name": "Владыка", "text": "Ох, слава мне... Наконец-то получилось. Знаешь, сколько я потратил маны на этот ритуал? Не знаешь. И лучше тебе не знать.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
				{"name": "Вы", "text": "Что?.. Кто я? Где я? Почему так темно? И почему от вас веет... смертью?", "portrait": PORTRAIT_PLAYER, "voice": "player"},
				{"name": "Владыка", "text": "Вопросы потом. Сейчас мне нужно убедиться, что ты не бракованный. Пошевелись-ка.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
			], func():
				_unblock_input()
				_show_hint("Используйте WASD для перемещения")
				_advance(Step.WAIT_MOVE)
			)

		Step.WAIT_ZOOM:
			_hide_hint()
			_show_hint("Прокрутите колёсико мыши для изменения масштаба")

		Step.EXPLAIN_QUEST:
			_block_input()
			_hide_hint()
			_show_dialogue([
				{"name": "Владыка", "text": "О, двигается! Чудесно. Последний, кого я призвал, просто стоял и плакал. Три часа. Пришлось развоплощать.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
				{"name": "Владыка", "text": "Слушай внимательно. Люди — эти суетливые создания — уничтожили троны моих братьев. Всех до одного. Мы их не трогали, заметь. Ни одного набега, ни одной войны.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
				{"name": "Владыка", "text": "Мы просто... существуем. Тихо. Мирно. В своих тёмных замках. Но им этого мало — видите ли, мы \"угроза\". Какая угроза? Я за последние триста лет даже с территории не выходил!", "portrait": PORTRAIT_OWNER, "voice": "owner"},
				{"name": "Владыка", "text": "Мне нужен архитектор. Лучший. А ты, говорят, в мире людей строил что-то... как это... \"офисные центры\"? Звучит ужасающе. Идеально.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
				{"name": "Владыка", "text": "Я дам тебе силу, бессмертие и полное отсутствие дедлайнов. Взамен — построй мне крепость, которую эти параноики не смогут разрушить. Согласен?", "portrait": PORTRAIT_OWNER, "voice": "owner"},
				{"name": "Вы", "text": "...", "portrait": PORTRAIT_PLAYER, "voice": "player"},
				{"name": "Вы", "text": "Никаких дедлайнов? Это всё, о чём я мечтал! Конечно!", "portrait": PORTRAIT_PLAYER, "voice": "player"},
				{"name": "Владыка", "text": "Восхитительно. Такой энтузиазм я видел только у свежеподнятых скелетов. Это комплимент, если что.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
				{"name": "Владыка", "text": "Теперь загляни в омут древних знаний. Там хранятся способности, которые помогут тебе в строительстве.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
			], func():
				_block_input()
				_highlight_skill_tree_button(true)
				_advance(Step.WAIT_SKILL_TREE)
			)
			_show_hint("Откройте древо навыков")

		Step.GIVE_CRYSTALS:
			_block_input()
			_hide_hint()
			GameManager.souls += 4
			SkillManager.allowed_skills = REQUIRED_SKILLS.duplicate()
			_show_dialogue([
				{"name": "Владыка", "text": "Держи четыре кристалла — всё, что осталось после твоего призыва. Не благодари, ты и так обошёлся мне в целое состояние.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
				{"name": "Владыка", "text": "Вложи их с умом: Строительный план, Лучники, Смена вида и Магические способности. Остальное — потом, когда заслужишь.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
			], func():
				_unblock_input()
				_update_skills_hint()
				SkillManager.skill_unlocked.connect(_on_tutorial_skill_unlocked)
				current_step = Step.WAIT_SKILLS_UNLOCKED
			)

		Step.BOOK_INTRO:
			_block_input()
			_hide_hint()
			SkillManager.allowed_skills = []
			_show_dialogue([
				{"name": "Книга", "text": "ПЯТЬСОТ. ЛЕТ. Пятьсот лет я лежал на этой полке! И ни одного \"как дела\", ни одного \"спасибо за службу\"!", "portrait": PORTRAIT_BOOK, "voice": "book"},
				{"name": "Книга", "text": "А стоит понадобиться — сразу \"о, Книга, помоги, Книга, подскажи\". Вы хоть пыль с меня стряхнули? НЕТ.", "portrait": PORTRAIT_BOOK, "voice": "book"},
				{"name": "Владыка", "text": "О, ты нашёл моего старого фамильяра! Эта книга учила меня, когда я был ещё маленьким принцем тьмы. Ностальгия...", "portrait": PORTRAIT_OWNER, "voice": "owner"},
				{"name": "Книга", "text": "Ага, помню. Рисовал чертей на моих страницах. До сих пор на 347-й странице какой-то монстр с подписью \"папа\".", "portrait": PORTRAIT_BOOK, "voice": "book"},
				{"name": "Владыка", "text": "...Ещё одно слово, и я найду тебе применение поинтереснее. Например, растопка камина.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
				{"name": "Книга", "text": "...", "portrait": PORTRAIT_BOOK, "voice": "book"},
				{"name": "Владыка", "text": "Вот и славно. Я вас оставляю. Книга подскажет, что к чему. А мне пора — дела тёмные, сами понимаете.", "portrait": PORTRAIT_OWNER, "voice": "owner"},
			], func(): _advance(Step.OWNER_LEAVES))

		Step.OWNER_LEAVES:
			_block_input()
			# Владыка уходит с поля
			var lich = get_tree().current_scene.get_node_or_null("YSort/LichKing")
			if lich:
				var tween = create_tween()
				tween.tween_property(lich, "modulate:a", 0.0, 0.5)
				tween.tween_callback(lich.queue_free)
			_show_dialogue([
				{"name": "Книга", "text": "Ушёл. Наконец-то. Ладно, слушай сюда, человечек.", "portrait": PORTRAIT_BOOK, "voice": "book"},
				{"name": "Книга", "text": "Видишь этот трон? Это единственное, что стоит между нами и толпой людей, которые почему-то считают, что мы угрожаем их существованию. Мы! Которые сидим тут тише воды, ниже травы!", "portrait": PORTRAIT_BOOK, "voice": "book"},
				{"name": "Книга", "text": "Прежде чем строить — Владыка дал тебе дар видеть суть вещей. Попробуй активировать его.", "portrait": PORTRAIT_BOOK, "voice": "book"},
			], func():
				_unblock_input()
				_advance(Step.FLAT_VIEW_ON)
			)
			_show_hint("Постройте башню лучников рядом с троном")

		Step.FLAT_VIEW_ON:
			_block_input_except_toolbar()
			_show_hint("Нажмите кнопку смены вида")
			_highlight_toolbar_slot(4)  # Слот 5 = flat view (индекс 4)
			current_step = Step.WAIT_FLAT_VIEW_ON

		Step.FLAT_VIEW_DIALOGUE:
			_block_input()
			_hide_hint()
			_show_dialogue([
				{"name": "Книга", "text": "Ага! Теперь ты видишь мир как есть — без этой изометрической мишуры. Каждая клетка как на ладони.", "portrait": PORTRAIT_BOOK, "voice": "book"},
				{"name": "Книга", "text": "В этом режиме удобнее строить и планировать оборону. Осмотрись, а потом выключи — нам нужно двигаться дальше.", "portrait": PORTRAIT_BOOK, "voice": "book"},
			], func():
				_unblock_input()
				_show_hint("Осмотритесь. Выключите смену вида для продолжения")
				current_step = Step.WAIT_FLAT_VIEW_OFF
			)

		Step.WAIT_BUILD_ARCHERS:
			_block_input()
			_hide_hint()
			_show_dialogue([
				{"name": "Книга", "text": "Видишь? Теперь ты можешь видеть истинную природу построек. Полезно, когда всё начнёт разрастаться.", "portrait": PORTRAIT_BOOK, "voice": "book"},
				{"name": "Книга", "text": "А теперь к делу. Поставь лучников рядом с троном. Да-да, скелетов с луками. Не спрашивай, откуда у них глаза — просто ставь.", "portrait": PORTRAIT_BOOK, "voice": "book"},
			], func():
				_unblock_input()
				_setup_throne_placement()
				_highlight_toolbar_slot(0)
				_show_hint("Постройте башню лучников рядом с троном")
			)

		Step.ENEMY_ARRIVES:
			_block_input()
			_hide_hint()
			_show_dialogue([
				{"name": "Книга", "text": "Хм, неплохо для существа без магического образования. Я впечатлён. Немного. Самую каплю.", "portrait": PORTRAIT_BOOK, "voice": "book"},
				{"name": "Книга", "text": "Стоп. Ты слышишь? Шаги. Кажется, к нам кто-то идёт...", "portrait": PORTRAIT_BOOK, "voice": "book"},
			], func():
				_unblock_input()
				GameManager.tutorial_wave = true
				PhaseManager.current_phase = PhaseManager.Phase.COMBAT
				PhaseManager.phase_changed.emit(PhaseManager.Phase.COMBAT)
				PhaseManager._transition_to_day()
				_spawn_tutorial_enemy()
			)

		Step.OUTRO:
			_block_input()
			_show_dialogue([
				{"name": "Рыцарь", "text": "Во имя света! Тьма будет повер... к-как?! Одна стрела?! Мои потомки... отомстят...", "portrait": PORTRAIT_KNIGHT, "voice": "knight"},
				{"name": "Книга", "text": "Мы буквально сидели у себя дома. ОН пришёл к НАМ. И мы ещё злодеи?", "portrait": PORTRAIT_BOOK, "voice": "book"},
				{"name": "Книга", "text": "Вот так всегда. Один фанатик, одна стрела, а потом — армия обиженных потомков с факелами и \"священной миссией\".", "portrait": PORTRAIT_BOOK, "voice": "book"},
				{"name": "Книга", "text": "Ладно, хватит глазеть. У нас примерно одно человеческое поколение до следующей атаки.", "portrait": PORTRAIT_BOOK, "voice": "book"},
				{"name": "Книга", "text": "Строй, укрепляй, готовься. И учти — в следующий раз одной башней не отделаешься. Ненавижу дедлайны, но тут уж ничего не поделать.", "portrait": PORTRAIT_BOOK, "voice": "book"},
			], func(): _advance(Step.DONE))

		Step.DONE:
			_hide_hint()
			_unblock_input()
			SkillManager.allowed_skills = []
			GameManager.tutorial_wave = false
			GameManager.tutorial_completed = true
			# Показываем кнопку пропуска фазы
			var wave_btn = get_tree().current_scene.get_node_or_null("UILayer/StartWaveButton")
			if wave_btn:
				wave_btn.force_hidden = false
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
	_block_layer.layer = 105
	add_child(_block_layer)

	_block_rect = ColorRect.new()
	_block_rect.color = Color(0, 0, 0, 0.5)
	_block_rect.anchors_preset = Control.PRESET_FULL_RECT
	_block_rect.anchor_right = 1.0
	_block_rect.anchor_bottom = 1.0
	_block_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_block_layer.add_child(_block_rect)
	_block_layer.visible = false


var _toolbar_passthrough: Control = null

func _block_input_except_toolbar() -> void:
	if not _block_layer:
		_create_block_layer()
	_block_layer.visible = true
	# Добавляем прозрачную дырку над тулбаром
	if not _toolbar_passthrough:
		_toolbar_passthrough = Control.new()
		_toolbar_passthrough.anchors_preset = Control.PRESET_BOTTOM_RIGHT
		_toolbar_passthrough.anchor_left = 1.0
		_toolbar_passthrough.anchor_top = 1.0
		_toolbar_passthrough.anchor_right = 1.0
		_toolbar_passthrough.anchor_bottom = 1.0
		_toolbar_passthrough.offset_left = -270.0
		_toolbar_passthrough.offset_top = -270.0
		_toolbar_passthrough.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_block_layer.add_child(_toolbar_passthrough)
	# Скрываем главный блок-рект чтобы показать L-образный блок
	_block_rect.visible = false
	# Создаём 2 прямоугольника вокруг тулбара
	_clear_toolbar_block_rects()
	# Верхняя полоса (всё кроме правого нижнего угла)
	var top = ColorRect.new()
	top.name = "BlockTop"
	top.color = Color(0, 0, 0, 0.5)
	top.anchors_preset = Control.PRESET_TOP_WIDE
	top.anchor_right = 1.0
	top.anchor_bottom = 1.0
	top.offset_bottom = -270.0  # Оставляем место снизу для тулбара
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	_block_layer.add_child(top)
	# Левая нижняя полоса (слева от тулбара)
	var bottom_left = ColorRect.new()
	bottom_left.name = "BlockBottomLeft"
	bottom_left.color = Color(0, 0, 0, 0.5)
	bottom_left.anchor_top = 1.0
	bottom_left.anchor_bottom = 1.0
	bottom_left.anchor_right = 1.0
	bottom_left.offset_top = -270.0
	bottom_left.offset_right = -270.0
	bottom_left.mouse_filter = Control.MOUSE_FILTER_STOP
	_block_layer.add_child(bottom_left)


func _clear_toolbar_block_rects() -> void:
	for child in _block_layer.get_children():
		if child.name in ["BlockTop", "BlockBottomLeft"]:
			child.queue_free()


func _restore_full_block() -> void:
	_clear_toolbar_block_rects()
	if _toolbar_passthrough and is_instance_valid(_toolbar_passthrough):
		_toolbar_passthrough.queue_free()
		_toolbar_passthrough = null
	if _block_rect:
		_block_rect.visible = true


func _block_input() -> void:
	if not _block_layer:
		_create_block_layer()
	_block_layer.visible = true


func _unblock_input() -> void:
	_restore_full_block()
	if _block_layer:
		_block_layer.visible = false


func _show_hint(text: String) -> void:
	var al = get_node_or_null("/root/AlertSystem")
	if al:
		al.show_persistent(text)


func _hide_hint() -> void:
	var al = get_node_or_null("/root/AlertSystem")
	if al:
		al.hide_persistent()


var _enemy_weakened: bool = false
var _highlighted_slot: Node = null
var _highlight_slot_tween: Tween = null


func _highlight_toolbar_slot(index: int) -> void:
	_unhighlight_toolbar_slot()
	var main = get_tree().current_scene
	var grid = main.get_node_or_null("UILayer/Toolbar/Grid") if main else null
	if not grid:
		return
	var slots = grid.get_children()
	if index >= slots.size():
		return
	_highlighted_slot = slots[index]
	_highlight_slot_tween = create_tween().set_loops()
	_highlight_slot_tween.tween_property(_highlighted_slot, "modulate", Color(1.5, 1.2, 1.8), 0.4)
	_highlight_slot_tween.tween_property(_highlighted_slot, "modulate", Color.WHITE, 0.4)


func _unhighlight_toolbar_slot() -> void:
	if _highlight_slot_tween and _highlight_slot_tween.is_valid():
		_highlight_slot_tween.kill()
	if _highlighted_slot and is_instance_valid(_highlighted_slot):
		_highlighted_slot.modulate = Color.WHITE
	_highlighted_slot = null
	_highlight_slot_tween = null

const SKILL_NAMES: Dictionary = {
	"build_plan": "Строительный план",
	"archers": "Лучники",
	"flat_view": "Смена вида",
	"magic_abilities": "Магические способности",
}


func _on_tutorial_skill_unlocked(_skill_id: String) -> void:
	if current_step == Step.WAIT_SKILLS_UNLOCKED:
		_update_skills_hint()


func _update_skills_hint() -> void:
	var remaining: Array[String] = []
	for skill_id in REQUIRED_SKILLS:
		if not SkillManager.is_unlocked(skill_id):
			remaining.append(SKILL_NAMES.get(skill_id, skill_id))
	if remaining.is_empty():
		_hide_hint()
	else:
		_show_hint("Прокачайте: " + ", ".join(remaining))
var _skill_tree_btn_original_parent: Node = null
var _skill_tree_btn_original_z: int = 0


var _highlight_btn: TextureRect = null
var _arrow_label: Label = null

func _highlight_skill_tree_button(enable: bool) -> void:
	if enable:
		if not _block_layer:
			_create_block_layer()
		_block_layer.visible = true

		# Создаём кнопку-дубликат поверх блока
		var main = get_tree().current_scene
		var original = main.get_node_or_null("UILayer/SkillTreeButton") if main else null
		if not original:
			return

		_highlight_btn = TextureRect.new()
		_highlight_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Копируем иконку
		var icon = original.get_node_or_null("Icon")
		if icon and icon.texture:
			_highlight_btn.texture = icon.texture
		_highlight_btn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_highlight_btn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Позиция как у оригинала
		_highlight_btn.offset_left = original.offset_left
		_highlight_btn.offset_top = original.offset_top
		_highlight_btn.offset_right = original.offset_right
		_highlight_btn.offset_bottom = original.offset_bottom
		_highlight_btn.anchor_left = original.anchor_left
		_highlight_btn.anchor_top = original.anchor_top
		_highlight_btn.anchor_right = original.anchor_right
		_highlight_btn.anchor_bottom = original.anchor_bottom
		_highlight_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_highlight_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_highlight_btn.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				var skill_tree = get_tree().current_scene.get_node_or_null("SkillTree")
				if skill_tree:
					skill_tree.open()
				get_viewport().set_input_as_handled()
		)
		_block_layer.add_child(_highlight_btn)

		# Пульсация
		var tween = create_tween().set_loops()
		tween.tween_property(_highlight_btn, "modulate", Color(1.5, 1.2, 1.8), 0.5)
		tween.tween_property(_highlight_btn, "modulate", Color.WHITE, 0.5)
		_highlight_btn.set_meta("tween", tween)

		# Стрелка с подписью — снизу от кнопки
		var btn_rect = original.get_global_rect()
		var arrow_x = btn_rect.position.x + btn_rect.size.x * 0.5 - 30
		var arrow_y = btn_rect.end.y + 5

		_arrow_label = Label.new()
		_arrow_label.text = "▲  Древо талантов"
		_arrow_label.add_theme_font_size_override("font_size", 16)
		_arrow_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_arrow_label.position = Vector2(arrow_x, arrow_y)
		_arrow_label.size = Vector2(200, 30)
		_arrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_block_layer.add_child(_arrow_label)

		# Анимация стрелки — покачивание вверх-вниз
		var arrow_tween = create_tween().set_loops()
		arrow_tween.tween_property(_arrow_label, "position:y", arrow_y - 4.0, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		arrow_tween.tween_property(_arrow_label, "position:y", arrow_y + 4.0, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_arrow_label.set_meta("tween", arrow_tween)
	else:
		if _highlight_btn and is_instance_valid(_highlight_btn):
			if _highlight_btn.has_meta("tween"):
				var tween = _highlight_btn.get_meta("tween")
				if tween and tween.is_valid():
					tween.kill()
			_highlight_btn.queue_free()
			_highlight_btn = null
		if _arrow_label and is_instance_valid(_arrow_label):
			if _arrow_label.has_meta("tween"):
				var tween = _arrow_label.get_meta("tween")
				if tween and tween.is_valid():
					tween.kill()
			_arrow_label.queue_free()
			_arrow_label = null


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
