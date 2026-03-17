class_name TowerData
extends RefCounted

# Tower definitions matching art bible
const TOWERS = {
	"tower_arrow": {
		"name": "Башня лучников",
		"cost": 50,
		"damage": 15,
		"attack_speed": 1.0,  # attacks per second
		"range": 150.0,
		"projectile_speed": 300.0,
		"color": Color("#4a3070"),  # Dusk Purple
		"accent": Color("#9933cc"),  # Cursed Violet
		"description": "Стреляет одиночными проклятыми стрелами",
		"type": "ATTACK",
	},
	"tower_necro": {
		"name": "Обелиск некроманта",
		"cost": 75,
		"damage": 8,
		"attack_speed": 0.5,
		"range": 120.0,
		"projectile_speed": 200.0,
		"color": Color("#1a1030"),  # Shadow Purple
		"accent": Color("#e8e0ff"),  # Ghost White
		"description": "Замедляет врагов в зоне поражения",
		"type": "MAGIC",
		"slow_factor": 0.5,
		"slow_duration": 2.0,
	},
	"tower_fire": {
		"name": "Адский алтарь",
		"cost": 100,
		"damage": 25,
		"attack_speed": 0.3,
		"range": 100.0,
		"projectile_speed": 0.0,  # AoE, no projectile
		"color": Color("#1a1030"),  # Shadow Purple
		"accent": Color("#8b0000"),  # Blood Crimson
		"description": "Наносит урон по площади вокруг себя",
		"type": "ATTACK_AOE",
		"aoe_radius": 80.0,
	},
}
