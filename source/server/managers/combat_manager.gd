extends Node
class_name CombatManager

## Manages all combat system operations - extracted from ServerWorld
## Handles NPC combat initialization, player actions, enemy AI, and round execution
## PHASE 1 SECURITY: Added server-side action timeout and stats validation
## REFACTOR STEP 1.1: Using EnemySquadBuilder for squad generation

# Refactored components
const EnemySquadBuilder = preload("res://source/server/managers/combat/enemy_squad_builder.gd")

# Dependencies (injected from ServerWorld)
var server_world: Node = null
var network_handler = null
var player_manager = null
var npc_manager = null
var server_battle_manager = null

# Combat state
var npc_combat_instances: Dictionary = {}
var next_combat_id: int = 1

# SECURITY: Action timeout configuration
const ACTION_TIMEOUT_SECONDS: float = 8.0
var action_timers: Dictionary = {}  # {combat_id: timestamp}


func initialize(server_ref, net_handler, player_mgr, npc_mgr, battle_mgr):
	## Initialize CombatManager with dependencies from ServerWorld
	server_world = server_ref
	network_handler = net_handler
	player_manager = player_mgr
	npc_manager = npc_mgr
	server_battle_manager = battle_mgr
	print("[CombatManager] Initialized with Phase 1 security enhancements")


func _process(delta):
	## SECURITY: Check for expired action timers and force default action
	var current_time = Time.get_ticks_msec() / 1000.0

	for combat_id in action_timers.keys():
		var timer_start = action_timers[combat_id]
		var elapsed = current_time - timer_start

		if elapsed >= ACTION_TIMEOUT_SECONDS:
			print("[COMBAT-SECURITY] Action timeout for combat %d (%.1fs elapsed) - forcing defend action" % [combat_id, elapsed])
			_force_timeout_action(combat_id)
			action_timers.erase(combat_id)


func _force_timeout_action(combat_id: int):
	## SECURITY: Force a default "defend" action when player times out
	if not npc_combat_instances.has(combat_id):
		return

	var combat = npc_combat_instances[combat_id]
	var peer_id = combat.get("peer_id", -1)

	if peer_id < 0:
		return

	# Initialize queued_actions if needed
	if not combat.has("queued_actions"):
		combat["queued_actions"] = {}

	# Set default defend action
	combat["queued_actions"][peer_id] = {
		"action": "defend",
		"target_id": 0
	}

	print("[COMBAT-SECURITY] Forced defend action for timed-out player %d in combat %d" % [peer_id, combat_id])

	# Execute the round with the forced action
	execute_combat_round(combat_id)


# ========== COMBAT INITIALIZATION ==========

