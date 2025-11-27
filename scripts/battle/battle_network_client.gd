class_name BattleNetworkClient
extends Node
## Battle Network Client - Handles server communication for battles
## Extracted from battle_window.gd for modularity
## Now fully server-authoritative - all damage calculations on server

# Signals for server communication
signal server_result_received(results: Dictionary)
signal action_result_received(results: Dictionary)
signal server_error(error_message: String)
signal connection_lost()

# Server battle state
var is_server_battle: bool = false
var combat_id: int = -1

# References
var server_connection: Node = null
var world_client: Node = null

# Last action result (for async await)
var last_action_result: Dictionary = {}

# FIX 14: Dedicated player action result that won't be overwritten by enemy/NPC results
# Player results have "action" but no "actor_type" field (enemy results have actor_type="enemy")
var player_action_result: Dictionary = {}

## ========== INITIALIZATION ==========

func initialize_server_battle(battle_combat_id: int):
	"""Initialize server battle with combat ID"""
	is_server_battle = true
	combat_id = battle_combat_id

	# Find ServerConnection node
	server_connection = get_tree().root.get_node_or_null("ServerConnection")
	if server_connection:
		# FIX 12: Register THIS instance with ServerConnection so RPC uses the SAME instance
		# that battle_window_v2.network_client is waiting on for action_result_received signal
		server_connection.set_meta("active_battle_network_client", self)

	# Find WorldClient node (backup)
	world_client = get_tree().root.find_child("WorldClient", true, false)

func initialize_local_battle():
	"""Initialize local (non-server) battle"""
	is_server_battle = false
	combat_id = -1
	server_connection = null
	world_client = null

## ========== SERVER COMBAT DATA ==========

static func load_server_combat_data() -> Dictionary:
	"""Load server combat data from GameState meta (called from battle_window setup)"""
	var game_state = null

	# Try to find GameState node
	var root = Engine.get_main_loop().root
	if root:
		game_state = root.get_node_or_null("GameState")

	if not game_state:
		return {}

	# Check for server battle meta
	if not game_state.has_meta("in_server_battle"):
		return {}

	if not game_state.get_meta("in_server_battle"):
		return {}

	# Get server combat data
	if not game_state.has_meta("server_combat_data"):
		return {}

	var server_data = game_state.get_meta("server_combat_data")
	if server_data.is_empty():
		return {}

	return server_data

## ========== SENDING ACTIONS TO SERVER ==========

func send_player_action(action: String, target_id: int):
	"""Send player action to server for authoritative processing"""
	if not is_server_battle:
		return

	if combat_id == -1:
		server_error.emit("Invalid combat ID")
		return

	# Try ServerConnection first (preferred)
	if server_connection:
		server_connection.handle_player_action.rpc_id(1, combat_id, action, target_id)
		return

	# Fallback to WorldClient
	if world_client:
		world_client.handle_player_action.rpc_id(1, combat_id, action, target_id)
		return

	# No connection available
	server_error.emit("No server connection available")
	connection_lost.emit()

@rpc("authority", "call_remote", "reliable")
func receive_action_result(result: Dictionary):
	"""
	Receive authoritative action result from server
	Emits signal so client can update UI/state
	"""
	# Store result for await
	last_action_result = result

	# FIX 14: Store player results separately (won't be overwritten by enemy results)
	# Player results have "action" field but NOT "actor_type" field
	# Enemy results have "actor_type": "enemy"
	# System messages have "type" field (new_round, battle_end)
	if result.has("action") and not result.has("actor_type") and not result.has("type"):
		player_action_result = result

	# Emit signals
	action_result_received.emit(result)
	server_result_received.emit(result)

## ========== RECEIVING SERVER RESULTS ==========

func receive_round_results(results: Dictionary):
	"""Process combat round results from server"""
	# Check for errors
	var error = results.get("error", "")
	if error != "":
		server_error.emit(error)
		return

	# Validate result data
	if not results.has("action"):
		server_error.emit("Invalid server response")
		return

	# Emit signal for battle controller to process
	server_result_received.emit(results)

## ========== BATTLE END ==========

func send_battle_end(victory: bool):
	"""Notify server that battle has ended"""
	if not is_server_battle:
		return

	if server_connection:
		server_connection.send_battle_end.rpc(combat_id, victory)
	elif world_client:
		world_client.send_battle_end.rpc(combat_id, victory)

## ========== UTILITY ==========

func has_server_connection() -> bool:
	"""Check if connected to server"""
	return server_connection != null or world_client != null

func get_combat_id() -> int:
	"""Get current combat ID"""
	return combat_id

func is_server_controlled() -> bool:
	"""Check if this is a server-controlled battle"""
	return is_server_battle
