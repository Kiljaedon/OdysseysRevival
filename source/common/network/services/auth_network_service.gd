class_name AuthNetworkService
extends Node
## Handles account lifecycle, authentication, session management

var server_world: Node  # Set by ServerConnection


## ========== CLIENT → SERVER HANDLERS ==========

func handle_ping():
	print("[AuthService] PING received from peer %d" % multiplayer.get_remote_sender_id())


func handle_create_account(username: String, password: String):
	if multiplayer.is_server() and server_world:
		server_world.request_create_account(username, password)


func handle_login(username: String, password: String):
	var peer_id = multiplayer.get_remote_sender_id()
	print("[AuthService] Login request from peer %d for user '%s'" % [peer_id, username])
	if multiplayer.is_server() and server_world:
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
