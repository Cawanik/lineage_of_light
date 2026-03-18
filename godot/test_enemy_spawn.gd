extends SceneTree

func _init():
	print("=== Testing Enemy Pathfinding ===")
	
	# Create main scene
	var main_scene = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main_scene)
	
	# Wait a bit for initialization
	await create_timer(2.0).timeout
	
	print("=== Starting first wave ===")
	# Start first wave
	var wave_manager = root.get_node_or_null("/root/WaveManager")
	if wave_manager:
		wave_manager.start_next_wave()
		print("Wave started, observing for 10 seconds...")
		
		# Wait and observe pathfinding behavior
		await create_timer(10.0).timeout
	else:
		print("WaveManager not found!")
	
	print("=== Test complete, quitting ===")
	quit()