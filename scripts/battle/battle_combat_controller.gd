class_name BattleCombatController
extends Node
## Battle Combat Controller - Manages combat flow, turn order, and battle state
## Extracted from battle_window.gd for modularity

# Signals for UI/Animation coordination
signal selection_phase_started(round: int)
signal turn_started(unit_type: String, unit_data: Dictionary, unit_index: int)
signal action_queued(action: String, target_id: int)
signal round_executing()
signal battle_ended(victory: bool)
signal turn_order_calculated(turn_list: Array)

# Battle state machine
enum BattleState { SELECTION_PHASE, TARGET_SELECTION, WAITING_FOR_ROUND, EXECUTING_ROUND }
var battle_state: int = BattleState.SELECTION_PHASE

# Squad data
var enemy_squad: Array = []
var ally_squad: Array = []
var player_character: Dictionary = {}

# Turn order system
var turn_order: Array = []
var current_turn_index: int = 0
var round_number: int = 1

# Player action queue
var player_queued_action: Dictionary = {
	"action": "",      # "attack", "defend", "skill", "item"
	"target_id": -1,   # Index of target (-1 = no target)
	"confirmed": false
}

# Selection phase timer
var selection_phase_timer: float = 8.0
const SELECTION_PHASE_DURATION: float = 8.0

# First strike system
var player_initiated: bool = true

# Server battle flag
var is_server_battle: bool = false
var combat_id: int = -1

# Pause state
var is_paused: bool = false

## ========== INITIALIZATION ==========

func initialize_battle(enemies: Array, allies: Array, player: Dictionary, server_battle: bool = false, battle_combat_id: int = -1):
	"""Initialize battle with squads"""
	enemy_squad = enemies
	ally_squad = allies
	player_character = player
	is_server_battle = server_battle
	combat_id = battle_combat_id

	round_number = 1
	current_turn_index = -1
	battle_state = BattleState.SELECTION_PHASE

	print("✓ Battle initialized: %d enemies vs %d allies (server=%s)" % [enemy_squad.size(), ally_squad.size(), is_server_battle])

func set_battle_initiator(player_attacked_first: bool):
	"""Set who initiated combat (affects first strike)"""
	player_initiated = player_attacked_first
	if player_attacked_first:
		print("🗡️ Player initiated combat - your fastest ally gets first strike!")
	else:
		print("👹 Enemy ambush - their fastest unit gets first strike!")

## ========== TURN ORDER CALCULATION ==========

