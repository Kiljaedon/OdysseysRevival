class_name WorldClient
extends BaseClient

# ========== SIGNALS ==========
signal connection_changed(connected_to_server: bool)
signal authentication_requested
signal login_response_received(success: bool, message: String, data: Dictionary)
signal account_creation_response_received(success: bool, message: String)

# ========== CLIENT STATE ==========
var peer_id: int
var is_connected_to_server: bool = false:
	set(value):
		is_connected_to_server = value
		connection_changed.emit(value)

var authentication_token: String
var authentication_completed: bool = false


func _ready():
	"""Initialize client sync for binary packet handling"""
	# Register in group for easy lookup (avoids fragile script path searches)
	add_to_group("world_client")

	# Create ClientSync for handling binary packets from server
	var client_sync_script = load("res://source/client/network/client_sync.gd")
	if client_sync_script:
		var client_sync = client_sync_script.new()
		client_sync.name = "ClientSync"
		add_child(client_sync)
		print("[WorldClient] ClientSync created and added")


func connect_to_server(
	_address: String,
	_port: int,
	_authentication_token: String
) -> void:
	address = _address
	port = _port
	authentication_token = _authentication_token
	# Set authentication callback
	authentication_callback = authentication_call
	start_client()


func send_rpc(method: String, args: Array = []) -> void:
	"""Send RPC to server via ServerConnection node"""
	# Debug logging disabled for performance (20 calls/sec during movement)
	# print("[WorldClient] Sending RPC: %s with %d args" % [method, args.size()])

	# Find ServerConnection node in scene tree
	var server_connection = _find_server_connection()

	if not server_connection:
		print("[WorldClient] ERROR: ServerConnection not found in scene tree!")
		return

	# Call RPC on the ServerConnection node using Callable (Godot 4 syntax)
	var callable = Callable(server_connection, method)
	match args.size():
		0:
			callable.rpc_id(1)
		1:
			callable.rpc_id(1, args[0])
		2:
			callable.rpc_id(1, args[0], args[1])
		3:
			callable.rpc_id(1, args[0], args[1], args[2])
		_:
			push_error("Too many RPC arguments")


func _find_server_connection() -> Node:
	"""Find ServerConnection node in /root"""
	# ServerConnection should be in /root for RPCs to work correctly
	var root = get_tree().root
	var server_conn = root.get_node_or_null("ServerConnection")
	if server_conn:
		return server_conn

	# Fallback: check parent (for scenes that haven't moved it yet)
	var parent = get_parent()
	if parent:
		server_conn = parent.get_node_or_null("ServerConnection")
		if server_conn:
			return server_conn

	# Last resort: search entire tree
	return _search_for_node(root, "ServerConnection")


func _search_for_node(node: Node, node_name: String) -> Node:
	"""Recursively search for node by name"""
	if node.name == node_name:
		return node

	for child in node.get_children():
		var found = _search_for_node(child, node_name)
		if found:
			return found

	return null


func close_connection() -> void:
	multiplayer.set_multiplayer_peer(null)
	client.close()
	is_connected_to_server = false


func _on_connection_succeeded() -> void:
	print("Successfully connected to the server as %d!" % multiplayer.get_unique_id())
	peer_id = multiplayer.get_unique_id()
	is_connected_to_server = true
	if OS.has_feature("debug"):
		DisplayServer.window_set_title("Client - %d" % peer_id)


func _on_connection_failed() -> void:
	print("Failed to connect to the server.")
	is_connected_to_server = false  # This will emit connection_changed(false)
	close_connection()


func _on_server_disconnected() -> void:
	print("Server disconnected.")
	close_connection()

	# Don't pause if we're transitioning to battle scene
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_meta("in_server_battle") and game_state.get_meta("in_server_battle"):
		print("[WorldClient] Battle transition in progress - not pausing game")
		return

	get_tree().paused = true


func _on_peer_authenticating(_peer_id: int) -> void:
	print("Trying to authenticate to the server.")


func _on_peer_authentication_failed(_peer_id: int) -> void:
	print("Authentication to the server failed.")
	# Keep connection open for login screen
	# close_connection()


func authentication_call(_peer_id: int, data: PackedByteArray) -> void:
	print("[WorldClient] Authentication requested by server")

	# Prevent double authentication
	if authentication_completed:
		print("[WorldClient] Authentication already completed, ignoring duplicate")
		return

	# Send a basic auth token to complete the handshake
	# Actual login happens via RPC after this
	if multiplayer.has_multiplayer_peer():
		multiplayer.send_auth(1, "GUEST".to_utf8_buffer())
		multiplayer.complete_auth(1)
		authentication_completed = true
		print("[WorldClient] Sent guest auth - ready for login")
