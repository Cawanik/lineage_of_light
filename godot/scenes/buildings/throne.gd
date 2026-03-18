# ==========================================
# throne.gd — Трон Короля-Лича, ёбаный центр всего
# ==========================================
# _ready() — при старте делает setup("throne"), инициализирует трон нахуй
# _on_destroyed() — трон разъёбан = game over, шлёт сигнал throne_destroyed
# ==========================================

class_name Throne
extends Building

## The Lich King's throne — core building. Game over if destroyed.

signal throne_destroyed


func _ready() -> void:
	setup("throne")


func _on_destroyed() -> void:
	throne_destroyed.emit()
