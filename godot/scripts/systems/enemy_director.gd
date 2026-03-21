# ==========================================
# enemy_director.gd — Раздаёт инструкции врагам перед боем
# ==========================================
# Анализирует поле, планирует маршруты, назначает цели
# Вызывается при старте комбат-фазы
# ==========================================

class_name EnemyDirector
extends RefCounted

var battlefield: Battlefield = null


func prepare(tree: SceneTree) -> void:
	battlefield = Battlefield.new()
	battlefield.scan(tree)


## Создаёт приказ для врага на основе его типа и точки спавна
func create_order(enemy_type: String, spawn_tile: Vector2i) -> EnemyOrder:
	var order = EnemyOrder.new()
	order.spawn_tile = spawn_tile
	order.target_tile = battlefield.get_throne_tile()

	# Строим маршрут
	order.path = battlefield.find_path(spawn_tile, order.target_tile)

	# Если путь заблокирован — находим первый блокер
	if order.path.is_empty():
		# Нет прямого пути — ищем ближайшую стену/здание для атаки
		order.blocked = true
		order.blocker = _find_nearest_blocker(spawn_tile)
	else:
		var blocker = battlefield.find_first_blocker(order.path)
		if not blocker.is_empty():
			order.blocked = true
			order.blocker = blocker

	# Тактика в зависимости от мозга
	var brain_type = EnemyData.ENEMIES.get(enemy_type, {}).get("brain", "peasant")
	order.tactic = _decide_tactic(brain_type, order)

	return order


func _decide_tactic(brain_type: String, order: EnemyOrder) -> String:
	if not order.blocked:
		return "direct"  # Прямой путь к трону

	match brain_type:
		"peasant":
			return "break_through"  # Ломай всё на пути
		"knight":
			# Попробуем обход
			if _can_flank(order):
				return "flank"
			return "break_through"
		"mage":
			# Маг сильно хочет обойти
			if _can_flank(order):
				return "flank"
			return "cautious_break"  # Медленно ломает
		_:
			return "break_through"


func _can_flank(order: EnemyOrder) -> bool:
	# Проверяем есть ли обходной путь с любого другого спавна
	var spawns = battlefield.get_spawn_tiles()
	for spawn in spawns:
		var path = battlefield.find_path(spawn, order.target_tile)
		if not path.is_empty():
			var blocker = battlefield.find_first_blocker(path)
			if blocker.is_empty():
				return true
	return false


func _find_nearest_blocker(from: Vector2i) -> Dictionary:
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [from]
	visited[from] = true

	while not queue.is_empty():
		var current = queue.pop_front()
		if battlefield.is_blocked(current):
			return {"tile": current, "type": battlefield.get_tile_type(current)}
		for d in dirs:
			var n = current + d
			if not visited.has(n) and battlefield.get_tile_type(n) != Battlefield.TileType.UNKNOWN:
				visited[n] = true
				queue.append(n)

	return {}
