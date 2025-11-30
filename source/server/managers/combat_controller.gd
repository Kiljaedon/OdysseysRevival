extends Node
class_name CombatController

## Combat Controller - Orchestrates combat system
## Extracted from CombatManager for focused responsibility
## Handles: combat lifecycle, RPC routing, state management, timeout enforcement

# Preload dependencies (required for Godot 4 class resolution)
const CombatValidatorScript = preload("res://source/server/managers/combat_validator.gd")
const TurnExecutorScript = preload("res://source/server/managers/turn_executor.gd")

# Dependencies (injected from ServerWorld)
var server_world: Node = null
var network_handler: Node = null
var player_manager: Node = null
var npc_manager: Node = null
var server_battle_manager: Node = null

# Sub-systems (created internally)
var validator = null
var executor = null

# Combat state
var npc_combat_instances: Dictionary = {}  # {combat_id: combat_data}
var next_combat_id: int = 1

# Action timeout tracking
const ACTION_TIMEOUT_SECONDS: float = 8.0
var action_timers: Dictionary = {}  # {combat_id: timestamp}

## ========== INITIALIZATION ==========

func initialize(server_ref: Node, net_handler: Node, player_mgr: Node, npc_mgr: Node, battle_mgr: Node) -> void:
	## Initialize CombatController with dependencies from ServerWorld
	server_world = server_ref
	network_handler = net_handler
	player_manager = player_mgr
	npc_manager = npc_mgr
	server_battle_manager = battle_mgr

	# Create sub-systems
	validator = CombatValidatorScript.new()
	validator.initialize(server_world, player_manager)
	add_child(validator)

	executor = TurnExecutorScript.new()
	executor.initialize(server_world, network_handler, server_battle_manager, validator)
	add_child(executor)

	# Connect executor signals
	executor.turn_complete.connect(_on_turn_complete)
	executor.battle_ended.connect(_on_battle_ended)
	executor.round_advanced.connect(_on_round_advanced)

	print("[CombatController] Initialized with validator and executor sub-systems")


func _process(delta: float) -> void:
	## SECURITY: Check for expired action timers and force default action
	var current_time = Time.get_ticks_msec() / 1000.0

	for combat_id in action_timers.keys():
		var timer_start = action_timers[combat_id]

		if validator.is_action_timeout(timer_start, current_time):
			var elapsed = validator.get_timeout_elapsed(timer_start, current_time)
			print("[CombatController-SECURITY] Action timeout for combat %d (%.1fs elapsed) - forcing defend action" % [combat_id, elapsed])
			_force_timeout_action(combat_id)
			action_timers.erase(combat_id)


func _force_timeout_action(combat_id: int) -> void:
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

	print("[CombatController-SECURITY] Forced defend action for timed-out player %d in combat %d" % [peer_id, combat_id])

	# Execute the round with the forced action
	var round_result = executor.execute_combat_round(combat_id, combat, peer_id)

	# Send results and continue with NPC turns
	if not round_result.has("error"):
		executor.process_npc_turns(combat_id, combat, peer_id)


## ========== COMBAT INITIALIZATION ==========

