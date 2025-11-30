extends Node
class_name TurnExecutor

## Turn Executor - Handles all combat turn execution and AI
## Extracted from CombatManager for focused responsibility
## Handles: turn execution, NPC AI, damage application, victory conditions

signal turn_complete(combat_id: int, peer_id: int, turn_results: Array)
signal turn_complete(combat_id: int)
signal battle_ended(combat_id: int, victor: String)
signal round_advanced(combat_id: int, new_round: int)

# Dependencies (injected by CombatController)
var server_world: Node = null
var network_handler: Node = null
var server_battle_manager: Node = null
var validator: Node = null  # CombatValidator reference

## ========== INITIALIZATION ==========

func initialize(world_ref: Node, net_handler: Node, battle_mgr: Node, validator_ref: Node) -> void:
	## Initialize turn executor with dependencies
	server_world = world_ref
	network_handler = net_handler
	server_battle_manager = battle_mgr
	validator = validator_ref
	print("[TurnExecutor] Initialized")


## ========== COMBAT ROUND EXECUTION ==========

func execute_combat_round(combat_id: int, combat: Dictionary, peer_id: int) -> Dictionary:
	## Execute one combat round with all queued actions
	## Returns round results dictionary
	print("[TurnExecutor] Executing round for combat %d" % combat_id)

	# Get queued actions (for now just player action)
	var queued_actions = combat.get("queued_actions", {})

	if queued_actions.is_empty():
		print("[TurnExecutor] No actions queued")
		return {"error": "No actions queued"}

	# Get player action
	var player_action = queued_actions.get(peer_id, {})
	var action_type = player_action.get("action", "defend")
	var target_id = player_action.get("target_id", 0)

	print("[TurnExecutor] Player action: %s (target: %d)" % [action_type, target_id])

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
		var attack_result = _execute_player_attack(combat, target_id, peer_id)
		if attack_result.has("error"):
			round_results["error"] = attack_result["error"]
		else:
			round_results["damage"] = attack_result.get("damage", 0)
			round_results["target_hp"] = attack_result.get("target_hp", 0)
			round_results["target_max_hp"] = attack_result.get("target_max_hp", 100)
			round_results["target_defeated"] = attack_result.get("target_defeated", false)

	elif action_type == "defend":
		# Defend action reduces incoming damage (handled in execute_enemy_turn)
		combat["player_defending"] = true
		print("[TurnExecutor] Player is defending this turn")

	# Clear queued actions for next round
	combat["queued_actions"].clear()

	# Send round results to client
	if network_handler:
		network_handler.send_combat_round_results(peer_id, combat_id, round_results)
		print("[TurnExecutor] Round results sent to peer %d" % peer_id)

	print("[TurnExecutor] Round execution complete")
	return round_results


