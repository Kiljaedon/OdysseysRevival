## Chat Manager - Server-side chat message handling and broadcasting
## Handles all chat message validation, logging, and distribution to connected players
extends Node
class_name ChatManager

# ========== REFERENCES ==========
var server_world  # Reference to main server_world
var player_manager  # Reference to player_manager
var network_handler  # Reference to network_handler
var debug_console  # Reference to debug_console

# ========== INITIALIZATION ==========

func initialize(server_ref):
	"""Initialize chat manager with server references"""
	server_world = server_ref
	player_manager = server_ref.player_manager
	network_handler = server_ref.network_handler
	debug_console = server_ref.debug_console
	print("[ChatManager] Initialized")


# ========== CHAT MESSAGE HANDLING ==========

@rpc("any_peer")
func handle_chat_message(message: String):
	"""
	Receive chat message from client and broadcast to all players

	SERVER-AUTHORITATIVE: All chat messages are validated and logged server-side
	- Validates sender is connected player
	- Logs message to server console and debug console
	- Broadcasts to all connected players via network_handler

	Args:
		message: Chat message text from client
	"""
	var peer_id = multiplayer.get_remote_sender_id()

	# Rate limit check: 5 messages per 10 seconds
	if server_world and server_world.rate_limiter:
		var limit_check = server_world.rate_limiter.check_rate_limit(peer_id, "chat_message", 5, 10.0)
		if not limit_check.allowed:
			print("[CHAT] Rate limit exceeded for peer %d - wait %.1fs" % [peer_id, limit_check.wait_time])
			if network_handler:
				network_handler.send_system_message(peer_id, "You are sending messages too quickly. Please wait.")
			return

	# VALIDATION: Check if sender exists in connected players
	if not player_manager or not player_manager.connected_players.has(peer_id):
		print("[CHAT] ERROR: Player manager not found or peer %d not connected" % peer_id)
		return

	# Get player name for message display
	var player_name = player_manager.connected_players[peer_id].get("character_name", "Unknown")
	print("[CHAT] Received from peer %d (%s): %s" % [peer_id, player_name, message])

	# Log to server console
	if server_world:
		server_world.log_message("[CHAT] %s: %s" % [player_name, message])

	# Log to debug console chat tab
	if debug_console:
		debug_console.add_chat(player_name, message, "all")

	# Broadcast message to all connected players
	broadcast_message(player_name, message)


func broadcast_message(player_name: String, message: String):
	"""
	Broadcast chat message to all connected players

	Args:
		player_name: Name of player who sent the message
		message: Chat message text to broadcast
	"""
	if not network_handler or not player_manager:
		print("[CHAT] ERROR: network_handler or player_manager not available for broadcasting!")
		return

	print("[CHAT] Broadcasting to %d players" % player_manager.connected_players.size())

	# Send to each connected player
	for other_peer_id in player_manager.connected_players:
		if network_handler.has_method("broadcast_chat_to_peer"):
			network_handler.broadcast_chat_to_peer(other_peer_id, player_name, message)
			print("[CHAT] Sent to peer %d" % other_peer_id)
		else:
			print("[CHAT] ERROR: network_handler doesn't have broadcast_chat_to_peer method!")
			break


# ========== FUTURE ENHANCEMENTS ==========
# TODO: Add chat message filtering (profanity, spam)
# TODO: Add rate limiting to prevent spam
# TODO: Add chat channels (global, team, whisper)
# TODO: Add chat commands (/help, /whisper, etc.)
# TODO: Add chat history logging to database