func handle_npc_attack_request(peer_id: int, npc_id: int) -> void:
	## Handle player attacking an NPC - create combat instance

	# Validate player exists
	if not validator.validate_player_exists(peer_id):
		print("[CombatController] Attack request from unknown peer %d" % peer_id)
		return

	# Validate NPC exists
	if not npc_manager.server_npcs.has(npc_id):
		print("[CombatController] Attack request for unknown NPC %d" % npc_id)
		return

	var npc = npc_manager.server_npcs[npc_id]
	var player = player_manager.connected_players[peer_id]

	# SECURITY: Validate player stats before combat starts
	if not validator.validate_character_stats(player):
		print("[CombatController-SECURITY] Invalid player stats detected for peer %d - rejecting combat" % peer_id)
		return

	# Create combat ID
	var combat_id = next_combat_id
	next_combat_id += 1

	# Generate enemy squad
	var enemy_squad = _generate_enemy_squad(npc)

	# Build ally squad (currently empty - player tracked separately)
	var ally_squad = []

	# Save player's pre-battle position
	var pre_battle_position = Vector2.ZERO
	if player_manager.player_positions.has(peer_id):
		pre_battle_position = player_manager.player_positions[peer_id]
		print("[CombatController] Saved pre-battle position: %s for peer %d" % [pre_battle_position, peer_id])

	# Create combat instance
	var combat = {
		"npc_id": npc_id,
		"peer_id": peer_id,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"player_character": player.duplicate(),
		"ally_squad": ally_squad,
		"enemy_squad": enemy_squad,
		"current_turn_index": 0,
		"is_player_turn": true,
		"pre_battle_position": pre_battle_position,
		"round_number": 1,
		"queued_actions": {},
		"player_defending": false
	}

	# Calculate turn order
	combat["turn_order"] = _calculate_turn_order(player, ally_squad, enemy_squad)

	# Store combat instance
	npc_combat_instances[combat_id] = combat

	# SECURITY: Start action timer
	action_timers[combat_id] = Time.get_ticks_msec() / 1000.0
	print("[CombatController-SECURITY] Action timer started for combat %d (%.0fs timeout)" % [combat_id, ACTION_TIMEOUT_SECONDS])

	# Build and send combat start packet
	var combat_packet = PacketEncoder.build_combat_start_packet(combat_id, npc_id, enemy_squad)
	if network_handler:
		network_handler.send_binary_combat_start(peer_id, combat_packet)

	# AUTO-EXECUTE FIRST ROUND: Process all NPC turns immediately
	print("[CombatController] Auto-executing first round for combat %d" % combat_id)
	executor.process_npc_turns(combat_id, combat, peer_id)
	print("[CombatController] First round complete, player can now choose action")

	_log_message("[CombatController] Player '%s' (peer %d) attacking NPC '%s' #%d - Combat ID: %d" % [
		player.get("character_name", "Unknown"),
		peer_id,
		npc.npc_name,
		npc_id,
		combat_id
	])


func _generate_enemy_squad(npc: Dictionary) -> Array:
	## Generate enemy squad: attacked NPC (boss) + 5 random NPCs
	var enemy_squad = []

	# Load the attacked NPC as boss
	var boss_file_path = "res://characters/npcs/" + npc.npc_type + ".json"
	var boss_data = load_npc_character_file(boss_file_path)

	if not boss_data.is_empty():
		boss_data["character_name"] = npc.npc_type + " 1"
		boss_data["name"] = npc.npc_type + " 1"
		boss_data["level"] = randi_range(1, 5)
		_initialize_npc_stats(boss_data)
		enemy_squad.append(boss_data)

	# Load 5 random NPCs
	var npc_types = ["Rogue", "Goblin", "OrcWarrior", "DarkMage", "EliteGuard", "RogueBandit"]
	npc_types.shuffle()

	for i in range(5):
		var random_type = npc_types[i % npc_types.size()]
		var enemy_file_path = "res://characters/npcs/" + random_type + ".json"
		var enemy_data = load_npc_character_file(enemy_file_path)

		if not enemy_data.is_empty():
			enemy_data["character_name"] = random_type + " " + str(i + 2)
			enemy_data["name"] = random_type + " " + str(i + 2)
			enemy_data["level"] = randi_range(1, 5)
			_initialize_npc_stats(enemy_data)
			enemy_squad.append(enemy_data)

	return enemy_squad


func _initialize_npc_stats(npc_data: Dictionary) -> void:
	## Initialize NPC stats from derived_stats or defaults
	if npc_data.has("derived_stats"):
		var derived = npc_data.derived_stats
		npc_data["max_hp"] = derived.get("max_hp", 100)
		npc_data["hp"] = npc_data["max_hp"]
		npc_data["max_mp"] = derived.get("max_mp", 50)
		npc_data["mp"] = npc_data["max_mp"]
		npc_data["max_energy"] = derived.get("max_ep", 100)
		npc_data["energy"] = npc_data["max_energy"]
		npc_data["attack"] = derived.get("phys_dmg", 10)
		npc_data["defense"] = derived.get("phys_def", 10)
	else:
		# Fallback defaults
		npc_data["max_hp"] = 100
		npc_data["hp"] = 100
		npc_data["max_mp"] = 50
		npc_data["mp"] = 50
		npc_data["max_energy"] = 100
		npc_data["energy"] = 100
		npc_data["attack"] = 10
		npc_data["defense"] = 10


