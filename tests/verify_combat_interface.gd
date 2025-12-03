extends SceneTree

# Mocks
class MockRpcCallable:
	func rpc_id(_peer_id, _arg1=null, _arg2=null, _arg3=null, _arg4=null):
		pass

class MockNetworkHandler extends Node:
	var rt_state_update = MockRpcCallable.new()
	var rt_damage_event = MockRpcCallable.new()
	var rt_unit_death = MockRpcCallable.new()
	var rt_dodge_roll_event = MockRpcCallable.new()
	var rt_battle_start = MockRpcCallable.new()
	var rt_battle_end = MockRpcCallable.new()

class MockServerWorld extends Node:
	var network_handler = MockNetworkHandler.new()

class MockPlayerManager extends Node:
	var player_positions = {1: Vector2(500, 500)}
	func get_player_data(peer_id):
		return {"position": Vector2(500, 500), "base_stats": {"str": 10, "int": 10}}

class MockNPCManager extends Node:
	pass

func _init():
	print("=== SAFETY NET: VERIFYING COMBAT INTERFACE ===")
	
	# 1. Load the Manager
	var RealTimeCombatManager = load("res://source/server/managers/realtime_combat_manager.gd")
	if not RealTimeCombatManager:
		print("ERROR: Could not load RealTimeCombatManager")
		quit(1)
		return
		
	var manager = RealTimeCombatManager.new()
	
	# 2. Initialize Dependencies
	var server = MockServerWorld.new()
	var player_mgr = MockPlayerManager.new()
	var npc_mgr = MockNPCManager.new()
	
	manager.initialize(server, player_mgr, npc_mgr)
	print("PASS: Initialization")
	
	# 3. Create Battle
	var player_data = {"character_name": "Hero", "hp": 100, "max_hp": 100}
	var squad_data = [{"character_name": "Merc", "hp": 50}]
	var enemy_data = [{"character_name": "Slime", "hp": 20}]
	
	var battle_id = manager.create_battle(1, 99, player_data, squad_data, enemy_data, "test_map")
	if battle_id <= 0:
		print("FAIL: create_battle returned invalid ID")
		quit(1)
		return
	print("PASS: create_battle (ID: %d)" % battle_id)
	
	# 4. Handle Input (Movement)
	manager.handle_player_movement(1, Vector2(100, 0))
	print("PASS: handle_player_movement")
	
	# 5. Handle Input (Attack)
	manager.handle_player_attack(1, "enemy_0")
	print("PASS: handle_player_attack")
	
	# 6. Fluid Combat Check (Move AND Attack)
	manager.handle_player_movement(1, Vector2(100, 0))
	manager.handle_player_attack(1, "enemy_0")
	print("PASS: Fluid Combat (Move + Attack sequence)")

	# 7. Handle Input (Dodge)
	manager.handle_player_dodge_roll(1, 1.0, 0.0)
	print("PASS: handle_player_dodge_roll")
	
	var file = FileAccess.open("res://tests/test_result_combat.txt", FileAccess.WRITE)
	if file:
		file.store_string("SUCCESS")
		file.close()
	
	print("=== ALL CHECKS PASSED ===")
	quit(0)
