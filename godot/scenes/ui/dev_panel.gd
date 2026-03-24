extends Control

@onready var game_active_label = $Background/VBoxContainer/InfoSection/GameActiveLabel
@onready var current_wave_label = $Background/VBoxContainer/InfoSection/CurrentWaveLabel
@onready var enemies_alive_label = $Background/VBoxContainer/InfoSection/EnemiesAliveLabel
@onready var lives_label = $Background/VBoxContainer/InfoSection/LivesLabel

@onready var spawn_test_button = $Background/VBoxContainer/ControlsSection/SpawnTestButton
@onready var start_wave_button = $Background/VBoxContainer/ControlsSection/StartWaveButton
@onready var test_path_button = $Background/VBoxContainer/ControlsSection/TestPathButton
@onready var reset_game_button = $Background/VBoxContainer/ControlsSection/ResetGameButton
@onready var toggle_debug_button = $Background/VBoxContainer/ControlsSection/ToggleDebugButton  
@onready var add_gold_button = $Background/VBoxContainer/ControlsSection/AddGoldButton
@onready var add_souls_button = $Background/VBoxContainer/ControlsSection/AddSoulsButton
@onready var toggle_button = $Background/VBoxContainer/ToggleButton

var is_panel_visible: bool = true
var debug_enabled: bool = true
var collapsed_size: Vector2
var full_size: Vector2

var spawn_popup: PopupPanel = null


func _ready() -> void:
	full_size = size
	collapsed_size = Vector2(full_size.x, 50)

	spawn_test_button.text = "Spawn Enemy..."
	_build_spawn_popup()

	spawn_test_button.pressed.connect(_on_spawn_test_pressed)

	# Кнопка тестового проджектайла
	var proj_btn = Button.new()
	proj_btn.text = "Spawn Projectile (click tile)"
	proj_btn.pressed.connect(_on_spawn_proj_pressed)
	spawn_test_button.get_parent().add_child(proj_btn)

	start_wave_button.pressed.connect(_on_start_wave_pressed)
	test_path_button.text = "Unlock All Skills"
	test_path_button.pressed.connect(_on_unlock_all_pressed)
	reset_game_button.pressed.connect(_on_reset_game_pressed)
	toggle_debug_button.pressed.connect(_on_toggle_debug_pressed)
	add_gold_button.pressed.connect(_on_add_gold_pressed)
	add_souls_button.pressed.connect(_on_add_souls_pressed)
	toggle_button.pressed.connect(_on_toggle_pressed)
	
	# Connect to game signals for live updates
	if GameManager:
		GameManager.lives_changed.connect(_on_lives_changed)
	if WaveManager:
		WaveManager.wave_started.connect(_on_wave_started)
	
	# Start update timer
	var timer = Timer.new()
	timer.wait_time = 0.5  # Update twice per second
	timer.timeout.connect(_update_info)
	timer.autostart = true
	add_child(timer)


func _update_info() -> void:
	if not is_inside_tree():
		return
		
	# Update game info labels
	game_active_label.text = "Game Active: %s" % GameManager.is_game_active
	current_wave_label.text = "Wave: %d/%d" % [WaveManager.current_wave, WaveManager.total_waves]
	enemies_alive_label.text = "Enemies Alive: %d" % WaveManager.enemies_alive
	lives_label.text = "Lives: %d" % GameManager.lives


var _placing_projectile: bool = false

var _debuff_slow_check: CheckBox
var _debuff_curse_check: CheckBox


func _build_spawn_popup() -> void:
	spawn_popup = PopupPanel.new()
	spawn_popup.title = "Spawn Enemy"
	add_child(spawn_popup)

	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(220, 0)
	spawn_popup.add_child(vbox)

	var label = Label.new()
	label.text = "Выбери врага:"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	vbox.add_child(HSeparator.new())

	# Дебаффы
	var debuff_label = Label.new()
	debuff_label.text = "Дебаффы:"
	debuff_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(debuff_label)

	_debuff_slow_check = CheckBox.new()
	_debuff_slow_check.text = "Замедление (50%)"
	vbox.add_child(_debuff_slow_check)

	_debuff_curse_check = CheckBox.new()
	_debuff_curse_check.text = "Проклятие (+100% урон)"
	vbox.add_child(_debuff_curse_check)

	vbox.add_child(HSeparator.new())

	for enemy_key in Config.enemies:
		var data = Config.enemies[enemy_key]
		var btn = Button.new()
		btn.text = "%s  (epoch %d)" % [data.get("name", enemy_key), data.get("epoch", 1)]
		btn.pressed.connect(_spawn_enemy.bind(enemy_key))
		vbox.add_child(btn)