func _execute_player_attack(combat: Dictionary, target_id: int, peer_id: int) -> Dictionary:
	## Execute player attack action
	## SECURITY: Calculate damage server-side using actual stats (no client trust)
	var enemy_squad = combat.get("enemy_squad", [])
	var player_character = combat.get("player_character", {})

	# Validate target using validator
	if not validator.validate_squad_not_empty(enemy_squad):
		return {"error": "No enemies in combat"}

	# Sanitize target index
	target_id = validator.sanitize_target_index(target_id, enemy_squad.size(), peer_id)

	var enemy = enemy_squad[target_id]

	# SERVER-AUTHORITATIVE DAMAGE CALCULATION using actual stats
	var damage = 0
	if server_battle_manager:
		damage = server_battle_manager.calculate_damage(player_character, enemy, 0, target_id, false)
	else:
		# Fallback calculation
		var player_str = player_character.get("base_stats", {}).get("str", 10)
		var enemy_vit = enemy.get("base_stats", {}).get("vit", 10)
		damage = max(1, player_str - enemy_vit)

	var old_hp = int(enemy.get("hp", 100))
	enemy["hp"] = max(0, old_hp - damage)

	# Get stats for logging
	var player_str = player_character.get("base_stats", {}).get("str", 10)
	var player_int = player_character.get("base_stats", {}).get("int", 10)
	var enemy_vit = enemy.get("base_stats", {}).get("vit", 10)
	var enemy_wis = enemy.get("base_stats", {}).get("wis", 10)
	var player_role = "physical" if player_str > player_int else "magical"
	var enemy_position = "back row" if target_id >= 3 else "front row"

	print("[TurnExecutor] Player (%s, pos 0) attacked enemy %d (%s, %s) for %d damage (HP: %d -> %d) [STR:%d INT:%d vs VIT:%d WIS:%d]" % [
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

	# Return attack result
	return {
		"damage": damage,
		"target_hp": enemy["hp"],
		"target_max_hp": int(enemy.get("max_hp", 100)),
		"target_defeated": enemy["hp"] <= 0
	}


## ========== NPC TURN PROCESSING ==========

func process_npc_turns(combat_id: int, combat: Dictionary, peer_id: int) -> Dictionary:
	## Process all NPC (ally and enemy) turns after player turn completes
	var turn_order = combat.get("turn_order", [])

	print("[TurnExecutor] Processing NPC turns for combat %d (turn_order size: %d)" % [combat_id, turn_order.size()])

	# Process each turn after the player (skip index 0 which is player)
	for i in range(1, turn_order.size()):
		var turn_data = turn_order[i]
		var unit_type = turn_data.get("type", "")
		var squad_index = turn_data.get("squad_index", -1)
		var unit_name = turn_data.get("name", "Unknown")

		print("[TurnExecutor] Processing turn %d/%d: %s (type: %s, squad_index: %d)" % [
			i + 1, turn_order.size(), unit_name, unit_type, squad_index
		])

		var result = {}

		match unit_type:
			"ally":
				result = execute_ally_turn(combat, squad_index)
				print("[TurnExecutor] Ally turn result: %s" % str(result))
			"enemy":
				result = execute_enemy_turn(combat, squad_index)
				print("[TurnExecutor] Enemy turn result: %s" % str(result))

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

			# RPC call will be handled by CombatController
			# We just prepare the data here
			result["rpc_packet"] = turn_result_packet

		# Check if battle ended
		var battle_result = check_battle_end(combat)
		if battle_result.battle_ended:
			print("[TurnExecutor] Battle ended: victor=%s" % battle_result.victor)
			battle_ended.emit(combat_id, battle_result.victor)
			return {"battle_ended": true, "victor": battle_result.victor}

	# All turns processed
	print("[TurnExecutor] All NPC turns processed, round %d complete" % combat.get("round_number", 1))

	# Advance turn
	var next_result = advance_turn(combat)

	# Emit signal for CombatController
	turn_complete.emit(combat_id)

	return {"success": true, "round_complete": true}


## ========== ALLY AI ==========

func execute_ally_turn(combat: Dictionary, ally_index: int) -> Dictionary:
	## Execute AI turn for allied NPC
	print("[TurnExecutor] Executing ally turn: index %d" % ally_index)

	var ally_squad = combat.get("ally_squad", [])
	if ally_index < 0 or ally_index >= ally_squad.size():
		print("[TurnExecutor] ERROR: Invalid ally index %d" % ally_index)
		return {"success": false}

	var ally_data = ally_squad[ally_index]

	# Check if ally is alive using validator
	if not validator or not validator.validate_entity_alive(ally_data):
		print("[TurnExecutor] Ally %s is defeated, skipping turn" % ally_data.get("character_name", "Unknown"))
		return {"success": false}

	# Simple ally AI: Attack random alive enemy
	var enemy_squad = combat.get("enemy_squad", [])
	var alive_enemies = []
	for i in range(enemy_squad.size()):
		if validator.validate_entity_alive(enemy_squad[i]):
			alive_enemies.append(i)

	if alive_enemies.is_empty():
		print("[TurnExecutor] No alive enemies for ally to attack")
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
	var old_hp = int(target.get("hp", 100))
	target["hp"] = max(0, old_hp - damage)

	print("[TurnExecutor] Ally %s attacked %s for %d damage (HP: %d -> %d)" % [
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
		"target_max_hp": int(target.get("max_hp", 100)),
		"target_defeated": target["hp"] <= 0,
		"attacker_name": ally_data.get("character_name", "Ally"),
		"target_name": target.get("character_name", "Enemy")
	}


## ========== ENEMY AI ==========

func execute_enemy_turn(combat: Dictionary, enemy_index: int) -> Dictionary:
	## Execute AI turn for enemy NPC
	print("[TurnExecutor] Executing enemy turn: index %d" % enemy_index)

	var enemy_squad = combat.get("enemy_squad", [])
	if enemy_index < 0 or enemy_index >= enemy_squad.size():
		print("[TurnExecutor] ERROR: Invalid enemy index %d" % enemy_index)
		return {"success": false}

	var enemy_data = enemy_squad[enemy_index]

	# Check if enemy is alive using validator
	if not validator or not validator.validate_entity_alive(enemy_data):
		print("[TurnExecutor] Enemy %s is defeated, skipping turn" % enemy_data.get("character_name", "Unknown"))
		return {"success": false}

	# Enemy AI: Attack player OR random ally
	var ally_squad = combat.get("ally_squad", [])
	var player_character = combat.get("player_character", {})
	var possible_targets = []

	# Add player as target if alive
	if validator.validate_entity_alive(player_character):
		possible_targets.append({"type": "player", "index": 0, "data": player_character})

	# Add alive allies as possible targets
	for i in range(ally_squad.size()):
		if validator.validate_entity_alive(ally_squad[i]):
			possible_targets.append({"type": "ally", "index": i, "data": ally_squad[i]})

	if possible_targets.is_empty():
		print("[TurnExecutor] No alive targets for enemy to attack")
		return {"success": false}

	# Pick random target
	var target_info = possible_targets[randi() % possible_targets.size()]
	var target = target_info.data
	var target_index = target_info.index
	var target_type = target_info.type

	# Calculate damage using server battle calculator
	var damage = 0
	if server_battle_manager:
		damage = server_battle_manager.calculate_damage(enemy_data, target, enemy_index, target_index, true)
	else:
		# Fallback calculation
		damage = enemy_data.get("attack", 10) - target.get("defense", 5)
		damage = max(1, damage)

	# Apply defend reduction if player is defending
	if target_type == "player" and combat.get("player_defending", false):
		damage = int(floor(damage * 0.5))
		print("[TurnExecutor] Player defending - damage reduced by 50% (%d -> %d)" % [damage * 2, damage])
		combat["player_defending"] = false  # Reset defend flag

	# Apply damage
	var old_hp = int(target.get("hp", 100))
	target["hp"] = max(0, old_hp - damage)

	print("[TurnExecutor] Enemy %s attacked %s for %d damage (HP: %d -> %d)" % [
		enemy_data.get("character_name", "Enemy"),
		target.get("character_name", "Target"),
		damage,
		old_hp,
		target["hp"]
	])

	# Return result
	return {
		"success": true,
		"action": "attack",
		"target_index": target_index,
		"target_type": target_type,
		"damage": damage,
		"target_hp": target["hp"],
		"target_max_hp": int(target.get("max_hp", 100)),
		"target_defeated": target["hp"] <= 0,
		"attacker_name": enemy_data.get("character_name", "Enemy"),
		"target_name": target.get("character_name", "Target")
	}


## ========== BATTLE END DETECTION ==========

func check_battle_end(combat: Dictionary) -> Dictionary:
	## Check if battle should end (all enemies dead OR player + all allies dead)
	var ally_squad = combat.get("ally_squad", [])
	var enemy_squad = combat.get("enemy_squad", [])

	# Check if player is dead
	var player_character = combat.get("player_character", {})
	var player_dead = not validator.validate_entity_alive(player_character) if validator else player_character.get("hp", 0) <= 0

	# Check if all allies are dead
	var all_allies_dead = true
	for ally in ally_squad:
		if validator:
			if validator.validate_entity_alive(ally):
				all_allies_dead = false
				break
		else:
			if ally.get("hp", 0) > 0:
				all_allies_dead = false
				break

	if player_dead and all_allies_dead:
		print("[TurnExecutor] Battle ended: All allies defeated")
		return {"battle_ended": true, "victor": "enemies"}

	# Check if all enemies are dead
	var all_enemies_dead = true
	for enemy in enemy_squad:
		if validator:
			if validator.validate_entity_alive(enemy):
				all_enemies_dead = false
				break
		else:
			if enemy.get("hp", 0) > 0:
				all_enemies_dead = false
				break

	if all_enemies_dead:
		print("[TurnExecutor] Battle ended: All enemies defeated")
		return {"battle_ended": true, "victor": "allies"}

	# Battle continues
	return {"battle_ended": false, "victor": ""}


## ========== TURN PROGRESSION ==========

func advance_turn(combat: Dictionary) -> Dictionary:
	## Advance to next round
	var current_round = combat.get("round_number", 1)
	combat["round_number"] = current_round + 1

	print("[TurnExecutor] Round %d complete, starting round %d" % [current_round, combat["round_number"]])

	# Emit signal
	round_advanced.emit(-1, combat["round_number"])  # combat_id will be set by controller

	return {"success": true, "new_round": combat["round_number"]}
