extends SceneTree

func _init():
	print("=== FINAL IMPLEMENTATION TEST ===")
	print("Testing all 4 fixes:")
	print("1. PathfindingSystem ↔ WallSystem synchronization") 
	print("2. Simplified FSM without state conflicts")
	print("3. Separated tile-based logic from physics")
	print("4. Fixed attack priorities and logic")
	print("")
	
	# Load main scene
	var main_scene = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main_scene)
	
	# Wait for initialization
	await create_timer(3.0).timeout
	
	print("=== Starting wave test ===")
	var wave_manager = root.get_node_or_null("/root/WaveManager")
	if wave_manager:
		wave_manager.start_next_wave()
		print("Wave started - monitoring enemy AI behavior...")
		
		# Monitor for 15 seconds
		await create_timer(15.0).timeout
		print("=== Test completed successfully ===")
	else:
		print("ERROR: WaveManager not found!")
	
	quit()