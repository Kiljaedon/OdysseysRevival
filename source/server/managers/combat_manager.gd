extends Node
## Combat Manager - Orchestrates server-authoritative battles
## Delegates to specialized components for turn order, actions, and round execution
## Refactored to ~400 lines from 1720 lines (77% reduction)

class_name CombatManager

## ========== CONSTANTS ==========
const SELECTION_PHASE_TIMEOUT_MS: int = 5600

## ========== COMPONENTS ==========
var battle_calculator: ServerBattleCalculator
var combat_round_executor: CombatRoundExecutor
var combat_action_processor: CombatActionProcessor

## ========== DEPENDENCIES ==========
var server_world = null
var player_manager = null
var npc_manager = null
var network_handler = null

## ========== COMBAT STATE ==========
var npc_combat_instances: Dictionary = {}  # combat_id -> combat session data
var action_timers: Dictionary = {}  # combat_id -> timestamp for timeout

## ========== LIFECYCLE ==========

func _ready():
	battle_calculator = ServerBattleCalculator.new()

	# Initialize components
	combat_round_executor = CombatRoundExecutor.new()
	add_child(combat_round_executor)

	combat_action_processor = CombatActionProcessor.new()
	add_child(combat_action_processor)

	print("[COMBAT] CombatManager ready")

func initialize(p_server_world, p_player_manager, p_npc_manager) -> void:
	server_world = p_server_world
	player_manager = p_player_manager
	npc_manager = p_npc_manager

	# Get network handler from server_world
	if server_world and server_world.has_method("get_network_handler"):
		network_handler = server_world.get_network_handler()

	# Initialize sub-components
	combat_round_executor.initialize(self, network_handler, battle_calculator)
	combat_action_processor.initialize(self, server_world, network_handler, player_manager, battle_calculator)

	print("[COMBAT] Initialized with manager references")

## ========== COMBAT SESSION MANAGEMENT ==========

func has_combat_instance(combat_id: int) -> bool:
	return npc_combat_instances.has(combat_id)

func get_combat_instance(combat_id: int) -> Dictionary:
	return npc_combat_instances.get(combat_id, {})

func create_combat_instance(combat_id: int, data: Dictionary) -> void:
	npc_combat_instances[combat_id] = data
	print("[COMBAT] Combat instance %d created" % combat_id)

func remove_combat_instance(combat_id: int) -> void:
	if npc_combat_instances.has(combat_id):
		npc_combat_instances.erase(combat_id)
		action_timers.erase(combat_id)
		print("[COMBAT] Combat instance %d removed" % combat_id)

## ========== TURN ORDER CALCULATION (with First Strike) ==========

func calculate_turn_order(combat: Dictionary) -> Array:
	"""Calculate turn order with first strike system"""
	print("\n=== TURN ORDER CALCULATION ===")
	combat["turn_order"] = []

	var ally_squad = combat.get("ally_squad", [])
	var enemy_squad = combat.get("enemy_squad", [])

	if ally_squad.is_empty() or enemy_squad.is_empty():
		print("ERROR: Empty squad(s)!")
		return []

	# Build all combatants list
	var all_units: Array = []

	for i in range(ally_squad.size()):
		var ally = ally_squad[i]
		var dex = _get_unit_dex(ally)
		all_units.append({
			"type": "ally",
			"data": ally,
			"dex": dex,
			"is_ally": true,
			"squad_index": i,
			"name": ally.get("character_name", "Ally")
		})

	for i in range(enemy_squad.size()):
		var enemy = enemy_squad[i]
		var dex = _get_unit_dex(enemy)
		all_units.append({
			"type": "enemy",
			"data": enemy,
			"dex": dex,
			"is_ally": false,
			"squad_index": i,
			"name": enemy.get("character_name", "Enemy")
		})

	# First strike logic
	var first_striker = null
	var remaining_units: Array = []
	var player_initiated = combat.get("player_initiated", false)

	if player_initiated:
		first_striker = _find_fastest(all_units, true)
		if first_striker:
			print("FIRST STRIKE: %s (ally)" % first_striker.name)
	else:
		first_striker = _find_fastest(all_units, false)
		if first_striker:
			print("AMBUSH: %s (enemy)" % first_striker.name)

	for unit in all_units:
		if unit != first_striker:
			remaining_units.append(unit)

	remaining_units.sort_custom(_sort_by_dex)

	if first_striker:
		combat["turn_order"].append(first_striker)
	combat["turn_order"].append_array(remaining_units)

	print("Turn order: %d units" % combat["turn_order"].size())
	return combat["turn_order"]