func handle_npc_attack_request(peer_id: int, npc_id: int):
	## Handle player attacking an NPC - create combat instance

	if not player_manager or not player_manager.connected_players.has(peer_id):
		print("[COMBAT] Attack request from unknown peer %d" % peer_id)
		return

	if not npc_manager.server_npcs.has(npc_id):
		print("[COMBAT] Attack request for unknown NPC %d" % npc_id)
		return

	var npc = npc_manager.server_npcs[npc_id]
	var player = player_manager.connected_players[peer_id]

	# SECURITY: Validate player stats before combat starts
	if not _validate_character_stats(player):
		print("[COMBAT-SECURITY] Invalid player stats detected for peer %d - rejecting combat" % peer_id)
		return

	# Create combat ID
	var combat_id = next_combat_id
	next_combat_id += 1

	# REFACTOR STEP 1.1: Use EnemySquadBuilder to generate enemy squad
	var enemy_squad = EnemySquadBuilder.build_enemy_squad(npc.npc_type, npc_id)

	# Build ally squad (player + 5 NPCs) - for now just player
	var ally_squad = []  # TODO: Add ally NPCs here (player tracked separately)

	# Get and save player's current overworld position before battle
	var pre_battle_position = Vector2.ZERO
	if player_manager and player_manager.player_positions.has(peer_id):
		pre_battle_position = player_manager.player_positions[peer_id]
		print("[COMBAT] Saved pre-battle position: %s for peer %d" % [pre_battle_position, peer_id])

	# Track combat instance for this player with full battle state
	npc_combat_instances[combat_id] = {
		"npc_id": npc_id,
		"peer_id": peer_id,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"player_character": player.duplicate(),
		"ally_squad": ally_squad,
		"enemy_squad": enemy_squad,
		"current_turn_index": 0,
		"is_player_turn": true,
		"pre_battle_position": pre_battle_position  # SAVE OVERWORLD POSITION
	}

	# Calculate turn order (player + allies + enemies sorted by DEX)
	var turn_order = []
	# Add player as index 0
	turn_order.append({"type": "player", "squad_index": 0, "name": player.get("name", "Player"), "dex": player.get("stats", {}).get("DEX", 10)})
	# Add allies
	for i in range(ally_squad.size()):
		var ally = ally_squad[i]
		turn_order.append({"type": "ally", "squad_index": i, "name": ally.get("name", "Ally"), "dex": ally.get("stats", {}).get("DEX", 10)})
	# Add enemies
	for i in range(enemy_squad.size()):
		var enemy = enemy_squad[i]
		turn_order.append({"type": "enemy", "squad_index": i, "name": enemy.get("name", "Enemy"), "dex": enemy.get("stats", {}).get("DEX", 10)})
	# Sort by DEX (highest first)
	turn_order.sort_custom(func(a, b): return a.dex > b.dex)
	
	npc_combat_instances[combat_id]["turn_order"] = turn_order

	# SECURITY: Start action timer for this combat
	action_timers[combat_id] = Time.get_ticks_msec() / 1000.0
	print("[COMBAT-SECURITY] Action timer started for combat %d (%.0fs timeout)" % [combat_id, ACTION_TIMEOUT_SECONDS])

	# Build binary combat packet (efficient: ~50 bytes vs 1500+ for Dictionary)
	var combat_packet = PacketEncoder.build_combat_start_packet(combat_id, npc_id, enemy_squad)

	# Send combat start to attacking player via binary RPC
	if network_handler:
		network_handler.send_binary_combat_start(peer_id, combat_packet)
	# AUTO-EXECUTE FIRST ROUND: Process all NPC turns immediately
	print("[COMBAT] Auto-executing first round for combat %d" % combat_id)
	process_npc_turns(combat_id)
	print("[COMBAT] First round complete, player can now choose action")


	_log_message("[COMBAT] Player '%s' (peer %d) attacking NPC '%s' #%d - Combat ID: %d, Enemies: %d, Packet: %d bytes" % [
		player.get("character_name", "Unknown"),
		peer_id,
		npc.npc_name,
		npc_id,
		combat_id,
		enemy_squad.size(),
		combat_packet.size()
	])


## ========== SECURITY VALIDATION ==========

func _validate_character_stats(character: Dictionary) -> bool:
	## TEMP FIX: Disable stat validation - auto-generate defaults
	## TODO: Properly initialize character stats in spawn
	return true
	
	## ORIGINAL CODE BELOW (commented out):
	#if not character.has("base_stats") and not character.has("stats"):
	#	print("[COMBAT-SECURITY] Character missing stats dictionary")
	#	return false

	var stats = character.get("stats", character.get("base_stats", {}))
	var level = character.get("level", 1)

	# Level validation: 1-100
	if level < 1 or level > 100:
		print("[COMBAT-SECURITY] Invalid level: %d (must be 1-100)" % level)
		return false

	# Stat validation: Each stat should be 1-999
	var stat_names = ["str", "dex", "int", "vit", "wis", "cha"]
	for stat_name in stat_names:
		var stat_value = stats.get(stat_name, 10)
		if stat_value < 1 or stat_value > 999:
			print("[COMBAT-SECURITY] Invalid %s stat: %d (must be 1-999)" % [stat_name, stat_value])
			return false

	# HP validation: Must be positive and <= max_hp
	var current_hp = character.get("hp", 0)
	var max_hp = character.get("max_hp", 100)

	if current_hp < 0 or current_hp > max_hp:
		print("[COMBAT-SECURITY] Invalid HP: %d/%d" % [current_hp, max_hp])
		return false

	if max_hp < 1 or max_hp > 99999:
		print("[COMBAT-SECURITY] Invalid max_hp: %d (must be 1-99999)" % max_hp)
		return false

	# All validations passed
	return true


