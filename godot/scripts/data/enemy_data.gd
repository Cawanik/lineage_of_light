class_name EnemyData
extends RefCounted

# Enemy definitions matching art bible epochs
const ENEMIES = {
	"hero_barbarian": {
		"name": "Крестьянин",
		"epoch": 1,
		"hp": 80,
		"speed": 35.0,
		"reward": 10,
		"damage_to_base": 1,
		"wall_dps": 15.0,
		"brain": "peasant",
		"color": Color("#8b5e3c"),
		"accent": Color("#f0d060"),
		"sprite_path": "res://assets/sprites/enemies/peasant/",
		"walk_anim": "walking-8-frames",
		"attack_anim": "pitchfork-attack",
	},
	"hero_knight": {
		"name": "Рыцарь",
		"epoch": 2,
		"hp": 200,
		"speed": 40.0,
		"reward": 20,
		"brain": "knight",
		"damage_to_base": 2,
		"wall_dps": 25.0,
		"color": Color("#2d5080"),  # Lake Reflect (steel blue)
		"accent": Color("#c47a45"),  # Terracotta (heraldic)
	},
	"hero_mage": {
		"name": "Маг",
		"epoch": 3,
		"hp": 100,
		"speed": 50.0,
		"reward": 25,
		"brain": "mage",
		"damage_to_base": 3,
		"wall_dps": 5.0,
		"color": Color("#1a1030"),  # Shadow Purple (robes)
		"accent": Color("#f0d060"),  # Pale Gold (magic glow)
	},
	"hero_alchemist": {
		"name": "Алхимик",
		"epoch": 4,
		"hp": 120,
		"speed": 55.0,
		"reward": 20,
		"damage_to_base": 2,
		"wall_dps": 20.0,
		"color": Color("#2d5a27"),  # Moss Green
		"accent": Color("#4a8c3f"),  # Pine Green
	},
	"hero_heir": {
		"name": "Наследник",
		"epoch": 5,
		"hp": 300,
		"speed": 45.0,
		"reward": 50,
		"damage_to_base": 5,
		"wall_dps": 30.0,
		"color": Color("#b8860b"),  # Aged Gold
		"accent": Color("#e8e0ff"),  # Ghost White
	},
}