func _spawn_enemy(enemy_type: String) -> void:
	spawn_popup.hide()
	WaveManager.spawn_test_enemy(enemy_type)

	# Применяем дебаффы к последнему заспавненному врагу
	if _debuff_slow_check.button_pressed or _debuff_curse_check.button_pressed:
		await get_tree().process_frame
		var enemies = get_tree().get_nodes_in_group("enemies")
		if not enemies.is_empty():
			var enemy = enemies[-1]
			if _debuff_slow_check.button_pressed and enemy.has_method("apply_slow"):
				enemy.apply_slow(0.5, 9999.0)
			if _debuff_curse_check.button_pressed and enemy.has_method("apply_curse"):
				enemy.apply_curse(1.0, 9999.0)

	print("DevPanel: Spawned %s" % enemy_type)


func _on_spawn_proj_pressed() -> void:
	_placing_projectile = true
	print("DevPanel: Click on a tile to spawn zombie_hand")


func _unhandled_input(event: InputEvent) -> void:
	if not _placing_projectile:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var main = get_tree().current_scene
		var bg = main.get_node_or_null("YSort/BuildingGrid") as BuildingGrid
		if bg:
			var mouse_pos = main.get_node("YSort/Player").get_global_mouse_position()
			var tile = bg.world_to_tile(mouse_pos)
			var tile_center = bg.tile_to_world(tile)
			var proj = Projectile.spawn(get_tree(), "zombie_hand", tile_center, tile_center)
			print("DevPanel: Spawned zombie_hand at tile %s (world %s, proj.pos.y=%s)" % [tile, tile_center, proj.position.y])
		_placing_projectile = false
		get_viewport().set_input_as_handled()


func _on_spawn_test_pressed() -> void:
	var btn_pos = spawn_test_button.global_position
	spawn_popup.popup(Rect2(btn_pos + Vector2(0, spawn_test_button.size.y + 4), Vector2.ZERO))


func _on_start_wave_pressed() -> void:
	print("DevPanel: Starting next wave")
	WaveManager.start_next_wave()


func _on_unlock_all_pressed() -> void:
	var sm = get_node_or_null("/root/SkillManager")
	if sm:
		for skill_id in Config.skill_tree:
			if not sm.is_unlocked(skill_id):
				sm.unlocked[skill_id] = true
				sm.skill_unlocked.emit(skill_id)
		print("DevPanel: All %d skills unlocked" % Config.skill_tree.size())
	else:
		print("SkillManager not found!")


func _on_reset_game_pressed() -> void:
	print("DevPanel: Resetting game")
	GameManager.reset_game()
	# Clear any existing enemies
	var main = get_tree().current_scene
	if main:
		var ysort = main.get_node_or_null("YSort")
		if ysort:
			for child in ysort.get_children():
				if child.has_method("die"):  # Enemy nodes
					child.queue_free()
	WaveManager.current_wave = 0
	WaveManager.enemies_alive = 0
	WaveManager.is_spawning = false


func _on_toggle_debug_pressed() -> void:
	debug_enabled = not debug_enabled
	toggle_debug_button.text = "Enable Debug Logs" if not debug_enabled else "Disable Debug Logs" 
	print("DevPanel: Debug logging %s" % ("enabled" if debug_enabled else "disabled"))


func _on_add_gold_pressed() -> void:
	GameManager.gold += 111


func _on_add_souls_pressed() -> void:
	GameManager.souls += 111


func _on_toggle_pressed() -> void:
	is_panel_visible = not is_panel_visible
	
	if is_panel_visible:
		# Show full panel
		size = full_size
		$Background/VBoxContainer/InfoSection.visible = true
		$Background/VBoxContainer/ControlsSection.visible = true
		$Background/VBoxContainer/HSeparator.visible = true
		$Background/VBoxContainer/HSeparator2.visible = true
		$Background/VBoxContainer/HSeparator3.visible = true
		toggle_button.text = "Hide Panel"
	else:
		# Collapse to title only
		size = collapsed_size
		$Background/VBoxContainer/InfoSection.visible = false
		$Background/VBoxContainer/ControlsSection.visible = false
		$Background/VBoxContainer/HSeparator.visible = false
		$Background/VBoxContainer/HSeparator2.visible = false
		$Background/VBoxContainer/HSeparator3.visible = false
		toggle_button.text = "Show Panel"


func _on_lives_changed(new_lives: int) -> void:
	lives_label.text = "Lives: %d" % new_lives


func _on_wave_started(wave_number: int) -> void:
	current_wave_label.text = "Wave: %d/%d" % [wave_number, WaveManager.total_waves]