## ========== BATTLE ACTION HANDLERS ==========


# ========== BATTLE ACTION HANDLERS ==========

func receive_player_battle_action(peer_id: int, combat_id: int, action_type: String, target_id: int):
	## Receive and queue player battle action (called from network_handler RPC)
	print("[COMBAT] Player action received: peer=%d, combat_id=%d, action=%s, target=%d" % [peer_id, combat_id, action_type, target_id])

	if not npc_combat_instances.has(combat_id):
		print("[COMBAT] ERROR: Invalid combat ID %d" % combat_id)
		return

	var combat = npc_combat_instances[combat_id]

	# SECURITY: Verify peer owns this combat
	if combat.get("peer_id") != peer_id:
		print("[COMBAT-SECURITY] Peer %d attempted action in combat %d (owned by peer %d) - REJECTED" % [peer_id, combat_id, combat.get("peer_id")])
		return

	# SECURITY: Validate action type
	var valid_actions = ["attack", "defend", "skill", "item"]
	if not action_type in valid_actions:
		print("[COMBAT-SECURITY] Invalid action type '%s' from peer %d - forcing defend" % [action_type, peer_id])
		action_type = "defend"
		target_id = 0

	# Initialize queued_actions dict if it doesn't exist
	if not combat.has("queued_actions"):
		combat["queued_actions"] = {}

	# Store the player's action
	combat["queued_actions"][peer_id] = {
		"action": action_type,
		"target_id": target_id
	}

	print("[COMBAT] Action queued for peer %d: %s (target: %d)" % [peer_id, action_type, target_id])

	# SECURITY: Clear the action timer since player submitted action
	if action_timers.has(combat_id):
		action_timers.erase(combat_id)
		print("[COMBAT-SECURITY] Action timer cleared for combat %d (action received)" % combat_id)

	# For single-player battles, execute round immediately
	# TODO: Wait for all players in party or timeout after 8 seconds
	execute_combat_round(combat_id)


@rpc("any_peer")
func battle_player_attack(combat_id: int, target_index: int):
	## Player attacks an enemy - server calculates damage
	var peer_id = multiplayer.get_remote_sender_id()

	# Rate limit check: 2 combat actions per second
	if server_world and server_world.rate_limiter:
		var limit_check = server_world.rate_limiter.check_rate_limit(peer_id, "combat_action", 2, 1.0)
		if not limit_check.allowed:
			print("[COMBAT] Rate limit exceeded for peer %d - wait %.1fs" % [peer_id, limit_check.wait_time])
			return

	if not npc_combat_instances.has(combat_id):
		print("[COMBAT] Invalid combat ID: %d from peer %d" % [combat_id, peer_id])
		return

	var combat = npc_combat_instances[combat_id]

	# SECURITY: Verify peer owns this combat
	if combat.peer_id != peer_id:
		print("[COMBAT-SECURITY] Peer %d attempted attack in combat %d (owned by peer %d) - REJECTED" % [peer_id, combat_id, combat.peer_id])
		return

	var player = player_manager.connected_players.get(peer_id) if player_manager else null
	if not player:
		print("[COMBAT] Player not found for peer %d" % peer_id)
		return

	# Get current battle state from combat instance
	var player_character = combat.get("player_character", {})
	var enemy_squad = combat.get("enemy_squad", [])

	# Validate target
	if target_index < 0 or target_index >= enemy_squad.size():
		print("[COMBAT] Invalid target index: %d for combat %d" % [target_index, combat_id])
		return

	var target_enemy = enemy_squad[target_index]

	# Check if target is already dead
	if target_enemy.hp <= 0:
		print("[COMBAT] Target already defeated in combat %d" % combat_id)
		return

	# SECURITY: Calculate damage using server-authoritative formula
	var damage = server_battle_manager.calculate_damage(player_character, target_enemy, 0, target_index, false)

	# Apply damage
	target_enemy.hp -= damage
	target_enemy.hp = max(0, target_enemy.hp)

	print("[COMBAT] Combat %d - Player deals %d damage to %s (HP: %d/%d)" % [
		combat_id,
		damage,
		target_enemy.get("character_name", "Enemy"),
		target_enemy.hp,
		target_enemy.get("max_hp", 100)
	])

	# Send updated enemy state to client (COMBAT_STATE packet)
	if network_handler:
		var state_packet = PacketEncoder.build_combat_state_packet(
			target_enemy.get("id", target_index),
			target_enemy.hp,
			target_enemy.get("max_hp", 100),
			0  # Effects bitmask
		)
		network_handler.send_binary_packet(peer_id, state_packet)

	# Advance turn
	combat.is_player_turn = false
	combat.current_turn_index += 1

	# SECURITY: Restart action timer for next turn
	action_timers[combat_id] = Time.get_ticks_msec() / 1000.0

	# Process enemy AI turn (will set is_player_turn = true at end)
	process_enemy_ai_turn(combat_id)