func _calculate_turn_order(player: Dictionary, ally_squad: Array, enemy_squad: Array) -> Array:
	## Calculate turn order sorted by DEX (highest first)
	var turn_order = []

	# Add player
	turn_order.append({
		"type": "player",
		"squad_index": 0,
		"name": player.get("name", "Player"),
		"dex": player.get("stats", {}).get("DEX", 10)
	})

	# Add allies
	for i in range(ally_squad.size()):
		var ally = ally_squad[i]
		turn_order.append({
			"type": "ally",
			"squad_index": i,
			"name": ally.get("name", "Ally"),
			"dex": ally.get("stats", {}).get("DEX", 10)
		})

	# Add enemies
	for i in range(enemy_squad.size()):
		var enemy = enemy_squad[i]
		turn_order.append({
			"type": "enemy",
			"squad_index": i,
			"name": enemy.get("name", "Enemy"),
			"dex": enemy.get("stats", {}).get("DEX", 10)
		})

	# Sort by DEX (highest first)
	turn_order.sort_custom(func(a, b): return a.dex > b.dex)

	return turn_order


## ========== PLAYER ACTION HANDLING ==========

func receive_player_battle_action(peer_id: int, combat_id: int, action_type: String, target_id: int) -> void:
	## Receive and queue player battle action (called from network_handler RPC)
	print("[CombatController] Player action received: peer=%d, combat_id=%d, action=%s, target=%d" % [peer_id, combat_id, action_type, target_id])

	# Validate combat exists
	if not validator.validate_combat_exists(combat_id, npc_combat_instances):
		return

	var combat = npc_combat_instances[combat_id]

	# SECURITY: Verify peer owns this combat
	if not validator.validate_combat_ownership(combat, peer_id):
		return

	# SECURITY: Validate and sanitize action type
	action_type = validator.sanitize_action_type(action_type, peer_id)

	# Initialize queued_actions if needed
	if not combat.has("queued_actions"):
		combat["queued_actions"] = {}

	# Queue the action
	combat["queued_actions"][peer_id] = {
		"action": action_type,
		"target_id": target_id
	}

	print("[CombatController] Action queued: %s (target: %d)" % [action_type, target_id])

	# Clear action timer (player responded in time)
	if action_timers.has(combat_id):
		action_timers.erase(combat_id)
		print("[CombatController-SECURITY] Action timer cleared for combat %d (player responded)" % combat_id)

	# Execute the combat round
	var round_result = executor.execute_combat_round(combat_id, combat, peer_id)

	# Continue with NPC turns if round succeeded
	if not round_result.has("error"):
		executor.process_npc_turns(combat_id, combat, peer_id)


## ========== CLIENT READY CONFIRMATION ==========

@rpc("any_peer")
func client_ready_for_next_turn(combat_id: int) -> void:
	## Client confirms it's ready for next turn selection phase
	var peer_id = multiplayer.get_remote_sender_id()

	# Validate combat exists
	if not validator.validate_combat_exists(combat_id, npc_combat_instances):
		return

	var combat = npc_combat_instances[combat_id]

	# SECURITY: Verify peer owns this combat
	if not validator.validate_combat_ownership(combat, peer_id):
		return

	print("[CombatController] Client ready confirmation received for combat %d from peer %d" % [combat_id, peer_id])

	# Client is ready - start selection phase immediately
	start_selection_phase(combat)


## ========== SELECTION PHASE ==========

func start_selection_phase(combat: Dictionary) -> void:
	## Start player action selection phase
	var combat_id = _find_combat_id(combat)

	if combat_id < 0:
		print("[CombatController] ERROR: Could not find combat_id for selection phase")
		return

	print("[CombatController] Starting selection phase for combat %d, round %d" % [combat_id, combat.get("round_number", 1)])

	# Start action timer (8 second timeout)
	action_timers[combat_id] = Time.get_ticks_msec() / 1000.0

	# Notify client to show action selection UI
	var peer_id = combat.get("peer_id", -1)
	if peer_id >= 0 and network_handler:
		rpc_id(peer_id, "start_action_selection", combat.get("round_number", 1))


## ========== SIGNAL HANDLERS ==========

func _on_turn_complete(combat_id: int, peer_id: int, turn_results: Array) -> void:
	## Handle turn completion from TurnExecutor
	print("[CombatController] Turn complete for combat %d" % combat_id)
	# Send turn results to client
	if network_handler and peer_id >= 0:
		for turn_result_packet in turn_results:
			rpc_id(peer_id, "receive_action_result", turn_result_packet)
		print("[COMBAT] Turn results sent to peer %d" % peer_id)
	
	# Start next selection phase
	if npc_combat_instances.has(combat_id):
		var combat = npc_combat_instances[combat_id]
		start_selection_phase(combat)
		print("[COMBAT] Started selection phase for round %d" % combat.get("round_number", 1))


