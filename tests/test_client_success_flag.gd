extends SceneTree

func _init():
	print("TEST: Verifying CombatRoundExecutor Client Success Flag...")
	
	# Mock CombatManager
	var MockCombatManager = {
		"has_combat_instance": func(id): return true,
		"get_combat_instance": func(id):
			var player_unit = {
				"hp": 100, "max_hp": 100, "character_name": "TestPlayer", "level": 1,
				"base_stats": {"dex": 20, "str": 10, "int": 10}, "is_player": true, "peer_id": 1
			}
			var enemy_unit = {
				"hp": 100, "max_hp": 100, "character_name": "Goblin", "level": 1,
				"base_stats": {"dex": 15, "str": 10, "int": 10}, "is_player": false
			}
			
			var combat_data = {
				"combat_id": 1, "peer_id": 1, "player_id": 1,
				"player_character": player_unit,
				"ally_squad": [player_unit],
				"enemy_squad": [enemy_unit],
				"turn_order": [ # Player first
					{ "type": "ally", "data": player_unit, "dex": 20, "is_ally": true, "squad_index": 0, "name": "TestPlayer" },
					{ "type": "enemy", "data": enemy_unit, "dex": 15, "is_ally": false, "squad_index": 0, "name": "Goblin" }
				],
				"current_turn_index": 0, "round_number": 1,
				"player_initiated": true,
				"player_has_acted": false,
				"state": "active",
				"queued_actions": { 1: {"action": "attack", "target_id": 0} } # Player's action
			}
			return combat_data
		,
		"action_timers": {},
		"rpc_id": func(id, method, p1, p2=null, p3=null):
			print("Mock CombatManager RPC_ID: ", method)
	}

	# Mock NetworkHandler to capture sent results
	var CapturedResults = []
	var MockNetworkHandler = {
		"send_combat_round_results": func(peer, combat, results):
			print("Mock NetworkHandler: Captured send_combat_round_results: ", results)
			CapturedResults.append(results)
		,
		"send_combat_round_updates": func(peer, combat, updates):
			print("Mock NetworkHandler: send_combat_round_updates called")
	}

	# Mock ServerBattleCalculator
	var MockServerBattleCalculator = {
		"calculate_damage": func(attacker, defender, p_idx, d_idx, is_enemy): return 10,
		"get_character_attack_type": func(char_data): return "melee"
	}
	
	# Load CombatRoundExecutor
	var CombatRoundExecutorClass = load("res://source/server/managers/combat/combat_round_executor.gd")
	var executor = CombatRoundExecutorClass.new()
	executor.initialize(MockCombatManager, MockNetworkHandler, MockServerBattleCalculator)
	
	var combat_id = 1
	var combat_instance = MockCombatManager.get_combat_instance(combat_id)
	
	# Simulate Player's Turn Execution (which triggers the result sending)
	executor.execute_combat_round(combat_id)
	
	# Verify that results were captured and contain "success": true
	if CapturedResults.size() == 1:
		var results_packet = CapturedResults[0]
		if results_packet.get("success", false) == true:
			print("PASS: Captured round_results contains 'success': true")
		else:
			print("FAIL: Captured round_results missing or incorrect 'success' flag: %s" % results_packet)
			quit(1)
	else:
		print("FAIL: Expected 1 result packet, got %d" % CapturedResults.size())
		quit(1)
	
	print("ALL CLIENT SUCCESS FLAG TESTS PASSED")
	quit(0)
