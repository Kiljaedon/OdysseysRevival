extends Node
class_name CombatRoundExecutor

## Combat Round Executor - Phase 2 Refactoring
## Handles combat round execution, turn processing, and battle flow
## Extracted from CombatManager lines 530-950

# Dependencies (injected by CombatManager)
var combat_manager = null  # Reference to parent CombatManager
var network_handler = null
var server_battle_manager = null

func initialize(mgr_ref, net_handler, battle_mgr):
	combat_manager = mgr_ref
	network_handler = net_handler
	server_battle_manager = battle_mgr
	print("[CombatRoundExecutor] Initialized")


# ========== COMBAT ROUND EXECUTION ==========

func execute_combat_round(combat_id: int):
	## Execute one combat round with all queued actions
	if not combat_manager.has_combat_instance(combat_id):
		print("[COMBAT] ERROR: Invalid combat ID %d" % combat_id)
		return

	var combat = combat_manager.get_combat_instance(combat_id)
	var peer_id = combat.get("peer_id", -1)

	print("[COMBAT] Executing round for combat %d" % combat_id)

	# Get queued actions (for now just player action)
	var queued_actions = combat.get("queued_actions", {})

	if queued_actions.is_empty():
		print("[COMBAT] No actions queued")
		return

	# Get player action
	var player_action = queued_actions.get(peer_id, {})
	var action_type = player_action.get("action", "defend")
	var target_id = player_action.get("target_id", 0)

	print("[COMBAT] Player action: %s (target: %d)" % [action_type, target_id])

	# Prepare round results
	var round_results = {
		"action": action_type,
		"target_id": target_id,
		"damage": 0,
		"target_hp": 0,
		"target_max_hp": 100,
		"target_defeated": false,
		"error": ""
	}

	# Execute action
	if action_type == "attack":
		# SECURITY: Calculate damage server-side using actual stats (no client trust)
		var enemy_squad = combat.get("enemy_squad", [])
		var player_character = combat.get("player_character", {})

		# Validate target
		print("[COMBAT] Enemy squad size: %d, target_id: %d" % [enemy_squad.size(), target_id])

		if enemy_squad.is_empty():
			print("[COMBAT] ERROR: Enemy squad is empty!")
			round_results["error"] = "No enemies in combat"
		elif target_id < 0 or target_id >= enemy_squad.size():
			print("[COMBAT] ERROR: Invalid target_id %d (squad size: %d)" % [target_id, enemy_squad.size()])
			round_results["error"] = "Target index out of range"
		else:
			var enemy = enemy_squad[target_id]

			# SERVER-AUTHORITATIVE DAMAGE CALCULATION using actual stats
			var damage = server_battle_manager.calculate_damage(player_character, enemy, 0, target_id, false)

			var old_hp = enemy.get("hp", 100)
			enemy["hp"] = max(0, old_hp - damage)

			# Get stats for logging
			var player_str = player_character.get("base_stats", {}).get("str", 10)
			var player_int = player_character.get("base_stats", {}).get("int", 10)
			var enemy_vit = enemy.get("base_stats", {}).get("vit", 10)
			var enemy_wis = enemy.get("base_stats", {}).get("wis", 10)
			var player_role = server_battle_manager.get_character_attack_type(player_character)
			var enemy_position = "back row" if target_id >= 3 else "front row"

			print("[COMBAT] Player (%s, pos 0) attacked enemy %d (%s, %s) for %d damage (HP: %d -> %d) [STR:%d INT:%d vs VIT:%d WIS:%d]" % [
				player_role,
				target_id,
				enemy.get("character_name", "Enemy"),
				enemy_position,
				damage,
				old_hp,
				enemy["hp"],
				player_str,
				player_int,
				enemy_vit,
				enemy_wis
			])

			# Update round results
			round_results["damage"] = damage
			round_results["target_hp"] = enemy["hp"]
			round_results["target_max_hp"] = enemy.get("max_hp", 100)

			# Check if enemy died
			if enemy["hp"] <= 0:
				print("[COMBAT] Enemy %d defeated!" % target_id)
				round_results["target_defeated"] = true

	# Clear queued actions for next round
	combat["queued_actions"].clear()

	# Send round results to client
	if network_handler:
		network_handler.send_combat_round_results(peer_id, combat_id, round_results)
		print("[COMBAT] Round results sent to peer %d" % peer_id)
	else:
		print("[COMBAT] ERROR: Cannot send results - network_handler not found")

	# SECURITY: Restart action timer for next selection phase
	combat_manager.action_timers[combat_id] = Time.get_ticks_msec() / 1000.0
	print("[COMBAT-SECURITY] Action timer restarted for combat %d" % combat_id)

	# PHASE 2 FIX: Process NPC turns after player action
	process_npc_turns(combat_id)

	print("[COMBAT] Round execution complete")


