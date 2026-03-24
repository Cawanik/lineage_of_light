# ==========================================
# skill_manager.gd — Менеджер навыков, autoload
# ==========================================

extends Node

signal skill_unlocked(skill_id: String)

# Множество открытых навыков
var unlocked: Dictionary = {}  # skill_id -> true


const DEFAULT_UNLOCKED = ["build_plan", "archers", "walls", "flat_view"]


func _ready() -> void:
	for skill_id in DEFAULT_UNLOCKED:
		unlocked[skill_id] = true


func is_unlocked(skill_id: String) -> bool:
	return unlocked.has(skill_id)


func can_unlock(skill_id: String) -> bool:
	var data = Config.skill_tree.get(skill_id, {})
	if data.is_empty():
		return false
	if is_unlocked(skill_id):
		return false
	# Проверяем все зависимости
	var requires = data.get("requires", [])
	for req in requires:
		if not is_unlocked(req):
			return false
	# Проверяем стоимость
	var cost = int(data.get("cost", 1))
	return GameManager.souls >= cost


# Состояние навыка: "unlocked", "available", "hidden"
func get_state(skill_id: String) -> String:
	if is_unlocked(skill_id):
		return "unlocked"
	var data = Config.skill_tree.get(skill_id, {})
	var requires = data.get("requires", [])
	# Если все родители открыты — доступен
	if requires.is_empty():
		return "available"
	for req in requires:
		if not is_unlocked(req):
			return "hidden"
	return "available"


func unlock(skill_id: String) -> bool:
	if not can_unlock(skill_id):
		return false
	var data = Config.skill_tree.get(skill_id, {})
	var cost = int(data.get("cost", 1))
	GameManager.souls -= cost
	unlocked[skill_id] = true
	skill_unlocked.emit(skill_id)
	return true


# Читает unlocks из skill_tree.json
func _get_unlocks(skill_id: String) -> Array:
	var data = Config.skill_tree.get(skill_id, {})
	return data.get("unlocks", [])


func _has_unlock(prefix: String) -> bool:
	for skill_id in unlocked:
		for entry in _get_unlocks(skill_id):
			if entry == prefix:
				return true
	return false


func is_tool_unlocked(tool_name: String) -> bool:
	return _has_unlock("tool:" + tool_name)


func is_building_unlocked(building_type: String) -> bool:
	return _has_unlock("building:" + building_type)


func is_ability_unlocked(ability_id: String) -> bool:
	return _has_unlock("ability:" + ability_id)


func get_max_upgrade_level(building_type: String) -> int:
	# Апгрейды работают только если Тёмная мастерская стоит на карте
	if not _building_exists_on_map("dark_workshop"):
		return 0
	# Уровень мастерской на карте определяет тир доступных апгрейдов
	var workshop_level = _get_building_upgrade_level("dark_workshop")
	var max_level = 0
	var prefix = "upgrade:" + building_type + ":"
	for skill_id in unlocked:
		for entry in _get_unlocks(skill_id):
			if entry.begins_with(prefix):
				var lvl = int(entry.split(":")[2])
				# Тир 2 апгрейды требуют улучшенную мастерскую
				if lvl >= 2 and workshop_level < 1:
					continue
				max_level = maxi(max_level, lvl)
	return max_level


func _get_building_upgrade_level(building_type: String) -> int:
	var bg_node = get_tree().current_scene.get_node_or_null("YSort/BuildingGrid") as BuildingGrid
	if not bg_node:
		return 0
	for tile in bg_node.buildings:
		var b = bg_node.get_building(tile)
		if b and b is Building and b.building_type == building_type:
			return b.upgrade_level
	return 0


# Проверяет есть ли здание данного типа на карте (не снесено/не уничтожено)
func _building_exists_on_map(building_type: String) -> bool:
	return GameManager._count_buildings(building_type) > 0


# Врата Эпох стоят на карте — тир 2 доступен
func is_epoch_active() -> bool:
	return is_unlocked("epoch_gate") and _building_exists_on_map("epoch_gate")


# Тёмная кузня стоит на карте — авторемонт работает
func is_repair_active() -> bool:
	return is_unlocked("shadow_forge") and _building_exists_on_map("shadow_forge")


func reset() -> void:
	unlocked.clear()
	for skill_id in DEFAULT_UNLOCKED:
		unlocked[skill_id] = true