func _get_unit_dex(unit: Dictionary) -> int:
	if unit.has("base_stats") and unit.base_stats.has("dex"):
		return unit.base_stats.dex
	return 10

func _find_fastest(units: Array, find_ally: bool) -> Dictionary:
	var fastest = null
	var best_dex = -1
	for unit in units:
		if unit.is_ally == find_ally and unit.dex > best_dex:
			fastest = unit
			best_dex = unit.dex
	return fastest if fastest else {}

func _sort_by_dex(a: Dictionary, b: Dictionary) -> bool:
	if a.dex != b.dex:
		return a.dex > b.dex
	if a.is_ally != b.is_ally:
		return a.is_ally
	return a.squad_index < b.squad_index

## ========== SELECTION TIMER ==========

func start_selection_phase(combat: Dictionary):
	var combat_id = _find_combat_id(combat)
	if combat_id >= 0:
		combat["selection_phase_start_time"] = Time.get_ticks_msec()
		combat["player_has_acted"] = false
		action_timers[combat_id] = Time.get_ticks_msec() / 1000.0
		print("[COMBAT] Selection phase started for combat %d" % combat_id)

func check_selection_timeout(combat: Dictionary) -> bool:
	if combat.get("player_has_acted", false):
		return false
	var start = combat.get("selection_phase_start_time", -1)
	if start < 0:
		return false
	return (Time.get_ticks_msec() - start) >= SELECTION_PHASE_TIMEOUT_MS

func _find_combat_id(combat: Dictionary) -> int:
	for id in npc_combat_instances.keys():
		if npc_combat_instances[id] == combat:
			return id
	return -1

## ========== BATTLE END DETECTION ==========

func check_battle_end(combat: Dictionary) -> Dictionary:
	var ally_squad = combat.get("ally_squad", [])
	var enemy_squad = combat.get("enemy_squad", [])

	var alive_allies = 0
	var alive_enemies = 0

	for ally in ally_squad:
		if ally.get("hp", 0) > 0:
			alive_allies += 1

	for enemy in enemy_squad:
		if enemy.get("hp", 0) > 0:
			alive_enemies += 1

	var player_defeated = ally_squad.size() > 0 and ally_squad[0].get("hp", 0) <= 0

	if alive_enemies == 0:
		return {"battle_ended": true, "victor": "player", "reason": "all_enemies_defeated"}
	if player_defeated or alive_allies == 0:
		return {"battle_ended": true, "victor": "enemy", "reason": "player_defeated"}

	return {"battle_ended": false, "victor": "", "reason": ""}

## ========== REWARD CALCULATION ==========

func calculate_rewards(combat: Dictionary) -> Dictionary:
	var enemy_squad = combat.get("enemy_squad", [])
	var base_xp = 0
	var base_gold = 0

	for enemy in enemy_squad:
		# Get base rewards from Loot Table (default to standard if missing)
		var loot = enemy.get("loot_table", {})
		var xp_val = loot.get("xp_reward", 50)
		var gold_val = loot.get("gold_reward", 10)
		
		# Scale by Level (Level 1 = 100%, Level 5 = 140%)
		var level = enemy.get("level", 1)
		var level_scale = 1.0 + ((level - 1) * 0.1)
		
		base_xp += int(xp_val * level_scale)
		base_gold += int(gold_val * level_scale)

	var bonus_xp = 0
	var bonus_gold = 0
	var bonuses = []

	# First strike bonus
	if combat.get("player_initiated", false):
		bonus_xp += int(base_xp * 0.1)
		bonus_gold += int(base_gold * 0.05)
		bonuses.append("first_strike")

	# Perfect victory bonus
	var all_alive = true
	for ally in combat.get("ally_squad", []):
		if ally.get("hp", 0) <= 0:
			all_alive = false
			break
	if all_alive:
		bonus_xp += int(base_xp * 0.2)
		bonuses.append("perfect_victory")

	# Quick victory bonus
	if combat.get("round_number", 1) <= 3:
		bonus_gold += int(base_gold * 0.15)
		bonuses.append("quick_victory")

	return {
		"xp_gained": base_xp,
		"gold_gained": base_gold,
		"bonus_xp": bonus_xp,
		"bonus_gold": bonus_gold,
		"total_xp": base_xp + bonus_xp,
		"total_gold": base_gold + bonus_gold,
		"bonuses_applied": bonuses,
		"items_dropped": []
	}