func process_npc_turns(combat_id: int):
	"""Process all NPC (ally and enemy) turns after player turn completes"""
	if not combat_manager.has_combat_instance(combat_id):
		print("[COMBAT] ERROR: Invalid combat ID in process_npc_turns: %d" % combat_id)
		return
	
	var combat = combat_manager.get_combat_instance(combat_id)
	var peer_id = combat.get("peer_id", -1)
	var turn_order = combat.get("turn_order", [])
	
	print("[COMBAT] Processing NPC turns for combat %d (turn_order size: %d)" % [combat_id, turn_order.size()])
	
	# Process each turn after the player (skip index 0 which is player)
	for i in range(1, turn_order.size()):
		var turn_data = turn_order[i]
		var unit_type = turn_data.get("type", "")
		var squad_index = turn_data.get("squad_index", -1)
		var unit_name = turn_data.get("name", "Unknown")
		
		print("[COMBAT] Processing turn %d/%d: %s (type: %s, squad_index: %d)" % [
			i + 1, turn_order.size(), unit_name, unit_type, squad_index
		])
		
		var result = {}
		
		match unit_type:
			"ally":
				result = execute_ally_turn(combat, squad_index)
				print("[COMBAT] Ally turn result: %s" % str(result))
			"enemy":
				result = execute_enemy_turn(combat, squad_index)
				print("[COMBAT] Enemy turn result: %s" % str(result))
		
		# Send turn result to client
		if network_handler and result.get("success", false):
			var turn_result_packet = {
				"actor_type": unit_type,
				"actor_name": unit_name,
				"action": result.get("action", "attack"),
				"target_index": result.get("target_index", -1),
				"damage": result.get("damage", 0),
				"target_hp": result.get("target_hp", 0),
				"target_max_hp": result.get("target_max_hp", 100),
				"target_defeated": result.get("target_defeated", false),
				"attacker_name": result.get("attacker_name", ""),
				"target_name": result.get("target_name", "")
			}
			
			combat_manager.rpc_id(peer_id, "receive_action_result", turn_result_packet)
			print("[COMBAT] Turn result sent to peer %d" % peer_id)
		
		# Check if battle ended
		var battle_result = check_battle_end(combat)
		if battle_result.battle_ended:
			print("[COMBAT] Battle ended: victor=%s" % battle_result.victor)
			var finalize_result = finalize_battle(combat)
			if network_handler:
				combat_manager.rpc_id(peer_id, "receive_battle_end", combat_id, finalize_result)
			return
	
	# All turns processed
	print("[COMBAT] All NPC turns processed, round %d complete" % combat.get("round_number", 1))
	var next_result = advance_turn(combat)
	start_selection_phase(combat)
	print("[COMBAT] Started selection phase for round %d" % combat.get("round_number", 1))


