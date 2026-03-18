# ==========================================
# wall_draw_node.gd — Нода для рисования стен, тупо буфер команд, блять
# ==========================================
# add_polygon(points, color) — добавляет полигон в очередь на отрисовку, нихуя сложного
# add_line(from, to, color, width) — добавляет линию в очередь
# _draw() — рисует все накопленные полигоны и линии, вот и вся магия, ёпт
# ==========================================

class_name WallDrawNode
extends Node2D

## Stores draw commands and replays them in _draw()

var polygons: Array = []
var lines: Array = []
# Edge key for walls, or node Vector2i for pillars
var edge_key: StringName = &""
var node_key: Vector2i = Vector2i(-9999, -9999)


func add_polygon(points: PackedVector2Array, color: Color) -> void:
	polygons.append({"points": points, "color": color})


func add_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	lines.append({"from": from, "to": to, "color": color, "width": width})


func _draw() -> void:
	for p in polygons:
		draw_colored_polygon(p["points"], p["color"])
	for l in lines:
		draw_line(l["from"], l["to"], l["color"], l["width"])
