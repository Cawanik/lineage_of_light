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


# Маппинг: навык дерева -> что он разблокирует
# tool:<name> — инструмент в тулбаре
# building:<type> — здание в меню
# ability:<id> — абилка игрока
# upgrade:<building>:<level> — уровень апгрейда здания (1-based)
const SKILL_UNLOCKS: Dictionary = {
	"build_plan": ["tool:build"],
	"archers": ["building:archer_tower"],
	"walls": ["building:wall_block"],
	"flat_view": ["tool:flat_view"],
	"demolish_tool": ["tool:demolish"],
	"upgrade_tool": ["tool:upgrade"],
	"move_tool": ["tool:move"],
	"magic_shot": ["ability:magic_bolt"],
	"magic_missile": ["ability:magic_missile"],
	"fireball": ["ability:fireball"],
	"ball_lightning": ["ability:storm"],
	"workshop_t1": [],
	"workshop_t2": [],
	"archer_up1": ["upgrade:archer_tower:1"],
	"archer_up2": ["upgrade:archer_tower:2"],
	"wall_up1": ["upgrade:wall_block:1"],
	"wall_up2": ["upgrade:wall_block:2"],
	"shadow_forge": ["building:shadow_forge"],
	"epoch_gate": ["building:epoch_gate"],
	"altar_of_greed": ["building:altar_of_greed"],
	"crystal_spire": ["building:crystal_spire"],
	"repair_up1": [],
	"repair_up2": [],
}


func is_tool_unlocked(tool_name: String) -> bool:
	var key = "tool:" + tool_name
	for skill_id in unlocked:
		if SKILL_UNLOCKS.has(skill_id):
			if key in SKILL_UNLOCKS[skill_id]:
				return true
	return false


func is_building_unlocked(building_type: String) -> bool:
	var key = "building:" + building_type
	for skill_id in unlocked:
		if SKILL_UNLOCKS.has(skill_id):
			if key in SKILL_UNLOCKS[skill_id]:
				return true
	return false


func is_ability_unlocked(ability_id: String) -> bool:
	var key = "ability:" + ability_id
	for skill_id in unlocked:
		if SKILL_UNLOCKS.has(skill_id):
			if key in SKILL_UNLOCKS[skill_id]:
				return true
	return false


func get_max_upgrade_level(building_type: String) -> int:
	var max_level = 0
	for skill_id in unlocked:
		if SKILL_UNLOCKS.has(skill_id):
			for entry in SKILL_UNLOCKS[skill_id]:
				if entry.begins_with("upgrade:" + building_type + ":"):
					var lvl = int(entry.split(":")[2])
					max_level = maxi(max_level, lvl)
	return max_level


func reset() -> void:
	unlocked.clear()
	for skill_id in DEFAULT_UNLOCKED:
		unlocked[skill_id] = true
