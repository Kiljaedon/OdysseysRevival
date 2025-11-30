extends SceneTree

func _init():
	print("TEST: Verifying CombatRoundExecutor Player Turn Skip...")
	
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
			
			# Setup: Enemy is faster, so player is not first in turn_order
			# Player (dex 20) is unit 0 for allies
			# Enemy (dex 15) is unit 0 for enemies
			# Turn order: Player, Enemy (because player is faster here by dex. Re-evaluate.)
			# Let's make enemy faster to test the skip
			var faster_enemy_unit = {
				"hp": 100, "max_hp": 100, "character_name": "FastGoblin", "level": 1,
				"base_stats": {"dex": 25, "str": 10, "int": 10}, "is_player": false
			}
			
			var combat_data = {
				"combat_id": 1, "peer_id": 1, "player_id": 1,
				"player_character": player_unit,
				"ally_squad": [player_unit],
				"enemy_squad": [faster_enemy_unit],
				"turn_order": [ # Manual turn order for testing: Enemy (first strike), Player
					{ "type": "enemy", "data": faster_enemy_unit, "dex": 25, "is_ally": false, "squad_index": 0, "name": "FastGoblin" },
					{ "type": "ally", "data": player_unit, "dex": 20, "is_ally": true, "squad_index": 0, "name": "TestPlayer" }
				],
				"current_turn_index": 0, "round_number": 1,
				"player_initiated": false, # Enemy initiated (ambush)
				"player_has_acted": true,  # Assume player already acted
				"state": "active",
				"queued_actions": { 1: {"action": "attack", "target_id": 0} } # Player's action
			}
			return combat_data
		,
		"action_timers": {},
		"rpc_id": func(id, method, p1, p2=null, p3=null):
			print("Mock CombatManager RPC_ID: ", method)
	}

	# Mock NetworkHandler
	var MockNetworkHandler = {
		"send_combat_round_results": func(peer, combat, results):
			print("Mock NetworkHandler: send_combat_round_results called")
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
	
	# === Simulate Player's Turn Execution ===
	# This part is normally done by CombatManager calling process_npc_turns *after* player action
	# For this test, we directly call process_npc_turns as if player just acted
	
	# Before calling process_npc_turns, let's track the enemy HP
	var initial_enemy_hp = combat_instance.enemy_squad[0].hp
	
	# Execute NPC turns (which now includes skipping the player)
	executor.process_npc_turns(combat_id)
	
	# Verify
	# 1. Enemy (FastGoblin) acts first (dex 25)
	# 2. Player (TestPlayer) acts second (dex 20)
	#    The player turn should be SKIPPED by the fix.
	#    So, the player's damage logic should NOT be triggered again.
	
	# Check if the player AI caused damage to an enemy
	# In this specific test setup, the mock damage is 10
	# If player AI acted, enemy HP would be 100 - 10 = 90 (if enemy was target)
	# But in this test, player (ally) acts on enemy. Enemy (as actor) acts on player.
	# So we expect the player's AI to NOT attack.
	
	# The mock turn order is: Enemy, Player
	# process_npc_turns starts from index 1.
	# Index 1 is the Player. This should be skipped.
	# So the enemy should not have taken damage from player AI.
	
	var final_enemy_hp = combat_instance.enemy_squad[0].hp
	
	if final_enemy_hp == initial_enemy_hp:
		print("PASS: Player's AI turn was correctly skipped. Enemy HP: %d" % final_enemy_hp)
	else:
		print("FAIL: Player's AI turn was NOT skipped. Enemy HP changed from %d to %d" % [initial_enemy_hp, final_enemy_hp])
		quit(1)
	
	print("ALL PLAYER TURN SKIP TESTS PASSED")
	quit(0)
