class_name Throne
extends Building

## The Lich King's throne — core building. Game over if destroyed.

signal throne_destroyed


func _ready() -> void:
	setup("throne")


func _on_destroyed() -> void:
	throne_destroyed.emit()