func execute_ally_turn(combat: Dictionary, ally_index: int) -> Dictionary:
	## Execute AI turn for allied NPC
	print("[COMBAT] Executing ally turn: index %d" % ally_index)
	
	var ally_squad = combat.get("ally_squad", [])
	if ally_index < 0 or ally_index >= ally_squad.size():
		print("[COMBAT] ERROR: Invalid ally index %d" % ally_index)
		return {"success": false}
	
	var ally_data = ally_squad[ally_index]
	
	# Check if ally is alive
	if ally_data.get("hp", 0) <= 0:
		print("[COMBAT] Ally %s is defeated, skipping turn" % ally_data.get("character_name", "Unknown"))
		return {"success": false}
	
	# Simple ally AI: Attack random alive enemy
	var enemy_squad = combat.get("enemy_squad", [])
	var alive_enemies = []
	for i in range(enemy_squad.size()):
		if enemy_squad[i].get("hp", 0) > 0:
			alive_enemies.append(i)
	
	if alive_enemies.is_empty():
		print("[COMBAT] No alive enemies for ally to attack")
		return {"success": false}
	
	# Pick random enemy
	var target_index = alive_enemies[randi() % alive_enemies.size()]
	var target = enemy_squad[target_index]
	
	# Calculate damage using server battle calculator
	var damage = 0
	if server_battle_manager:
		damage = server_battle_manager.calculate_damage(ally_data, target, ally_index, target_index, false)
	else:
		# Fallback calculation
		damage = ally_data.get("attack", 10) - target.get("defense", 5)
		damage = max(1, damage)
	
	# Apply damage
	var old_hp = target.get("hp", 100)
	target["hp"] = max(0, old_hp - damage)
	
	print("[COMBAT] Ally %s attacked %s for %d damage (HP: %d -> %d)" % [
		ally_data.get("character_name", "Ally"),
		target.get("character_name", "Enemy"),
		damage,
		old_hp,
		target["hp"]
	])
	
	# Return result
	return {
		"success": true,
		"action": "attack",
		"target_index": target_index,
		"damage": damage,
		"target_hp": target["hp"],
		"target_max_hp": target.get("max_hp", 100),
		"target_defeated": target["hp"] <= 0,
		"attacker_name": ally_data.get("character_name", "Ally"),
		"target_name": target.get("character_name", "Enemy")
	}


func execute_enemy_turn(combat: Dictionary, enemy_index: int) -> Dictionary:
	## Execute AI turn for enemy NPC
	print("[COMBAT] Executing enemy turn: index %d" % enemy_index)
	
	var enemy_squad = combat.get("enemy_squad", [])
	if enemy_index < 0 or enemy_index >= enemy_squad.size():
		print("[COMBAT] ERROR: Invalid enemy index %d" % enemy_index)
		return {"success": false}
	
	var enemy_data = enemy_squad[enemy_index]
	
	# Check if enemy is alive
	if enemy_data.get("hp", 0) <= 0:
		print("[COMBAT] Enemy %s is defeated, skipping turn" % enemy_data.get("character_name", "Unknown"))
		return {"success": false}
	
	# Simple enemy AI: Attack player or random ally
	var ally_squad = combat.get("ally_squad", [])
	var possible_targets = []
	
	# Add alive allies as possible targets
	for i in range(ally_squad.size()):
		if ally_squad[i].get("hp", 0) > 0:
			possible_targets.append({"type": "ally", "index": i, "data": ally_squad[i]})
	
	if possible_targets.is_empty():
		print("[COMBAT] No alive targets for enemy to attack")
		return {"success": false}
	
	# Pick random target
	var target_info = possible_targets[randi() % possible_targets.size()]
	var target = target_info.data
	var target_index = target_info.index
	
	# Calculate damage using server battle calculator
	var damage = 0
	if server_battle_manager:
		damage = server_battle_manager.calculate_damage(enemy_data, target, enemy_index, target_index, true)
	else:
		# Fallback calculation
		damage = enemy_data.get("attack", 10) - target.get("defense", 5)
		damage = max(1, damage)
	
	# Apply damage
	var old_hp = target.get("hp", 100)
	target["hp"] = max(0, old_hp - damage)
	
	print("[COMBAT] Enemy %s attacked %s for %d damage (HP: %d -> %d)" % [
		enemy_data.get("character_name", "Enemy"),
		target.get("character_name", "Ally"),
		damage,
		old_hp,
		target["hp"]
	])
	
	# Return result
	return {
		"success": true,
		"action": "attack",
		"target_index": target_index,
		"damage": damage,
		"target_hp": target["hp"],
		"target_max_hp": target.get("max_hp", 100),
		"target_defeated": target["hp"] <= 0,
		"attacker_name": enemy_data.get("character_name", "Enemy"),
		"target_name": target.get("character_name", "Ally")
	}


