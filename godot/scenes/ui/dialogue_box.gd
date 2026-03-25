# ==========================================
# dialogue_box.gd — Диалоговое окно в стиле Warcraft/Undertale
# ==========================================

class_name DialogueBox
extends CanvasLayer

signal dialogue_finished
signal line_finished

const CHARS_PER_SEC = 30.0
const BLIP_INTERVAL = 3

@onready var _container: Control = $Container
@onready var _portrait: TextureRect = $Container/Portrait
@onready var _name_label: Label = $Container/NameLabel
@onready var _text_label: RichTextLabel = $Container/TextLabel
@onready var _click_area: Control = $Container/ClickArea

var _full_text: String = ""
var _visible_chars: float = 0.0
var _is_typing: bool = false
var _char_count: int = 0
var _voice_blip_id: String = ""
var _dialogue_queue: Array[Dictionary] = []
var _active: bool = false
var _can_advance: bool = false
var _advance_cooldown: float = 0.0
var _skip_label: Label = null

static var _instance: DialogueBox = null


static func instance() -> DialogueBox:
	return _instance


func _ready() -> void:
	_instance = self
	if not Engine.is_editor_hint():
		_container.visible = false
	_click_area.gui_input.connect(_on_input)

	# Надпись "нажмите, чтобы продолжить"
	_skip_label = Label.new()
	_skip_label.text = "Нажмите, чтобы продолжить"
	_skip_label.add_theme_font_size_override("font_size", 10)
	_skip_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.7))
	_skip_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	_skip_label.anchor_left = 1.0
	_skip_label.anchor_top = 1.0
	_skip_label.anchor_right = 1.0
	_skip_label.anchor_bottom = 1.0
	_skip_label.offset_left = -200
	_skip_label.offset_top = -25
	_skip_label.offset_right = -15
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_label.visible = false
	_container.add_child(_skip_label)


func _process(delta: float) -> void:
	# Кулдаун на пропуск — всегда тикает
	if _advance_cooldown > 0:
		_advance_cooldown -= delta
		if _advance_cooldown <= 0:
			_can_advance = true
			if _skip_label:
				_skip_label.visible = true

	if not _is_typing:
		return

	_visible_chars += CHARS_PER_SEC * delta
	var target = int(_visible_chars)

	if target > _char_count:
		var old_count = _char_count
		_char_count = mini(target, _full_text.length())
		_text_label.visible_characters = _char_count

		if _voice_blip_id != "":
			for i in range(old_count, _char_count):
				if i % BLIP_INTERVAL == 0 and _full_text[i] != " ":
					var am = get_node_or_null("/root/AudioManager")
					if am:
						am.play(_voice_blip_id)

	if _char_count >= _full_text.length():
		_is_typing = false
		_can_advance = false
		_advance_cooldown = 1.0
		line_finished.emit()


func _on_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("[DialogueBox] Click! typing=%s can_advance=%s cooldown=%.2f" % [_is_typing, _can_advance, _advance_cooldown])
		if _is_typing:
			# Допечатать мгновенно, но НЕ переходить дальше
			_visible_chars = _full_text.length()
			_char_count = _full_text.length()
			_text_label.visible_characters = -1
			_is_typing = false
			_can_advance = false
			_advance_cooldown = 1.0
			line_finished.emit()
		elif _can_advance:
			# Переход к следующей реплике
			_can_advance = false
			if _skip_label:
				_skip_label.visible = false
			_next_line()
		get_viewport().set_input_as_handled()


func start_dialogue(lines: Array[Dictionary]) -> void:
	# Убиваем предыдущий close tween если есть
	if _close_tween and _close_tween.is_valid():
		_close_tween.kill()
	_dialogue_queue = lines.duplicate()
	_active = true
	_container.visible = true
	_container.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(_container, "modulate:a", 1.0, 0.3)
	_next_line()


func _next_line() -> void:
	print("[DialogueBox] _next_line, queue: %d" % _dialogue_queue.size())
	if _dialogue_queue.is_empty():
		_close()
		return

	var line = _dialogue_queue.pop_front()

	var portrait_tex = line.get("portrait")
	if portrait_tex is String and portrait_tex != "":
		if ResourceLoader.exists(portrait_tex):
			_portrait.texture = load(portrait_tex)
		_portrait.visible = true
	elif portrait_tex is Texture2D:
		_portrait.texture = portrait_tex
		_portrait.visible = true
	else:
		_portrait.visible = false

	_name_label.text = line.get("name", "")

	_full_text = line.get("text", "")
	_text_label.text = _full_text
	_text_label.visible_characters = 0
	_visible_chars = 0.0
	_char_count = 0
	_is_typing = true

	_voice_blip_id = line.get("voice", "")


var _close_tween: Tween = null

func _close() -> void:
	print("[DialogueBox] _close called, emitting dialogue_finished")
	_active = false
	_is_typing = false
	if _close_tween and _close_tween.is_valid():
		_close_tween.kill()
	_close_tween = create_tween()
	_close_tween.tween_property(_container, "modulate:a", 0.0, 0.3)
	_close_tween.tween_callback(func(): _container.visible = false)
	dialogue_finished.emit()


static func say(lines: Array[Dictionary]) -> void:
	if _instance:
		_instance.start_dialogue(lines)
	else:
		push_warning("DialogueBox: no instance found")
