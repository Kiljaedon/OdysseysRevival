class_name BaseServer
extends Node

const CmdlineUtils = preload("res://source/common/utils/cmdline_utils.gd")

# Server Default Configuration / Set with load_server_configuration()
var port: int = 9043
var certificate_path: String = "res://data/config/tls/certificate.crt"
var key_path: String = "res://data/config/tls/key.key"

# Server Components
var server: ENetMultiplayerPeer
var multiplayer_api: SceneMultiplayer
var authentication_callback := Callable()


func _process(_delta: float) -> void:
	if multiplayer_api and multiplayer_api.has_multiplayer_peer():
		multiplayer_api.poll()


func init_multiplayer_api(use_default: bool = false) -> void:
	multiplayer_api = (
		# SceneMultiplayer.new()
		MultiplayerAPI.create_default_interface()
		if not use_default else multiplayer
	)
	
	multiplayer_api.peer_connected.connect(_on_peer_connected)
	multiplayer_api.peer_disconnected.connect(_on_peer_disconnected)

	# Security: Disable object decoding to prevent arbitrary code execution
	# Only primitives, arrays, and dictionaries are used in RPCs - no custom objects needed
	multiplayer_api.allow_object_decoding = false
	
	# Always use root node as multiplayer context for consistent RPC routing
	get_tree().set_multiplayer(
		multiplayer_api,
		NodePath("/root")
	)


func load_server_configuration(section_key: String, default_config_path: String = "") -> bool:
	var parsed_arguments := CmdlineUtils.get_parsed_args()
	
	var config_path: String = default_config_path
	var config_file := ConfigFile.new()
	if parsed_arguments.has("config"):
		config_path = parsed_arguments["config"]
	var error: Error = config_file.load(config_path)
	if error != OK:
		printerr("Failed to load config at %s, error: %s" % [parsed_arguments["config"], error_string(error)])
	else:
		port = config_file.get_value(section_key, "port", port)
		certificate_path = config_file.get_value(section_key, "certificate_path", certificate_path)
		key_path = config_file.get_value(section_key, "key_path", key_path)
	return true


func start_server() -> void:
	if not multiplayer_api:
		init_multiplayer_api()

	server = ENetMultiplayerPeer.new()

	# Force IPv4 binding to ensure return path works for IPv4 clients
	server.set_bind_ip("0.0.0.0")

	# Create ENet server (UDP-based, no TLS options needed)
	print("[BaseServer] Attempting to create server on port %d..." % port)
	var error: Error = server.create_server(port, 32)
	if error != OK:
		printerr("Error while creating server: %s" % error_string(error))
		printerr("Failed to bind to port %d - check if port is already in use" % port)
		return  # Early return prevents broken state

	# Verify server is actually connected before assigning
	if server.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		printerr("ENet server created but not in connected state!")
		return  # Additional safety check

	multiplayer_api.multiplayer_peer = server

	print("[BaseServer] Server started successfully on port %d" % port)
	print("[BaseServer] ENet ready state: %d" % server.get_connection_status())


func _on_peer_connected(peer_id: int) -> void:
	var peer_state = server.get_peer(peer_id)
	print("[BaseServer] Peer %d connected. State: %s" % [peer_id, peer_state])


func _on_peer_disconnected(peer_id: int) -> void:
	# Note: ENet doesn't provide close codes like WebSocket does
	print("[BaseServer] Peer %d disconnected." % peer_id)


func _on_peer_authenticating(peer_id: int) -> void:
	print("Peer: %d is trying to authenticate." % peer_id)
	multiplayer_api.send_auth(peer_id, "send_string".to_ascii_buffer())


func _on_peer_authentication_failed(peer_id: int) -> void:
	print("Peer: %d failed to authenticate." % peer_id)


## ========== RAW BINARY PACKET SENDING ==========

func send_binary_packet(peer_id: int, packet: PackedByteArray) -> bool:
	"""Send raw binary packet directly via WebSocket (bypasses RPC overhead)"""
	if not server:
		push_error("[BaseServer] Cannot send packet - server not initialized")
		return false

	var peer = server.get_peer(peer_id)
	if not peer:
		push_error("[BaseServer] Cannot send packet - peer %d not found" % peer_id)
		return false

	# Send raw binary packet (no RPC framing)
	var error = peer.put_packet(packet)
	if error != OK:
		push_error("[BaseServer] Failed to send packet to peer %d: %s" % [peer_id, error_string(error)])
		return false

	return true


func broadcast_binary_packet(packet: PackedByteArray, exclude_peer: int = -1) -> void:
	"""Broadcast raw binary packet to all connected peers"""
	if not server:
		return

	for peer_id in multiplayer_api.get_peers():
		if peer_id == exclude_peer:
			continue
		send_binary_packet(peer_id, packet)