func calculate_turn_order():
	"""Calculate turn order based on DEX stat with first strike system"""
	turn_order.clear()

	# Build list of all combatants
	var all_units: Array = []
	var unit_id_counter: int = 0

	# Add player
	var player_dex = 10
	if player_character.has("base_stats") and player_character.base_stats.has("dex"):
		player_dex = player_character.base_stats.dex
	all_units.append({"type": "player", "data": player_character, "dex": player_dex, "is_ally": true, "unit_id": unit_id_counter})
	unit_id_counter += 1

	# Add allies
	for ally in ally_squad:
		if ally != player_character:  # Don't add player twice
			var ally_dex = 10
			if ally.has("base_stats") and ally.base_stats.has("dex"):
				ally_dex = ally.base_stats.dex
			all_units.append({"type": "ally", "data": ally, "dex": ally_dex, "is_ally": true, "unit_id": unit_id_counter})
			unit_id_counter += 1

	# Add enemies
	for enemy in enemy_squad:
		var enemy_dex = 10
		if enemy.has("base_stats") and enemy.base_stats.has("dex"):
			enemy_dex = enemy.base_stats.dex
		all_units.append({"type": "enemy", "data": enemy, "dex": enemy_dex, "is_ally": false, "unit_id": unit_id_counter})
		unit_id_counter += 1

	# FIRST STRIKE SYSTEM
	var first_striker = null
	var remaining_units: Array = []

	if player_initiated:
		# Player attacked first - fastest ALLY goes first
		var fastest_ally = null
		var fastest_dex = -1
		for unit in all_units:
			if unit.is_ally:
				# Use unit_id as tiebreaker when DEX is equal
				if unit.dex > fastest_dex or (unit.dex == fastest_dex and (fastest_ally == null or unit.unit_id < fastest_ally.unit_id)):
					fastest_ally = unit
					fastest_dex = unit.dex

		if fastest_ally:
			first_striker = fastest_ally
			print("⚔️ FIRST STRIKE: %s attacks first! (Player initiated)" % fastest_ally.data.get("character_name", "Ally"))

		# Add remaining units
		for unit in all_units:
			if unit != first_striker:
				remaining_units.append(unit)
	else:
		# Enemy ambushed - fastest ENEMY goes first
		var fastest_enemy = null
		var fastest_dex = -1
		for unit in all_units:
			if not unit.is_ally:
				# Use unit_id as tiebreaker when DEX is equal
				if unit.dex > fastest_dex or (unit.dex == fastest_dex and (fastest_enemy == null or unit.unit_id < fastest_enemy.unit_id)):
					fastest_enemy = unit
					fastest_dex = unit.dex

		if fastest_enemy:
			first_striker = fastest_enemy
			print("💀 AMBUSH: %s attacks first! (Enemy initiated)" % fastest_enemy.data.get("character_name", "Enemy"))

		# Add remaining units
		for unit in all_units:
			if unit != first_striker:
				remaining_units.append(unit)

	# Sort remaining units by DEX (with unit_id as tiebreaker for deterministic ordering)
	remaining_units.sort_custom(func(a, b):
		if a.dex == b.dex:
			return a.unit_id < b.unit_id  # Tiebreaker: lower unit_id goes first
		return a.dex > b.dex
	)

	# Build final turn order: first striker + sorted remaining
	if first_striker:
		turn_order.append(first_striker)
	turn_order.append_array(remaining_units)

	print("Turn order calculated:")
	for i in range(turn_order.size()):
		var unit = turn_order[i]
		var prefix = "  "
		if i == 0 and first_striker:
			prefix = "⚡ "  # First strike marker
		print(prefix, unit.data.get("character_name", "Unknown"), " (DEX: ", unit.dex, ")")

	turn_order_calculated.emit(turn_order)

## ========== SELECTION PHASE ==========

func start_selection_phase():
	"""Start selection phase - give player 8 seconds to choose their action"""
	print("=== Selection Phase Started - Round #%d ===" % round_number)

	# CRITICAL: Prevent any turns from executing during selection
	current_turn_index = -1

	# Reset player action queue for this round
	player_queued_action = {
		"action": "",
		"target_id": -1,
		"confirmed": false
	}

	# Start 8-second selection timer
	battle_state = BattleState.SELECTION_PHASE
	selection_phase_timer = SELECTION_PHASE_DURATION

	selection_phase_started.emit(round_number)

func process_selection_phase(delta: float):
	"""Process selection phase timer (call from _process)"""
	if battle_state != BattleState.SELECTION_PHASE and battle_state != BattleState.TARGET_SELECTION:
		return

	selection_phase_timer -= delta

	# When selection timer expires, execute round
	if selection_phase_timer <= 0:
		# Only auto-defend if player hasn't confirmed an action yet
		if not player_queued_action.get("confirmed", false):
			print("⏱️ Selection timer expired - auto-defending")
			player_queued_action = {
				"action": "defend",
				"target_id": -1,
				"confirmed": true
			}
		else:
			print("⏱️ Selection timer expired - executing player's queued action: %s" % player_queued_action["action"])

		# Stop timer and start executing all 12 turns in DEX order
		selection_phase_timer = 0.0
		start_round_execution()

func enter_target_selection():
	"""Enter target selection state (when Attack is pressed)"""
	battle_state = BattleState.TARGET_SELECTION
	print("🎯 Entering TARGET_SELECTION state")

func cancel_target_selection():
	"""Cancel target selection and return to SELECTION_PHASE"""
	battle_state = BattleState.SELECTION_PHASE
	print("❌ Cancelled target selection - returning to SELECTION_PHASE")

