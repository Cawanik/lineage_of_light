# ==========================================
# skill_manager.gd — Менеджер навыков, autoload
# ==========================================

extends Node

signal skill_unlocked(skill_id: String)

# Множество открытых навыков
var unlocked: Dictionary = {}  # skill_id -> true

# Туториал: если не пустой — можно качать только эти навыки
var allowed_skills: Array = []


const DEFAULT_UNLOCKED = ["build_plan", "archers", "flat_view", "magic_abilities"]


func _ready() -> void:
	pass


func is_unlocked(skill_id: String) -> bool:
	return unlocked.has(skill_id)


func can_unlock(skill_id: String) -> bool:
	var data = Config.skill_tree.get(skill_id, {})
	if data.is_empty():
		return false
	if is_unlocked(skill_id):
		return false
	# Туториал — ограничение навыков
	if not allowed_skills.is_empty() and skill_id not in allowed_skills:
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
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play("skill_unlock")
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


func is_autocast_unlocked(ability_id: String) -> bool:
	return _has_unlock("autocast:" + ability_id)


## Суммирует бонусы к стату абилки из всех открытых талантов
## Формат unlock: "bonus:ability_id:stat:value"
func get_ability_bonus(ability_id: String, stat: String) -> float:
	var total := 0.0
	var prefix = "bonus:" + ability_id + ":" + stat + ":"
	for skill_id in unlocked:
		for entry in _get_unlocks(skill_id):
			if entry.begins_with(prefix):
				total += float(entry.substr(prefix.length()))
	return total


## Возвращает id абилки-замены или "" если замены нет
## Формат unlock: "replace:ability_id:replacement_id"
func get_ability_replacement(ability_id: String) -> String:
	var prefix = "replace:" + ability_id + ":"
	for skill_id in unlocked:
		for entry in _get_unlocks(skill_id):
			if entry.begins_with(prefix):
				return entry.substr(prefix.length())
	return ""


func get_max_upgrade_level(building_type: String) -> int:
	# Апгрейды определяются только деревом навыков
	var max_level = 0
	var prefix = "upgrade:" + building_type + ":"
	for skill_id in unlocked:
		for entry in _get_unlocks(skill_id):
			if entry.begins_with(prefix):
				var lvl = int(entry.split(":")[2])
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
	allowed_skills = []
