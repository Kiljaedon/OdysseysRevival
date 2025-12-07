class_name AuthNetworkService
extends Node
## Handles account lifecycle, authentication, session management
## ============================================================
## VERSION VALIDATION: All logins are checked against GameVersion.GAME_VERSION
## Mismatched versions are rejected before authentication.

const GameVersion = preload("res://source/common/version.gd")

var server_world: Node  # Set by ServerConnection


## ========== CLIENT → SERVER HANDLERS ==========

func handle_ping():
	# Removed: pings are frequent, no need to log each one
	pass


func handle_create_account(username: String, password: String):
	if multiplayer.is_server() and server_world:
		server_world.request_create_account(username, password)


func handle_login(username: String, password: String, client_version: String = ""):
	var peer_id = multiplayer.get_remote_sender_id()
	print("[AuthService] Login request from peer %d for user '%s' (version: %s)" % [peer_id, username, client_version])

	if multiplayer.is_server():
		# VERSION CHECK - MUST MATCH BEFORE LOGIN
		var server_version = GameVersion.GAME_VERSION
		if client_version.is_empty():
			print("[AuthService] REJECTED peer %d - No version sent (legacy client)" % peer_id)
			send_login_response(peer_id, false, "Version mismatch! Your client is outdated. Please download the latest version.", {})
			return

		if client_version != server_version:
			print("[AuthService] REJECTED peer %d - Version mismatch (client: %s, server: %s)" % [peer_id, client_version, server_version])
			send_login_response(peer_id, false, GameVersion.get_mismatch_message(client_version, server_version), {})
			return

		print("[AuthService] Version OK: %s" % server_version)
		if server_world:
			server_world.request_login(username, password)


## ========== SERVER → CLIENT SENDERS ==========

func send_account_creation_response(peer_id: int, success: bool, message: String):
	get_parent().account_creation_response.rpc_id(peer_id, success, message)


func send_login_response(peer_id: int, success: bool, message: String, data: Dictionary):
	get_parent().login_response.rpc_id(peer_id, success, message, data)


## ========== CLIENT-SIDE RESPONSE HANDLERS ==========

func on_account_creation_response(success: bool, message: String):
	var world_client = _find_world_client()
	if world_client:
		world_client.account_creation_response_received.emit(success, message)


func on_login_response(success: bool, message: String, data: Dictionary):
	var world_client = _find_world_client()
	if world_client:
		world_client.login_response_received.emit(success, message, data)


## ========== HELPERS ==========

func _find_world_client() -> Node:
	"""Find WorldClient using groups (robust, doesn't depend on script paths)"""
	var nodes = get_tree().get_nodes_in_group("world_client")
	if nodes.size() > 0:
		return nodes[0]
	return null
