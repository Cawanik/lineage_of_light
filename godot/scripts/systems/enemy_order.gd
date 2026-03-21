# ==========================================
# enemy_order.gd — Приказ для врага
# ==========================================
# Структура данных: куда идти, что атаковать, какая тактика
# Генерируется EnemyDirector перед боем
# ==========================================

class_name EnemyOrder
extends RefCounted

var spawn_tile: Vector2i = Vector2i.ZERO
var target_tile: Vector2i = Vector2i.ZERO
var path: Array[Vector2i] = []
var blocked: bool = false
var blocker: Dictionary = {}  # {"tile": Vector2i, "type": TileType}
var tactic: String = "direct"  # direct, break_through, flank, cautious_break

# Видимость (для тумана войны в будущем)
var visible_tiles: Dictionary = {}
var known_buildings: Array = []
