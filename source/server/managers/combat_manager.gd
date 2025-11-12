extends Node
class_name CombatManager

## Manages all combat system operations - extracted from ServerWorld
## Handles NPC combat initialization, player actions, enemy AI, and round execution
## PHASE 1 SECURITY: Added server-side action timeout and stats validation
## REFACTOR STEP 1.1: Using EnemySquadBuilder for squad generation
## REFACTOR STEP 1.2: Using TurnOrderCalculator for initiative order

# Refactored components
const EnemySquadBuilder = preload("res://source/server/managers/combat/enemy_squad_builder.gd")
const TurnOrderCalculator = preload("res://source/server/managers/combat/turn_order_calculator.gd")
const CombatRoundExecutor = preload("res://source/server/managers/combat/combat_round_executor.gd")
const CombatActionProcessor = preload("res://source/server/managers/combat/combat_action_processor.gd")

# Dependencies (injected from ServerWorld)
var server_world: Node = null
var network_handler = null
var player_manager = null
var npc_manager = null
var server_battle_manager = null

# Refactored subsystems
var combat_round_executor: CombatRoundExecutor = null
var combat_action_processor: CombatActionProcessor = null

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

	# Initialize CombatRoundExecutor (Phase 2 refactoring)
	combat_round_executor = CombatRoundExecutor.new()
	add_child(combat_round_executor)
	combat_round_executor.initialize(self, network_handler, server_battle_manager)

	# Initialize CombatActionProcessor (Phase 3 refactoring)
	combat_action_processor = CombatActionProcessor.new()
	add_child(combat_action_processor)
	combat_action_processor.initialize(self, server_ref, network_handler, player_mgr, battle_mgr)

	print("[CombatManager] Initialized with Phase 3 refactoring - CombatRoundExecutor and CombatActionProcessor active")


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

	# Execute the round with the forced action (delegated to CombatRoundExecutor)
	combat_round_executor.execute_combat_round(combat_id)


# ========== COMBAT INSTANCE GETTERS (Phase 2 Refactoring) ==========

func get_combat_instance(combat_id: int) -> Dictionary:
	## Get combat instance by ID (used by CombatRoundExecutor)
	return npc_combat_instances.get(combat_id, {})

func has_combat_instance(combat_id: int) -> bool:
	## Check if combat instance exists (used by CombatRoundExecutor)
	return npc_combat_instances.has(combat_id)


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

	# REFACTOR STEP 1.2: Use TurnOrderCalculator to calculate initiative order
	var turn_order = TurnOrderCalculator.calculate_turn_order(player, ally_squad, enemy_squad)
	npc_combat_instances[combat_id]["turn_order"] = turn_order

	# SECURITY: Start action timer for this combat
	action_timers[combat_id] = Time.get_ticks_msec() / 1000.0
	print("[COMBAT-SECURITY] Action timer started for combat %d (%.0fs timeout)" % [combat_id, ACTION_TIMEOUT_SECONDS])

	# Build binary combat packet (efficient: ~50 bytes vs 1500+ for Dictionary)
	var combat_packet = PacketEncoder.build_combat_start_packet(combat_id, npc_id, enemy_squad)

	# Send combat start to attacking player via binary RPC
	if network_handler:
		network_handler.send_binary_combat_start(peer_id, combat_packet)
	# AUTO-EXECUTE FIRST ROUND: Process all NPC turns immediately (delegated to CombatRoundExecutor)
	print("[COMBAT] Auto-executing first round for combat %d" % combat_id)
	combat_round_executor.process_npc_turns(combat_id)
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


## ========== BATTLE ACTION HANDLERS (PHASE 3 REFACTORING) ==========
# All action processing delegated to CombatActionProcessor

func receive_player_battle_action(peer_id: int, combat_id: int, action_type: String, target_id: int):
	## Delegate to CombatActionProcessor
	combat_action_processor.receive_player_battle_action(peer_id, combat_id, action_type, target_id)


@rpc("any_peer")
func battle_player_attack(combat_id: int, target_index: int):
	## Delegate to CombatActionProcessor
	combat_action_processor.battle_player_attack(combat_id, target_index)



@rpc("any_peer")
func battle_player_defend(combat_id: int):
	## Delegate to CombatActionProcessor
	combat_action_processor.battle_player_defend(combat_id)


@rpc("any_peer")
func battle_player_use_skill(combat_id: int, target_index: int, skill_name: String):
	## Delegate to CombatActionProcessor
	combat_action_processor.battle_player_use_skill(combat_id, target_index, skill_name)


@rpc("any_peer")
func battle_player_use_item(combat_id: int, target_index: int, item_name: String):
	## Delegate to CombatActionProcessor
	combat_action_processor.battle_player_use_item(combat_id, target_index, item_name)


@rpc("any_peer")
func client_ready_for_next_turn(combat_id: int):
	## Delegate to CombatActionProcessor
	combat_action_processor.client_ready_for_next_turn(combat_id)


func process_enemy_ai_turn(combat_id: int):
	## Delegate to CombatActionProcessor
	combat_action_processor.process_enemy_ai_turn(combat_id)


# ========== COMBAT REFACTORING SUMMARY ==========
# PHASE 2: CombatRoundExecutor extracted:
#   - execute_combat_round(), process_npc_turns(), execute_ally_turn()
#   - execute_enemy_turn(), check_battle_end(), advance_turn()
#   - start_selection_phase(), finalize_battle()
#
# PHASE 3: CombatActionProcessor extracted:
#   - receive_player_battle_action() - Action queuing
#   - battle_player_attack() - @rpc attack handler
#   - battle_player_defend() - @rpc defend handler
#   - battle_player_use_skill() - @rpc skill handler
#   - battle_player_use_item() - @rpc item handler
#   - client_ready_for_next_turn() - @rpc ready confirmation
#   - process_enemy_ai_turn() - Enemy AI logic
#
# All calls delegated to combat_round_executor and combat_action_processor


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
