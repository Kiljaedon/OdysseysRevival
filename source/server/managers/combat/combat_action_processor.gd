extends Node
class_name CombatActionProcessor

## Combat Action Processor - Phase 3 Refactoring
## Handles all player action RPCs and action processing
## CRITICAL: ALL @rpc decorators preserved for network functionality

# Dependencies (injected by CombatManager)
var combat_manager = null  # Reference to parent CombatManager
var server_world = null
var network_handler = null
var player_manager = null
var server_battle_manager = null

func initialize(mgr_ref, world_ref, net_handler, player_mgr, battle_mgr):
	combat_manager = mgr_ref
	server_world = world_ref
	network_handler = net_handler
	player_manager = player_mgr
	server_battle_manager = battle_mgr
	print("[CombatActionProcessor] Initialized with all RPC handlers")


# ========== BATTLE ACTION HANDLERS ==========

func receive_player_battle_action(peer_id: int, combat_id: int, action_type: String, target_id: int):
	## Receive and queue player battle action (called from network_handler RPC)
	print("[COMBAT] Player action received: peer=%d, combat_id=%d, action=%s, target=%d" % [peer_id, combat_id, action_type, target_id])

	if not combat_manager.has_combat_instance(combat_id):
		print("[COMBAT] ERROR: Invalid combat ID %d" % combat_id)
		return

	var combat = combat_manager.get_combat_instance(combat_id)

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
	if combat_manager.action_timers.has(combat_id):
		combat_manager.action_timers.erase(combat_id)
		print("[COMBAT-SECURITY] Action timer cleared for combat %d (action received)" % combat_id)

	# For single-player battles, execute round immediately (delegated to CombatRoundExecutor)
	# TODO: Wait for all players in party or timeout after 8 seconds
	combat_manager.combat_round_executor.execute_combat_round(combat_id)

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

	if not combat_manager.has_combat_instance(combat_id):
		print("[COMBAT] Invalid combat ID: %d from peer %d" % [combat_id, peer_id])
		return

	var combat = combat_manager.get_combat_instance(combat_id)

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
	combat_manager.action_timers[combat_id] = Time.get_ticks_msec() / 1000.0

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

	if not combat_manager.has_combat_instance(combat_id):
		print("[COMBAT] Invalid combat ID: %d from peer %d" % [combat_id, peer_id])
		return

	var combat = combat_manager.get_combat_instance(combat_id)

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
	combat_manager.action_timers[combat_id] = Time.get_ticks_msec() / 1000.0

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

	if not combat_manager.has_combat_instance(combat_id):
		print("[COMBAT] Invalid combat ID: %d from peer %d" % [combat_id, peer_id])
		return

	var combat = combat_manager.get_combat_instance(combat_id)

	# SECURITY: Verify peer owns this combat
	if combat.peer_id != peer_id:
		print("[COMBAT-SECURITY] Peer %d attempted skill in combat %d (owned by peer %d) - REJECTED" % [peer_id, combat_id, combat.peer_id])
		return

	print("[COMBAT] Player skill: Combat %d, Target %d, Skill %s" % [combat_id, target_index, skill_name])
	# Skills not yet implemented - advance turn
	combat.is_player_turn = false
	combat.current_turn_index += 1

	# SECURITY: Restart action timer for next turn
	combat_manager.action_timers[combat_id] = Time.get_ticks_msec() / 1000.0

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

	if not combat_manager.has_combat_instance(combat_id):
		print("[COMBAT] Invalid combat ID: %d from peer %d" % [combat_id, peer_id])
		return

	var combat = combat_manager.get_combat_instance(combat_id)

	# SECURITY: Verify peer owns this combat
	if combat.peer_id != peer_id:
		print("[COMBAT-SECURITY] Peer %d attempted item use in combat %d (owned by peer %d) - REJECTED" % [peer_id, combat_id, combat.peer_id])
		return

	print("[COMBAT] Player item: Combat %d, Target %d, Item %s" % [combat_id, target_index, item_name])
	# Items not yet implemented - advance turn
	combat.is_player_turn = false
	combat.current_turn_index += 1

	# SECURITY: Restart action timer for next turn
	combat_manager.action_timers[combat_id] = Time.get_ticks_msec() / 1000.0

	# Process enemy AI turn
	process_enemy_ai_turn(combat_id)

@rpc("any_peer")
func client_ready_for_next_turn(combat_id: int):
	"""
	Client confirms it's ready for next turn selection phase
	This prevents delays caused by client animations or UI updates
	"""
	var peer_id = multiplayer.get_remote_sender_id()

	if not combat_manager.has_combat_instance(combat_id):
		print("[COMBAT] Invalid combat ID in client_ready: %d from peer %d" % [combat_id, peer_id])
		return

	var combat = combat_manager.get_combat_instance(combat_id)
	
	# SECURITY: Verify peer owns this combat
	if combat.get("peer_id", -1) != peer_id:
		print("[COMBAT-SECURITY] Peer %d attempted ready confirmation for combat %d (owned by peer %d) - REJECTED" % [
			peer_id, combat_id, combat.get("peer_id", -1)
		])
		return
	
	print("[COMBAT] Client ready confirmation received for combat %d from peer %d" % [combat_id, peer_id])

	# Client is ready - start selection phase immediately (delegated to CombatRoundExecutor)
	combat_manager.combat_round_executor.start_selection_phase(combat)



# ========== ENEMY AI TURN ==========

func process_enemy_ai_turn(combat_id: int):
	## Process enemy turn - enemies attack back
	if not combat_manager.has_combat_instance(combat_id):
		return

	var combat = combat_manager.get_combat_instance(combat_id)
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