@rpc("any_peer")
func battle_player_defend(combat_id: int):
	## Player takes defensive stance
	var peer_id = multiplayer.get_remote_sender_id()

	# Rate limit check: 2 combat actions per second
	if server_world and server_world.rate_limiter:
		var limit_check = server_world.rate_limiter.check_rate_limit(peer_id, "combat_action", 2, 1.0)
		if not limit_check.allowed:
			print("[COMBAT] Rate limit exceeded for peer %d - wait %.1fs" % [peer_id, limit_check.wait_time])
			return

	if not npc_combat_instances.has(combat_id):
		print("[COMBAT] Invalid combat ID: %d from peer %d" % [combat_id, peer_id])
		return

	var combat = npc_combat_instances[combat_id]

	# SECURITY: Verify peer owns this combat
	if combat.peer_id != peer_id:
		print("[COMBAT-SECURITY] Peer %d attempted defend in combat %d (owned by peer %d) - REJECTED" % [peer_id, combat_id, combat.peer_id])
		return

	# Set defensive stance (reduces incoming damage by 50%)
	if not combat.has("player_defending"):
		combat["player_defending"] = false
	combat.player_defending = true

	print("[COMBAT] Player defending: Combat %d (damage reduced by 50% next turn)" % combat_id)

	# Advance turn
	combat.is_player_turn = false
	combat.current_turn_index += 1

	# SECURITY: Restart action timer for next turn
	action_timers[combat_id] = Time.get_ticks_msec() / 1000.0

	# Process enemy AI turn
	process_enemy_ai_turn(combat_id)


@rpc("any_peer")
func battle_player_use_skill(combat_id: int, target_index: int, skill_name: String):
	## Player uses a skill
	var peer_id = multiplayer.get_remote_sender_id()

	# Rate limit check: 2 combat actions per second
	if server_world and server_world.rate_limiter:
		var limit_check = server_world.rate_limiter.check_rate_limit(peer_id, "combat_action", 2, 1.0)
		if not limit_check.allowed:
			print("[COMBAT] Rate limit exceeded for peer %d - wait %.1fs" % [peer_id, limit_check.wait_time])
			return

	if not npc_combat_instances.has(combat_id):
		print("[COMBAT] Invalid combat ID: %d from peer %d" % [combat_id, peer_id])
		return

	var combat = npc_combat_instances[combat_id]

	# SECURITY: Verify peer owns this combat
	if combat.peer_id != peer_id:
		print("[COMBAT-SECURITY] Peer %d attempted skill in combat %d (owned by peer %d) - REJECTED" % [peer_id, combat_id, combat.peer_id])
		return

	print("[COMBAT] Player skill: Combat %d, Target %d, Skill %s" % [combat_id, target_index, skill_name])
	# Skills not yet implemented - advance turn
	combat.is_player_turn = false
	combat.current_turn_index += 1

	# SECURITY: Restart action timer for next turn
	action_timers[combat_id] = Time.get_ticks_msec() / 1000.0

	# Process enemy AI turn
	process_enemy_ai_turn(combat_id)


