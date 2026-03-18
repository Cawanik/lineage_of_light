extends SceneTree

func _init():
	print("=== Testing Enemy Spawn ===")
	
	# Create main scene
	var main_scene = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main_scene)
	
	# Wait a bit for initialization
	await create_timer(1.0).timeout
	
	print("=== Spawning test enemy ===")
	# Spawn test enemy
	var wave_manager = main_scene.get_node("/root/WaveManager")
	if wave_manager:
		wave_manager.spawn_test_enemy("hero_barbarian")
	else:
		print("WaveManager not found!")
	
	# Wait and observe
	await create_timer(5.0).timeout
	
	print("=== Test complete, quitting ===")
	quit()