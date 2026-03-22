# ==========================================
# phase_manager.gd — Менеджер фаз: строительство и бой
# ==========================================

extends Node

signal phase_changed(phase: Phase)
signal build_phase_timer_tick(seconds_left: float)

enum Phase { BUILD, COMBAT }

var current_phase: Phase = Phase.BUILD
var build_time: float = 300.0
var _build_timer: float = 0.0

var night_color: Color = Color(0.8, 0.8, 0.9)
var day_color: Color = Color(1.0, 1.0, 1.0)
var transition_time: float = 1.5
var _canvas_modulate: CanvasModulate = null
var director: EnemyDirector = null


func _ready() -> void:
	_start_build_phase()


func _process(delta: float) -> void:
	if current_phase == Phase.BUILD:
		_build_timer -= delta
		build_phase_timer_tick.emit(_build_timer)
		if _build_timer <= 0:
			start_combat_phase()

	elif current_phase == Phase.COMBAT:
		# Проверяем завершение боя
		if WaveManager.enemies_alive <= 0 and not WaveManager.is_spawning:
			end_combat_phase()


func _ensure_canvas_modulate() -> void:
	if _canvas_modulate and is_instance_valid(_canvas_modulate):
		return
	var scene = get_tree().current_scene
	if not scene:
		return
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.color = night_color
	scene.add_child(_canvas_modulate)


func _transition_to_night() -> void:
	_ensure_canvas_modulate()
	if not _canvas_modulate:
		return
	var tween = create_tween()
	tween.tween_property(_canvas_modulate, "color", night_color, transition_time).set_ease(Tween.EASE_IN_OUT)


func _transition_to_day() -> void:
	_ensure_canvas_modulate()
	if not _canvas_modulate:
		return
	var tween = create_tween()
	tween.tween_property(_canvas_modulate, "color", day_color, transition_time).set_ease(Tween.EASE_IN_OUT)


func _start_build_phase() -> void:
	current_phase = Phase.BUILD
	_build_timer = build_time
	phase_changed.emit(Phase.BUILD)
	call_deferred("_transition_to_night")


func start_combat_phase() -> void:
	if current_phase == Phase.COMBAT:
		return
	# Анализируем поле боя перед началом
	director = EnemyDirector.new()
	director.prepare(get_tree())

	current_phase = Phase.COMBAT
	phase_changed.emit(Phase.COMBAT)
	_transition_to_day()
	WaveManager.start_next_wave()


func end_combat_phase() -> void:
	if current_phase == Phase.BUILD:
		return
	# Награда за волну — 1 кристалл
	GameManager.souls += 1
	# Отхиливаем все здания
	_heal_all_buildings()
	_start_build_phase()


func _heal_all_buildings() -> void:
	var bg = get_tree().current_scene.get_node_or_null("YSort/BuildingGrid") as BuildingGrid
	if not bg:
		return
	for tile in bg.buildings:
		var b = bg.get_building(tile)
		if b and is_instance_valid(b):
			b.hp = b.max_hp
			b._update_hp_bar()


func skip_build_phase() -> void:
	if current_phase == Phase.BUILD:
		start_combat_phase()


func get_build_time_remaining() -> float:
	return maxf(_build_timer, 0.0)


func is_build_phase() -> bool:
	return current_phase == Phase.BUILD


func is_combat_phase() -> bool:
	return current_phase == Phase.COMBAT