func _on_battle_ended(combat_id: int, victor: String) -> void:
	## Handle battle end from TurnExecutor
	print("[CombatController] Battle ended: combat %d, victor: %s" % [combat_id, victor])

	if not npc_combat_instances.has(combat_id):
		return

	var combat = npc_combat_instances[combat_id]
	var peer_id = combat.get("peer_id", -1)

	# Finalize battle and calculate rewards
	var finalize_result = finalize_battle(combat)

	# Send battle end notification to client
	if network_handler and peer_id >= 0:
		rpc_id(peer_id, "receive_battle_end", combat_id, finalize_result)

	# Clean up after short delay (let client process)
	await get_tree().create_timer(1.0).timeout
	end_combat(combat_id, finalize_result.get("victory", false))


func _on_round_advanced(combat_id: int, new_round: int) -> void:
	## Handle round advancement from TurnExecutor
	print("[CombatController] Round advanced to %d for combat %d" % [new_round, combat_id])


## ========== BATTLE FINALIZATION ==========

func finalize_battle(combat: Dictionary) -> Dictionary:
	## Finalize battle and calculate rewards
	var battle_result = executor.check_battle_end(combat)
	var victor = battle_result.victor
	var victory = (victor == "allies")

	print("[CombatController-SECURITY] Finalizing battle (victory: %s)" % victory)

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

		print("[CombatController-SECURITY] Rewards calculated: %d XP, %d gold" % [rewards.get("xp", 0), rewards.get("gold", 0)])

	return {
		"victory": victory,
		"rewards": rewards,
		"victor": victor
	}


func end_combat(combat_id: int, victory: bool) -> void:
	## Clean up combat and apply rewards
	if not npc_combat_instances.has(combat_id):
		print("[CombatController] Cannot end combat - invalid combat ID: %d" % combat_id)
		return

	var combat = npc_combat_instances[combat_id]
	var peer_id = combat.get("peer_id", -1)

	# SECURITY: Clear action timer
	if action_timers.has(combat_id):
		action_timers.erase(combat_id)
		print("[CombatController-SECURITY] Action timer cleared for ended combat %d" % combat_id)

	# Apply rewards if victory
	if victory and player_manager and player_manager.connected_players.has(peer_id):
		var player = player_manager.connected_players[peer_id]
		var enemy_squad = combat.get("enemy_squad", [])
		var player_level = player.get("level", 1)

		# SERVER-AUTHORITATIVE REWARD CALCULATION
		var rewards = {}
		if server_battle_manager:
			rewards = server_battle_manager.calculate_battle_rewards(enemy_squad, player_level)

		# Apply rewards
		var old_xp = player.get("xp", 0)
		player["xp"] = old_xp + rewards.get("xp", 0)

		var old_gold = player.get("gold", 0)
		player["gold"] = old_gold + rewards.get("gold", 0)

		print("[CombatController-SECURITY] Rewards applied to player %d: XP %d -> %d, Gold %d -> %d" % [
			peer_id, old_xp, player["xp"], old_gold, player["gold"]
		])

	# Restore player to pre-battle position
	var pre_battle_pos = combat.get("pre_battle_position", Vector2.ZERO)
	if player_manager and player_manager.player_positions.has(peer_id):
		player_manager.player_positions[peer_id] = pre_battle_pos
		print("[CombatController] Restored player %d to pre-battle position: %s" % [peer_id, pre_battle_pos])

	# Clean up combat instance
	npc_combat_instances.erase(combat_id)

	var result = "VICTORY" if victory else "DEFEAT"
	_log_message("[CombatController] Combat %d ended - %s - Player %d" % [combat_id, result, peer_id])


## ========== UTILITY FUNCTIONS ==========

func load_npc_character_file(file_path: String) -> Dictionary:
	## Load NPC character data from JSON file
	if not FileAccess.file_exists(file_path):
		print("[CombatController] ERROR: NPC file not found: %s" % file_path)
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[CombatController] ERROR: Could not open NPC file: %s" % file_path)
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		print("[CombatController] ERROR: Failed to parse NPC JSON: %s" % file_path)
		return {}

	return json.data


func _log_message(message: String) -> void:
	## Log message to server console
	if server_world and server_world.has_method("log_message"):
		server_world.log_message(message)
	else:
		print(message)


func _find_combat_id(combat: Dictionary) -> int:
	## Find combat_id from combat instance
	for id in npc_combat_instances.keys():
		if npc_combat_instances[id] == combat:
			return id
	return -1