func check_battle_end(combat: Dictionary) -> Dictionary:
	## Check if battle should end (all enemies dead OR all allies dead)
	var ally_squad = combat.get("ally_squad", [])
	var enemy_squad = combat.get("enemy_squad", [])
	
	# Check if player is dead
	var player_character = combat.get("player_character", {})
	var player_dead = player_character.get("hp", 0) <= 0

	# Check if all allies are dead
	var all_allies_dead = true
	for ally in ally_squad:
		if ally.get("hp", 0) > 0:
			all_allies_dead = false
			break
	
	if player_dead and all_allies_dead:
		print("[COMBAT-SECURITY] Battle ended: All allies defeated")
		return {"battle_ended": true, "victor": "enemies"}
	
	# Check if all enemies are dead
	var all_enemies_dead = true
	for enemy in enemy_squad:
		if enemy.get("hp", 0) > 0:
			all_enemies_dead = false
			break
	
	if all_enemies_dead:
		print("[COMBAT-SECURITY] Battle ended: All enemies defeated")
		return {"battle_ended": true, "victor": "allies"}
	
	# Battle continues
	return {"battle_ended": false, "victor": ""}


func advance_turn(combat: Dictionary) -> Dictionary:

	var current_round = combat.get("round_number", 1)
	combat["round_number"] = current_round + 1
	
	print("[COMBAT] Round %d complete, starting round %d" % [current_round, combat["round_number"]])
	
	return {"success": true, "new_round": combat["round_number"]}


func start_selection_phase(combat: Dictionary):
	## Start player action selection phase
	var combat_id = -1

	# Find combat_id from instances
	for id in combat_manager.npc_combat_instances.keys():
		if combat_manager.npc_combat_instances[id] == combat:
			combat_id = id
			break
	
	if combat_id < 0:
		print("[COMBAT] ERROR: Could not find combat_id for selection phase")
		return
	
	print("[COMBAT] Starting selection phase for combat %d, round %d" % [combat_id, combat.get("round_number", 1)])
	
	# Start action timer (8 second timeout)
	combat_manager.action_timers[combat_id] = Time.get_ticks_msec() / 1000.0
	
	# Notify client to show action selection UI
	var peer_id = combat.get("peer_id", -1)
	if peer_id >= 0 and network_handler:
		combat_manager.rpc_id(peer_id, "start_action_selection", combat.get("round_number", 1))


func finalize_battle(combat: Dictionary) -> Dictionary:
	## Finalize battle and calculate rewards
	var victor = check_battle_end(combat).victor
	var victory = (victor == "player") # check_battle_end returns "player" or "enemy", not "allies"
	
	var rewards = {}
	
	if victory:
		var enemy_squad = combat.get("enemy_squad", [])
		var player_character = combat.get("player_character", {})
		var player_level = player_character.get("level", 1)
		
		# Calculate rewards using combat_manager (FIX: was incorrectly using calculator)
		if combat_manager and combat_manager.has_method("calculate_rewards"):
			rewards = combat_manager.calculate_rewards(combat)
		else:
			# Fallback simple calculation
			var total_xp = 0
			var total_gold = 0
			for enemy in enemy_squad:
				total_xp += enemy.get("level", 1) * 10
				total_gold += enemy.get("level", 1) * 5
			rewards = {"xp_gained": total_xp, "gold_gained": total_gold}
		
		print("[COMBAT-SECURITY] Rewards calculated: %d XP, %d gold" % [rewards.get("xp_gained", 0), rewards.get("gold_gained", 0)])
		
		# GRANT REWARDS TO PLAYER DB (Closing the loop)
		var peer_id = combat.get("peer_id", -1)
		if combat_manager.player_manager:
			# Convert to format expected by grant_rewards
			var grant_data = {
				"xp": rewards.get("xp_gained", 0), 
				"gold": rewards.get("gold_gained", 0)
			}
			combat_manager.player_manager.grant_rewards(peer_id, grant_data)
			print("[COMBAT] Rewards granted to peer %d" % peer_id)
	
	return {
		"victory": victory,
		"rewards": rewards,
		"victor": victor
	}

