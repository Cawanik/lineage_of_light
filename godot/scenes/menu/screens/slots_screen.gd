extends VBoxContainer

signal slot_selected(slot: int, mode: String)
signal slot_deleted(slot: int)
signal back_pressed

var _mode: String = "new"

@onready var title_label: Label = $Title
@onready var slot_container: VBoxContainer = $Slots


func show_slots(mode: String, save_data: Array) -> void:
	_mode = mode
	title_label.text = tr("MENU_NEW_GAME") if mode == "new" else tr("MENU_CONTINUE")

	for child in slot_container.get_children():
		slot_container.remove_child(child)
		child.queue_free()

	for i in range(3):
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_container.add_child(hbox)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(280, 50)

		if save_data[i].is_empty():
			btn.text = tr("MENU_SLOT_EMPTY") % [i + 1]
			if mode == "load":
				btn.disabled = true
		else:
			var skills = save_data[i].get("unlocked_skills", [])
			var maps = save_data[i].get("completed_maps", [])
			var total_skills = Config.skill_tree.size()
			var skill_pct = (float(skills.size()) / max(total_skills, 1)) * 50.0
			var map_pct = (float(maps.size()) / 5.0) * 50.0
			var pct = int(clampf(skill_pct + map_pct, 0, 100))
			btn.text = tr("MENU_SLOT_PROGRESS") % [i + 1, pct]

		btn.pressed.connect(func(): slot_selected.emit(i, _mode))
		hbox.add_child(btn)

		var del_btn = TextureButton.new()
		del_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		del_btn.ignore_texture_size = true
		del_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		del_btn.custom_minimum_size = Vector2(36, 36)
		if ResourceLoader.exists("res://assets/sprites/ui/icon_close.png"):
			del_btn.texture_normal = load("res://assets/sprites/ui/icon_close.png")

		if not save_data[i].is_empty():
			del_btn.mouse_entered.connect(func(): del_btn.modulate = Color(1.3, 0.8, 0.8))
			del_btn.mouse_exited.connect(func(): del_btn.modulate = Color.WHITE)
			del_btn.pressed.connect(func(): slot_deleted.emit(i))
		else:
			del_btn.disabled = true
			del_btn.modulate = Color(0.3, 0.3, 0.3, 0.3)
		hbox.add_child(del_btn)


func _on_back_pressed() -> void:
	back_pressed.emit()