## ========== COMBAT INITIATION ==========

func handle_npc_attack_request(peer_id: int, npc_id: int) -> void:
	print("[COMBAT] NPC attack request: peer=%d, npc=%d" % [peer_id, npc_id])

	var player_data = _get_player_data(peer_id)
	if player_data.is_empty():
		print("[COMBAT] ERROR: Player data not found")
		return

	if not npc_manager or not npc_manager.server_npcs.has(npc_id):
		print("[COMBAT] ERROR: NPC %d not found" % npc_id)
		return

	var npc_info = npc_manager.server_npcs[npc_id]
	var npc_type = npc_info.get("npc_type", "Goblin")

	# Build squads
	var enemy_squad = EnemySquadBuilder.build_enemy_squad(npc_type, npc_id)
	var player_unit = _build_player_combat_unit(player_data, peer_id)

	# Create combat session
	var combat_id = (Time.get_ticks_msec() % 65535) + 1
	var combat = {
		"combat_id": combat_id,
		"peer_id": peer_id,
		"player_id": peer_id,
		"player_character": player_unit,
		"ally_squad": [player_unit],
		"enemy_squad": enemy_squad,
		"turn_order": [],
		"current_turn_index": 0,
		"round_number": 1,
		"player_initiated": true,
		"player_has_acted": false,
		"state": "active",
		"queued_actions": {}
	}

	calculate_turn_order(combat)
	npc_combat_instances[combat_id] = combat
	start_selection_phase(combat)

	# Notify client
	_send_combat_start(peer_id, combat_id, npc_id, enemy_squad)
	print("[COMBAT] Combat %d started" % combat_id)

func _get_player_data(peer_id: int) -> Dictionary:
	if player_manager and player_manager.has_method("get_player_data"):
		return player_manager.get_player_data(peer_id)
	return {}

func _build_player_combat_unit(player_data: Dictionary, peer_id: int) -> Dictionary:
	var character = player_data.get("character", {})
	return {
		"hp": character.get("current_hp", character.get("max_hp", 100)),
		"max_hp": character.get("max_hp", 100),
		"character_name": player_data.get("character_name", "Player"),
		"level": player_data.get("level", 1),
		"base_stats": character.get("stats", {"dex": 10, "str": 10, "int": 10}),
		"is_player": true,
		"peer_id": peer_id
	}

func _send_combat_start(peer_id: int, combat_id: int, npc_id: int, enemy_squad: Array) -> void:
	var packet = PacketEncoder.build_combat_start_packet(combat_id, npc_id, enemy_squad)
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if server_conn:
		server_conn.send_binary_combat_start(peer_id, packet)

## ========== PLAYER ACTION HANDLING ==========

func receive_player_battle_action(peer_id: int, combat_id: int, action_type: String, target_id: int) -> void:
	"""Main entry point for player actions - delegates to CombatActionProcessor"""
	print("[COMBAT] Action received: peer=%d, combat=%d, action=%s, target=%d" % [peer_id, combat_id, action_type, target_id])
	combat_action_processor.receive_player_battle_action(peer_id, combat_id, action_type, target_id)

func handle_battle_end(peer_id: int, combat_id: int, victory: bool) -> void:
	print("[COMBAT] Battle end: combat=%d, victory=%s" % [combat_id, victory])
	if has_combat_instance(combat_id):
		var combat = get_combat_instance(combat_id)
		if combat.get("peer_id", -1) == peer_id:
			remove_combat_instance(combat_id)

## ========== UTILITY ==========

func get_alive_enemies(combat: Dictionary) -> Array:
	var alive = []
	for enemy in combat.get("enemy_squad", []):
		if enemy.get("hp", 0) > 0:
			alive.append(enemy)
	return alive

func get_alive_allies(combat: Dictionary) -> Array:
	var alive = []
	for ally in combat.get("ally_squad", []):
		if ally.get("hp", 0) > 0:
			alive.append(ally)
	return alive