func queue_player_action(action: String, target_id: int = -1):
	"""Queue player's selected action"""
	player_queued_action = {
		"action": action,
		"target_id": target_id,
		"confirmed": true
	}

	print("✅ Action queued: %s (target: %d)" % [action, target_id])
	action_queued.emit(action, target_id)

	# Immediately start round execution
	selection_phase_timer = 0.0
	start_round_execution()

func start_round_execution():
	"""Start executing all turns in DEX order"""
	battle_state = BattleState.EXECUTING_ROUND
	current_turn_index = 0

	print("=== Round %d - Executing All Turns ===" % round_number)
	round_executing.emit()

	# Start first turn
	start_next_turn()

## ========== TURN EXECUTION ==========

func start_next_turn():
	"""Start the next unit's turn"""
	# Don't start turns if paused
	if is_paused:
		return

	# CRITICAL: Don't start turns during selection phase
	if battle_state == BattleState.SELECTION_PHASE or battle_state == BattleState.TARGET_SELECTION:
		print("⚠️ start_next_turn() blocked - currently in selection phase")
		return

	if current_turn_index < 0:
		print("⚠️ start_next_turn() blocked - current_turn_index is negative")
		return

	if current_turn_index >= turn_order.size():
		# Round complete - start new selection phase
		current_turn_index = 0
		round_number += 1
		print("=== Round %d Complete - Starting New Selection Phase ===" % (round_number - 1))
		start_selection_phase()
		return

	var current_unit = turn_order[current_turn_index]

	# Emit signal so UI/animations can respond
	turn_started.emit(current_unit.type, current_unit.data, current_turn_index)

func advance_turn():
	"""Advance to next turn (call this after current turn completes)"""
	current_turn_index += 1
	start_next_turn()

func get_current_turn_unit() -> Dictionary:
	"""Get the unit whose turn it currently is"""
	if current_turn_index >= 0 and current_turn_index < turn_order.size():
		return turn_order[current_turn_index]
	return {}

## ========== BATTLE END CHECKING ==========

func check_battle_end() -> Dictionary:
	"""Check if battle has ended. Returns {ended: bool, victory: bool}
	Battle ends when:
	- Player character (ally_squad[0]) dies → DEFEAT
	- Enemy squad leader (enemy_squad[0]) dies → VICTORY
	"""

	# Check if player character is dead (first ally is always the player)
	if ally_squad.size() > 0:
		var player_hp = ally_squad[0].get("hp", 0)
		if player_hp <= 0:
			print("💀 Player character defeated - DEFEAT!")
			battle_ended.emit(false)
			return {"ended": true, "victory": false}

	# Check if enemy squad leader is dead (first enemy is the one attacked on map)
	if enemy_squad.size() > 0:
		var leader_hp = enemy_squad[0].get("hp", 0)
		if leader_hp <= 0:
			print("🎉 Enemy squad leader defeated - VICTORY!")
			battle_ended.emit(true)
			return {"ended": true, "victory": true}

	return {"ended": false, "victory": false}

## ========== PAUSE CONTROL ==========

func toggle_pause():
	"""Toggle battle pause state"""
	is_paused = !is_paused
	print("⏸️ Battle paused" if is_paused else "▶️ Battle resumed")

func pause():
	"""Pause battle"""
	is_paused = true

func resume():
	"""Resume battle"""
	is_paused = false

## ========== GETTERS ==========

func get_battle_state() -> int:
	return battle_state

func get_selection_timer() -> float:
	return selection_phase_timer

func get_player_queued_action() -> Dictionary:
	return player_queued_action

func get_round_number() -> int:
	return round_number

func is_player_turn_active() -> bool:
	if current_turn_index >= 0 and current_turn_index < turn_order.size():
		return turn_order[current_turn_index].type == "player"
	return false

func get_enemy_squad() -> Array:
	"""Get reference to enemy squad array"""
	return enemy_squad

func get_ally_squad() -> Array:
	"""Get reference to ally squad array"""
	return ally_squad
