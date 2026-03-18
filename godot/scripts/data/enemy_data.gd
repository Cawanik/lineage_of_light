wwclass_name EnemyData
extends RefCounted

# Enemy definitions matching art bible epochs
const ENEMIES = {
	"hero_barbarian": {
		"name": "Варвар",
		"epoch": 1,
		"hp": 80,
		"speed": 60.0,
		"reward": 10,
		"damage_to_base": 1,
		"color": Color("#8b5e3c"),  # Stone Brick (warm)
		"accent": Color("#f0d060"),  # Pale Gold (torch)
	},
	"hero_knight": {
		"name": "Рыцарь",
		"epoch": 2,
		"hp": 200,
		"speed": 40.0,
		"reward": 20,
		"damage_to_base": 2,
		"color": Color("#2d5080"),  # Lake Reflect (steel blue)
		"accent": Color("#c47a45"),  # Terracotta (heraldic)
	},
	"hero_mage": {
		"name": "Маг",
		"epoch": 3,
		"hp": 100,
		"speed": 50.0,
		"reward": 25,
		"damage_to_base": 3,
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
		"color": Color("#b8860b"),  # Aged Gold
		"accent": Color("#e8e0ff"),  # Ghost White
	},
}