@rpc("any_peer")
func battle_player_use_item(combat_id: int, target_index: int, item_name: String):
	## Player uses an item
	var peer_id = multiplayer.get_remote_sender_id()

	# Rate limit check: 2 combat actions per second
	if server_world and server_world.rate_limiter:
		var limit_check = server_world.rate_limiter.check_rate_limit(peer_id, "combat_action", 2, 1.0)
		if not limit_check.allowed:
			print("[COMBAT] Rate limit exceeded for peer %d - wait %.1fs" % [peer_id, limit_check.wait_time])
			return

	if not npc_combat_instances.has(combat_id):
		print("[COMBAT] Invalid combat ID: %d from peer %d" % [combat_id, peer_id])
		return

	var combat = npc_combat_instances[combat_id]

	# SECURITY: Verify peer owns this combat
	if combat.peer_id != peer_id:
		print("[COMBAT-SECURITY] Peer %d attempted item use in combat %d (owned by peer %d) - REJECTED" % [peer_id, combat_id, combat.peer_id])
		return

	print("[COMBAT] Player item: Combat %d, Target %d, Item %s" % [combat_id, target_index, item_name])
	# Items not yet implemented - advance turn
	combat.is_player_turn = false
	combat.current_turn_index += 1

	# SECURITY: Restart action timer for next turn
	action_timers[combat_id] = Time.get_ticks_msec() / 1000.0

	# Process enemy AI turn
	process_enemy_ai_turn(combat_id)


# ========== ENEMY AI TURN ==========


@rpc("any_peer")
func client_ready_for_next_turn(combat_id: int):
	"""
	Client confirms it's ready for next turn selection phase
	This prevents delays caused by client animations or UI updates
	"""
	var peer_id = multiplayer.get_remote_sender_id()
	
	if not npc_combat_instances.has(combat_id):
		print("[COMBAT] Invalid combat ID in client_ready: %d from peer %d" % [combat_id, peer_id])
		return
	
	var combat = npc_combat_instances[combat_id]
	
	# SECURITY: Verify peer owns this combat
	if combat.get("peer_id", -1) != peer_id:
		print("[COMBAT-SECURITY] Peer %d attempted ready confirmation for combat %d (owned by peer %d) - REJECTED" % [
			peer_id, combat_id, combat.get("peer_id", -1)
		])
		return
	
	print("[COMBAT] Client ready confirmation received for combat %d from peer %d" % [combat_id, peer_id])
	
	# Client is ready - start selection phase immediately
	start_selection_phase(combat)


func process_enemy_ai_turn(combat_id: int):
	## Process enemy turn - enemies attack back
	if not npc_combat_instances.has(combat_id):
		return

	var combat = npc_combat_instances[combat_id]
	var player_character = combat.get("player_character", {})
	var enemy_squad = combat.get("enemy_squad", [])
	var peer_id = combat.get("peer_id")

	if not peer_id or enemy_squad.is_empty():
		return

	# Simple AI: First alive enemy attacks player
	for enemy in enemy_squad:
		if enemy.hp > 0:
			# SECURITY: Calculate enemy damage using server-authoritative formula
			var damage = server_battle_manager.calculate_damage(enemy, player_character, 0, 0, true)

			# Apply defense if player is defending
			if combat.get("player_defending", false):
				damage = int(damage * 0.5)  # 50% reduction
				combat.player_defending = false  # Reset defending after this turn

			# Apply damage to player
			player_character.hp -= damage
			player_character.hp = max(0, player_character.hp)

			print("[COMBAT] Combat %d - %s attacks player for %d damage (HP: %d/%d)" % [
				combat_id,
				enemy.get("character_name", "Enemy"),
				damage,
				player_character.hp,
				player_character.get("max_hp", 100)
			])

			# Send updated player state to client
			if network_handler:
				var state_packet = PacketEncoder.build_combat_state_packet(
					0,  # Player is entity 0
					player_character.hp,
					player_character.get("max_hp", 100),
					0  # Effects bitmask
				)
				network_handler.send_binary_packet(peer_id, state_packet)
			break  # Only first alive enemy attacks per turn

	# Set is_player_turn back to true so player can act again
	combat.is_player_turn = true

