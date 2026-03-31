extends CenterContainer

signal map_selected(map: Dictionary)
signal back_pressed

@onready var title_label: Label = $VBox/Title
@onready var maps_container: HBoxContainer = $VBox/Maps
@onready var back_button: Button = $VBox/Back


func build_map_list(maps_data: Array, completed_maps: Array) -> void:
	for child in maps_container.get_children():
		maps_container.remove_child(child)
		child.queue_free()

	for i in range(maps_data.size()):
		var map = maps_data[i]
		var map_id = map.get("id", "")
		var unlock_after = map.get("unlock_after", "")
		var is_unlocked = unlock_after == "" or unlock_after in completed_maps
		var is_coming_soon = map.get("scene", "") == ""

		var card = VBoxContainer.new()
		card.add_theme_constant_override("separation", 4)
		card.custom_minimum_size = Vector2(80, 100)
		maps_container.add_child(card)

		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		var icon_path = map.get("icon", "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
		if not is_unlocked:
			icon_rect.modulate = Color(0.3, 0.3, 0.3)
		card.add_child(icon_rect)

		var name_lbl = Label.new()
		var map_name_key = "MAP_" + map_id.to_upper()
		name_lbl.text = tr(map_name_key)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", Color("#e8e0ff") if is_unlocked else Color("#666666"))
		card.add_child(name_lbl)

		if is_unlocked and not is_coming_soon:
			var is_completed = map_id in completed_maps
			var play_btn = Button.new()
			play_btn.text = tr("MENU_COMPLETED") if is_completed else tr("MENU_PLAY")
			play_btn.custom_minimum_size = Vector2(80, 35)
			play_btn.disabled = is_completed
			if not is_completed:
				play_btn.pressed.connect(func(): map_selected.emit(map))
			card.add_child(play_btn)
		else:
			var lock_lbl = Label.new()
			lock_lbl.text = tr("MENU_COMING_SOON") if is_coming_soon else "🔒"
			lock_lbl.add_theme_font_size_override("font_size", 10)
			lock_lbl.add_theme_color_override("font_color", Color("#666666"))
			lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(lock_lbl)

		if i < maps_data.size() - 1:
			var arrow = Label.new()
			arrow.text = "->"
			arrow.add_theme_font_size_override("font_size", 20)
			arrow.add_theme_color_override("font_color", Color("#9988bb"))
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			maps_container.add_child(arrow)


func _on_back_pressed() -> void:
	back_pressed.emit()
