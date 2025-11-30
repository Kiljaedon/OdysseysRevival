class_name BaseClient
extends Node


# Client Default Configuration / Set with load_client_configuration()
var address: String = "127.0.0.1"
var port: int = 9043
var certificate_path: String = "res://data/config/tls/certificate.crt"

# Client Components
var client: ENetMultiplayerPeer
var multiplayer_api: MultiplayerAPI
var authentication_callback := Callable()


func _process(_delta: float) -> void:
	if multiplayer_api and multiplayer_api.has_multiplayer_peer():
		multiplayer_api.poll()


func init_multiplayer_api(use_default: bool = false) -> void:
	multiplayer_api = (
		MultiplayerAPI.create_default_interface()
		if not use_default else multiplayer
	)
	
	multiplayer_api.connected_to_server.connect(_on_connection_succeeded)
	multiplayer_api.connection_failed.connect(_on_connection_failed)
	multiplayer_api.server_disconnected.connect(_on_server_disconnected)

	# Security: Disable object decoding to prevent arbitrary code execution
	# Only primitives, arrays, and dictionaries are used in RPCs - no custom objects needed
	multiplayer_api.allow_object_decoding = false
	
	# Always use root node path for multiplayer so RPC routing works correctly
	# Client and server both have /root, so this ensures compatible node paths
	get_tree().set_multiplayer(
		multiplayer_api,
		NodePath("/root")  # Explicit path to root node
	)


func load_client_configuration(section_key: String, default_config_path: String = "") -> bool:
	var parsed_arguments := CmdlineUtils.get_parsed_args()
	
	var config_path := default_config_path
	var config_file := ConfigFile.new()
	if parsed_arguments.has("config"):
		config_path = parsed_arguments["config"]
	var error := config_file.load(config_path)
	if error != OK:
		printerr("Failed to load config at %s, error: %s" % [config_path, error_string(error)])
	else:
		address = config_file.get_value(section_key, "address", address)
		port = config_file.get_value(section_key, "port", port)
		certificate_path = config_file.get_value(section_key, "certificate_path", certificate_path)
	return true


func start_client() -> void:
	if not multiplayer_api:
		init_multiplayer_api()

	# Add network handler at root for RPC routing
	var network_handler_script = load("res://source/common/network/network_handler.gd")
	if network_handler_script:
		var network_handler = network_handler_script.new()
		network_handler.name = "NetworkHandler"  # Set name BEFORE adding to tree
		get_tree().root.add_child(network_handler)
		print("[BaseClient] Network handler added to root as: %s" % network_handler)
	else:
		print("[BaseClient] ERROR: Could not load NetworkHandler script")

	client = ENetMultiplayerPeer.new()

	# ENet uses UDP, no TLS options needed
	var error: Error = client.create_client(address, port)
	if error != OK:
		printerr("Error while creating client: %s" % error_string(error))
	
	multiplayer_api.multiplayer_peer = client


func _on_connection_succeeded() -> void:
	print("Successfully connected as %d!" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	print("Failed to connect to the server.")


func _on_server_disconnected() -> void:
	print("Server disconnected.")


func _on_peer_authenticating(_peer_id: int) -> void:
	print("Trying to authenticate.")


func _on_peer_authentication_failed(_peer_id: int) -> void:
	print("Authentification failed.")


## ========== RAW BINARY PACKET SENDING ==========

func send_binary_packet(packet: PackedByteArray) -> bool:
	"""Send raw binary packet to server (bypasses RPC overhead)"""
	if not client:
		push_error("[BaseClient] Cannot send packet - client not initialized")
		return false

	# Send raw binary packet (no RPC framing)
	var error = client.put_packet(packet)
	if error != OK:
		push_error("[BaseClient] Failed to send packet: %s" % error_string(error))
		return false

	return true
