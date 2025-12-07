## Golden Sun MMO - Connection Manager
## Handles player connection lifecycle: authentication, connection, disconnection
## Separated from ServerWorld for modularity - Phase 5 of refactoring

extends Node
class_name ConnectionManager

# ========== DEPENDENCIES ==========
var server_world: Node = null
var server = null  # BaseServer reference
var network_handler = null
var auth_manager = null
var player_manager = null
var spatial_manager = null
var anti_cheat = null
var network_manager = null
var admin_ui = null
var debug_console = null


func _ready():
	pass


## Called by ServerWorld to set dependencies
func initialize(server_ref, server_instance, net_handler, auth_mgr, player_mgr, spatial_mgr, anti_cheat_sys, network_mgr, admin_ui_ref, debug_console_ref):
	server_world = server_ref
	server = server_instance
	network_handler = net_handler
	auth_manager = auth_mgr
	player_manager = player_mgr
	spatial_manager = spatial_mgr
	anti_cheat = anti_cheat_sys
	network_manager = network_mgr
	admin_ui = admin_ui_ref
	debug_console = debug_console_ref

	print("[ConnectionManager] Initialized")


# ========== AUTHENTICATION CALLBACK ==========

func handle_authentication_callback(peer_id: int, data: PackedByteArray):
	"""Handle authentication handshake - accept guest connections"""
	var auth_string = data.get_string_from_utf8()
	print("[AUTH] Peer %d authenticating with token: %s" % [peer_id, auth_string])

	if debug_console:
		debug_console.add_log("Auth handshake from peer %d" % peer_id, "cyan")

	# Accept all guest connections - actual login happens via RPC
	server.multiplayer_api.send_auth(peer_id, "ACCEPTED".to_utf8_buffer())
	server.multiplayer_api.complete_auth(peer_id)

	log_message("[AUTH] Peer %d authenticated as guest - awaiting login RPC" % peer_id)


# ========== PLAYER CONNECTED ==========

func handle_player_connected(peer_id: int):
	"""Handle new player connection (authenticated but not logged in)"""
	log_message("[CONNECT] Peer %d connected and authenticated - awaiting login" % peer_id)

	# Register with anti-cheat system
	if anti_cheat:
		anti_cheat.register_player(peer_id)

	# debug_console disabled - using ui_manager console instead
	if debug_console:
		debug_console.add_log("Peer %d ready for login" % peer_id, "green")
		var player_count = player_manager.connected_players.size() if player_manager else 0
		debug_console.update_stats("SERVER RUNNING - Port 9043 (DEV)", -1, player_count)


# ========== PLAYER DISCONNECTED ==========

func handle_player_disconnected(peer_id: int):
	"""Handle player disconnection - critical path code for data persistence"""

	# Get username from auth manager
	var username = auth_manager.get_username(peer_id) if auth_manager else "Unknown"
	var was_authenticated = auth_manager.is_authenticated(peer_id) if auth_manager else false
	var disconnect_reason = ""

	# Check if they were authenticated or just connected
	if was_authenticated:
		disconnect_reason = "User '%s' logged out" % username
	else:
		disconnect_reason = "Unauthenticated peer disconnected (never logged in)"

	log_message("[DISCONNECT] %s (peer %d) - %s" % [username, peer_id, disconnect_reason])

	# Log to activity panel
	if was_authenticated and player_manager:
		var char_name = player_manager.connected_players.get(peer_id, {}).get("character_name", username)
		log_activity("[color=orange]✗ %s disconnected[/color]" % char_name)

	# CRITICAL: Save character data before cleanup (prevents data loss)
	if player_manager and player_manager.connected_players.has(peer_id):
		save_character_on_disconnect(peer_id, username)

	# Remove player from all tracking dictionaries (AFTER saving)
	cleanup_player_state(peer_id)

	# Update UI and stats
	update_player_count()

	# Update admin panel stats
	if admin_ui:
		admin_ui.update_server_stats()

	# Update debug console with correct player count (after removal)
	if debug_console:
		debug_console.add_log("DISCONNECT: Peer %d" % peer_id, "orange")
		debug_console.add_log("  └─ Reason: %s" % disconnect_reason, "gray")
		if was_authenticated:
			debug_console.add_log("  └─ User: %s" % username, "gray")
		var player_count = player_manager.connected_players.size() if player_manager else 0
		debug_console.update_stats("SERVER RUNNING - Port 9043 (DEV)", -1, player_count)

	# Broadcast player removal to all connected players
	if network_handler and player_manager:
		for other_peer_id in player_manager.connected_players:
			network_handler.send_player_despawned(other_peer_id, peer_id)


# ========== CHARACTER PERSISTENCE ==========

func save_character_on_disconnect(peer_id: int, username: String):
	"""Save character data before disconnecting - prevents data loss"""
	if not player_manager:
		return

	var player_data = player_manager.connected_players[peer_id]
	var character_id = player_data.get("character_id", "")

	if character_id:
		var char_repo = RepositoryFactory.get_character_repository()

		# Build updated character data with current state
		var character_data = player_data.get("character", {})
		if character_data.is_empty():
			# If character dict not stored, attempt to load it
			var char_result = char_repo.get_character(character_id)
			if char_result.success:
				character_data = char_result.character.duplicate()
			else:
				character_data = {}
		else:
			character_data = character_data.duplicate()

		# Update position from current player state
		if player_manager.player_positions.has(peer_id):
			character_data["position"] = player_manager.player_positions[peer_id]

		# Update any other runtime state (HP, MP, inventory, etc. as needed)
		# For now, save what we have

		var save_result = char_repo.save_character(character_id, character_data)
		if save_result:
			log_message("[PERSIST] Saved character %s for %s on disconnect" % [character_id, username])
		else:
			log_message("[PERSIST] WARNING: Failed to save character %s" % character_id)


# ========== CLEANUP ==========

func cleanup_player_state(peer_id: int):
	"""Remove player from all tracking systems"""
	# Remove from player manager
	if player_manager:
		player_manager.connected_players.erase(peer_id)
		player_manager.player_positions.erase(peer_id)

	# Deauthenticate from auth manager
	if auth_manager:
		auth_manager.deauthenticate_peer(peer_id)

	# Unregister from spatial manager
	if spatial_manager:
		spatial_manager.unregister_entity(peer_id)

	# Unregister from anti-cheat
	if anti_cheat:
		anti_cheat.unregister_player(peer_id)

	# Remove from network manager position tracking
	if network_manager:
		network_manager.remove_player_tracking(peer_id)


# ========== UTILITIES ==========

func update_player_count():
	"""Update player count display"""
	if server_world:
		server_world.update_player_count()


func log_message(message: String):
	"""Forward log message to server_world"""
	if server_world:
		server_world.log_message(message)


func log_activity(message: String):
	"""Forward activity log to server_world"""
	if server_world:
		server_world.log_activity(message)