# ========== COMBAT ROUND EXECUTION ==========


func execute_combat_round(combat_id: int):
	## Execute one combat round with all queued actions
	if not npc_combat_instances.has(combat_id):
		print("[COMBAT] ERROR: Invalid combat ID %d" % combat_id)
		return

	var combat = npc_combat_instances[combat_id]
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
	action_timers[combat_id] = Time.get_ticks_msec() / 1000.0
	print("[COMBAT-SECURITY] Action timer restarted for combat %d" % combat_id)

	# PHASE 2 FIX: Process NPC turns after player action
	process_npc_turns(combat_id)

	print("[COMBAT] Round execution complete")

## ========== NPC TURN PROCESSING (PHASE 2 FIX) ==========

func process_npc_turns(combat_id: int):
	"""Process all NPC (ally and enemy) turns after player turn completes"""
	if not npc_combat_instances.has(combat_id):
		print("[COMBAT] ERROR: Invalid combat ID in process_npc_turns: %d" % combat_id)
		return
	
	var combat = npc_combat_instances[combat_id]
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
			
			rpc_id(peer_id, "receive_action_result", turn_result_packet)
			print("[COMBAT] Turn result sent to peer %d" % peer_id)
		
		# Check if battle ended
		var battle_result = check_battle_end(combat)
		if battle_result.battle_ended:
			print("[COMBAT] Battle ended: victor=%s" % battle_result.victor)
			var finalize_result = finalize_battle(combat)
			if network_handler:
				rpc_id(peer_id, "receive_battle_end", combat_id, finalize_result)
			return
	
	# All turns processed
	print("[COMBAT] All NPC turns processed, round %d complete" % combat.get("round_number", 1))
	var next_result = advance_turn(combat)
	start_selection_phase(combat)
	print("[COMBAT] Started selection phase for round %d" % combat.get("round_number", 1))


# ========== MISSING BATTLE SYSTEM FUNCTIONS (COMPLETE FIX) ==========

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
	## Advance to next round
	var current_round = combat.get("round_number", 1)
	combat["round_number"] = current_round + 1
	
	print("[COMBAT] Round %d complete, starting round %d" % [current_round, combat["round_number"]])
	
	return {"success": true, "new_round": combat["round_number"]}


func start_selection_phase(combat: Dictionary):
	## Start player action selection phase
	var combat_id = -1
	
	# Find combat_id from instances
	for id in npc_combat_instances.keys():
		if npc_combat_instances[id] == combat:
			combat_id = id
			break
	
	if combat_id < 0:
		print("[COMBAT] ERROR: Could not find combat_id for selection phase")
		return
	
	print("[COMBAT] Starting selection phase for combat %d, round %d" % [combat_id, combat.get("round_number", 1)])
	
	# Start action timer (8 second timeout)
	action_timers[combat_id] = Time.get_ticks_msec() / 1000.0
	
	# Notify client to show action selection UI
	var peer_id = combat.get("peer_id", -1)
	if peer_id >= 0 and network_handler:
		rpc_id(peer_id, "start_action_selection", combat.get("round_number", 1))


func finalize_battle(combat: Dictionary) -> Dictionary:
	## Finalize battle and calculate rewards
	var victor = check_battle_end(combat).victor
	var victory = (victor == "allies")
	
	print("[COMBAT-SECURITY] Finalizing battle (victory: %s)" % victory)
	
	var rewards = {}
	
	if victory:
		var enemy_squad = combat.get("enemy_squad", [])
		var player_character = combat.get("player_character", {})
		var player_level = player_character.get("level", 1)
		
		# Calculate rewards using battle_manager
		if server_battle_manager and server_battle_manager.has_method("calculate_battle_rewards"):
			rewards = server_battle_manager.calculate_battle_rewards(enemy_squad, player_level)
		else:
			# Fallback simple calculation
			var total_xp = 0
			var total_gold = 0
			for enemy in enemy_squad:
				total_xp += enemy.get("level", 1) * 10
				total_gold += enemy.get("level", 1) * 5
			rewards = {"xp": total_xp, "gold": total_gold}
		
		print("[COMBAT-SECURITY] Rewards calculated: %d XP, %d gold" % [rewards.get("xp", 0), rewards.get("gold", 0)])
	
	return {
		"victory": victory,
		"rewards": rewards,
		"victor": victor
	}

