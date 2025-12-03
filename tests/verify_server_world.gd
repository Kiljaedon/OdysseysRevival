extends SceneTree

func _init():
	print("=== SAFETY NET: VERIFYING SERVER WORLD ===")
	
	# 1. Load ServerWorld
	var ServerWorld = load("res://source/server/server_world.gd")
	if not ServerWorld:
		print("ERROR: Could not load server_world.gd")
		quit(1)
		return
		
	# 2. Instantiate (Headless Check)
	# We cannot fully _ready() because it tries to spawn network servers, load DBs etc.
	# But we can check if the class compiles and instantiates.
	var server_node = ServerWorld.new()
	
	if not server_node:
		print("ERROR: Failed to instantiate ServerWorld")
		quit(1)
		return
		
	print("PASS: ServerWorld Instantiated")
	
	# 3. Check Member Variables (Reflection)
	var required_managers = [
		"player_manager", "npc_manager", "auth_manager", 
		"realtime_combat_manager", "network_handler"
	]
	
	for mgr in required_managers:
		if not mgr in server_node:
			print("FAIL: Missing required member variable: %s" % mgr)
			quit(1)
			return
			
	print("PASS: Required member variables present")
	
	# 4. Check Methods (Reflection)
	var required_methods = [
		"request_login", "handle_realtime_player_attack", 
		"upload_map" # Will be delegated later, but method sig must exist
	]
	
	for method in required_methods:
		if not server_node.has_method(method):
			print("FAIL: Missing public API method: %s" % method)
			quit(1)
			return
			
	print("PASS: Public API methods present")
	
	var file = FileAccess.open("res://tests/test_result_server.txt", FileAccess.WRITE)
	if file:
		file.store_string("SUCCESS")
		file.close()
	
	print("=== ALL CHECKS PASSED ===")
	quit(0)