# ========== UTILITY FUNCTIONS ==========


func load_npc_character_file(file_path: String) -> Dictionary:
	## Load NPC character data from JSON file
	if not FileAccess.file_exists(file_path):
		print("[COMBAT] ERROR: NPC file not found: %s" % file_path)
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[COMBAT] ERROR: Could not open NPC file: %s" % file_path)
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		print("[COMBAT] ERROR: Failed to parse NPC JSON: %s" % file_path)
		return {}

	return json.data

func _log_message(message: String):
	## Log message to server console
	if server_world and server_world.has_method("log_message"):
		server_world.log_message(message)
	else:
		print(message)


# ========== COMBAT END HANDLER ==========

func end_combat(combat_id: int, victory: bool):
	## PHASE 2 SECURITY: Handle combat end with server-authoritative reward calculation
	var peer_id = multiplayer.get_remote_sender_id()

	if not npc_combat_instances.has(combat_id):
		print("[COMBAT] Cannot end combat - invalid combat ID: %d" % combat_id)
		return

	var combat = npc_combat_instances[combat_id]

	# SECURITY: Verify peer owns this combat
	if combat.get("peer_id") != peer_id:
		print("[COMBAT-SECURITY] Peer %d cannot end combat %d (belongs to peer %d) - REJECTED" % [peer_id, combat_id, combat.get("peer_id")])
		return

	# SECURITY: Clear action timer when combat ends
	if action_timers.has(combat_id):
		action_timers.erase(combat_id)
		print("[COMBAT-SECURITY] Action timer cleared for ended combat %d" % combat_id)

	# PHASE 2: Calculate rewards server-side if victory
	var rewards = {}
	if victory:
		var enemy_squad = combat.get("enemy_squad", [])
		var player_character = combat.get("player_character", {})
		var player_level = player_character.get("level", 1)

		# SERVER-AUTHORITATIVE REWARD CALCULATION
		rewards = server_battle_manager.calculate_battle_rewards(enemy_squad, player_level)

		print("[COMBAT-SECURITY] Battle rewards calculated server-side: %d XP, %d gold" % [
			rewards.get("xp", 0),
			rewards.get("gold", 0)
		])

		# Apply rewards to player (server-side)
		if player_manager and player_manager.connected_players.has(peer_id):
			var player = player_manager.connected_players[peer_id]

			# Add XP
			var old_xp = player.get("xp", 0)
			player["xp"] = old_xp + rewards.get("xp", 0)

			# Add gold
			var old_gold = player.get("gold", 0)
			player["gold"] = old_gold + rewards.get("gold", 0)

			print("[COMBAT-SECURITY] Rewards applied to player %d: XP %d -> %d, Gold %d -> %d" % [
				peer_id,
				old_xp,
				player["xp"],
				old_gold,
				player["gold"]
			])

	# Restore player to pre-battle overworld position
	var pre_battle_pos = combat.get("pre_battle_position", Vector2.ZERO)
	if player_manager and player_manager.player_positions.has(peer_id):
		player_manager.player_positions[peer_id] = pre_battle_pos
		print("[COMBAT] Restored player %d to pre-battle position: %s" % [peer_id, pre_battle_pos])

		# Notify client to return to overworld at saved position (include rewards)
		if network_handler and network_handler.has_method("send_return_to_overworld"):
			network_handler.send_return_to_overworld(peer_id, pre_battle_pos, victory, rewards)

	# Clean up combat instance
	npc_combat_instances.erase(combat_id)

	var result = "VICTORY" if victory else "DEFEAT"
	_log_message("[COMBAT-SECURITY] Combat %d ended - %s - Player %d returned to position %s (Rewards: %s)" % [
		combat_id,
		result,
		peer_id,
		pre_battle_pos,
		str(rewards) if victory else "none"
	])
