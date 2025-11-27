class_name NetworkHandler
extends Node
## Network handler for server/client RPC routing at root level
## This ensures RPCs can be found at /root path on both server and client

var server_world: Node
var world_client: Node

func _ready():
	# Find the server_world node by searching all children
	for child in get_tree().root.get_children():
		if child.name == "ServerWorld":
			server_world = child
			# Pass reference to self so server_world can send responses
			if server_world.has_method("set_network_handler"):
				server_world.set_network_handler(self)
			print("[NetworkHandler] Found ServerWorld node: %s" % server_world)
			break

	if not server_world:
		print("[NetworkHandler] WARNING: ServerWorld not found in root children")

	# Find world_client via group if it exists (on client side)
	var found_client = find_world_client()
	if found_client:
		self.world_client = found_client
		print("[NetworkHandler] Found WorldClient node: %s" % world_client)
	else:
		print("[NetworkHandler] WorldClient not found - will search via group later if needed")


func _find_server_world() -> void:
	"""Search for ServerWorld node (lazy initialization for timing issues)"""
	for child in get_tree().root.get_children():
		if child.name == "ServerWorld":
			server_world = child
			print("[NetworkHandler] Found ServerWorld node via lazy search: %s" % server_world)
			return
	print("[NetworkHandler] WARNING: Could not find ServerWorld node in lazy search")


# ========== SERVER REQUEST RPCs (routed to server_world) ==========

@rpc("any_peer")
func request_create_account(username: String, password: String):
	"""Route to server_world"""
	if not server_world:
		_find_server_world()

	if server_world and server_world.has_method("request_create_account"):
		server_world.request_create_account(username, password)

@rpc("any_peer")
func request_login(username: String, password: String):
	"""Route to server_world"""
	# Lazy-load server_world if not found yet
	if not server_world:
		_find_server_world()

	print("[NetworkHandler] request_login RPC received! username=%s, server_world=%s" % [username, server_world])
	if server_world:
		print("[NetworkHandler] Routing to server_world.request_login()")
		if server_world.has_method("request_login"):
			server_world.request_login(username, password)
		else:
			print("[NetworkHandler] ERROR: server_world does not have request_login method")
	else:
		print("[NetworkHandler] ERROR: server_world is null!")

@rpc("any_peer")
func request_create_character(username: String, character_data: Dictionary):
	"""Route to server_world"""
	if not server_world:
		_find_server_world()

	print("[NetworkHandler] request_create_character RPC received! username=%s" % username)
	if server_world and server_world.has_method("request_create_character"):
		server_world.request_create_character(username, character_data)
	else:
		print("[NetworkHandler] ERROR: server_world doesn't have request_create_character method")

@rpc("any_peer")
func request_delete_character(username: String, character_id: String):
	"""Route to server_world"""
	if not server_world:
		_find_server_world()

	print("[NetworkHandler] request_delete_character RPC received! username=%s, char_id=%s" % [username, character_id])
	if server_world and server_world.has_method("request_delete_character"):
		server_world.request_delete_character(username, character_id)

@rpc("any_peer")
func request_spawn_character(username: String, character_id: String):
	"""Route to server_world"""
	if not server_world:
		_find_server_world()

	if server_world and server_world.has_method("request_spawn_character"):
		server_world.request_spawn_character(username, character_id)

@rpc("any_peer", "unreliable")
func binary_input(packet: PackedByteArray):
	"""Route binary input packet to server_world (unreliable for performance)"""
	if not server_world:
		_find_server_world()

	if server_world and server_world.has_method("handle_binary_input"):
		server_world.handle_binary_input(packet)

@rpc("any_peer")
func send_chat_message(message: String):
	"""Route to server_world"""
	if not server_world:
		_find_server_world()

	if server_world and server_world.has_method("send_chat_message"):
		server_world.send_chat_message(message)

@rpc("any_peer")
func send_player_battle_action(combat_id: int, action_type: String, target_id: int):
	"""Route player battle action to server_world"""
	if not server_world:
		_find_server_world()

	var peer_id = multiplayer.get_remote_sender_id()
	if server_world and server_world.has_method("receive_player_battle_action"):
		server_world.receive_player_battle_action(peer_id, combat_id, action_type, target_id)
	else:
		print("[NetworkHandler] ERROR: server_world doesn't have receive_player_battle_action method")

@rpc("any_peer")
func request_npc_attack(npc_id: int):
	"""Route NPC attack request to server_world"""
	if not server_world:
		_find_server_world()

	if server_world and server_world.has_method("handle_npc_attack_request"):
		server_world.handle_npc_attack_request(npc_id)
	else:
		print("[NetworkHandler] ERROR: server_world doesn't have handle_npc_attack_request method")


# ========== SERVER RESPONSE RPCs (called by server, executed on client) ==========

func find_world_client(_node: Node = null) -> Node:
	"""Find WorldClient using groups (robust, doesn't depend on script paths)"""
	var nodes = get_tree().get_nodes_in_group("world_client")
	if nodes.size() > 0:
		print("[NetworkHandler] find_world_client: Found via group at path %s" % nodes[0].get_path())
		return nodes[0]
	return null

func find_node_with_method(node: Node, method_name: String) -> Node:
	"""Recursively search for a node that has a specific method"""
	if node.has_method(method_name):
		return node

	for child in node.get_children():
		var found = find_node_with_method(child, method_name)
		if found:
			return found
	return null

func find_character_select_screen(_node: Node = null) -> Node:
	"""Find character select screen using groups (robust, doesn't depend on script paths)"""
	var nodes = get_tree().get_nodes_in_group("character_select_screen")
	if nodes.size() > 0:
		print("[NetworkHandler] find_character_select_screen: Found via group at path %s" % nodes[0].get_path())
		return nodes[0]
	return null

func find_character_creator(_node: Node = null) -> Node:
	"""Find character creator using groups (robust, doesn't depend on script paths)"""
	var nodes = get_tree().get_nodes_in_group("character_creator")
	if nodes.size() > 0:
		print("[NetworkHandler] find_character_creator: Found via group at path %s" % nodes[0].get_path())
		return nodes[0]
	return null

@rpc
func account_creation_response(success: bool, message: String):
	"""Server response - relay to WorldClient"""
	# Search for WorldClient via group if not cached yet
	if not world_client:
		world_client = find_world_client()
		if world_client:
			print("[NetworkHandler] Found WorldClient (delayed): %s" % world_client)

	if world_client:
		print("[NetworkHandler] Relaying account_creation_response to WorldClient: success=%s, msg=%s" % [success, message])
		world_client.account_creation_response_received.emit(success, message)
	else:
		print("[NetworkHandler] ERROR: Cannot relay account_creation_response - WorldClient not found!")

@rpc
func login_response(success: bool, message: String, data: Dictionary):
	"""Server response - relay to WorldClient"""
	print("[NetworkHandler CLIENT] login_response RPC received!")
	print("[NetworkHandler CLIENT] success: %s, message: %s" % [success, message])
	print("[NetworkHandler CLIENT] data keys: %s" % str(data.keys()))
	if data.has("characters"):
		print("[NetworkHandler CLIENT] Characters received: %d" % data.characters.size())
		if data.characters.size() > 0:
			print("[NetworkHandler CLIENT] First character: %s" % JSON.stringify(data.characters[0]))
	else:
		print("[NetworkHandler CLIENT] WARNING: No 'characters' key in data!")

	# Search for WorldClient via group if not cached yet
	if not world_client:
		world_client = find_world_client()
		if world_client:
			print("[NetworkHandler] Found WorldClient (delayed): %s" % world_client)

	if world_client:
		print("[NetworkHandler] Relaying login_response to WorldClient: success=%s" % success)
		world_client.login_response_received.emit(success, message, data)
	else:
		print("[NetworkHandler] ERROR: Cannot relay login_response - WorldClient not found!")

@rpc
func character_creation_response(success: bool, message: String, character_data: Dictionary):
	"""Server response - find and call character_creator's handler"""
	print("[NetworkHandler] Received character_creation_response: success=%s, msg=%s, data=%s" % [success, message, character_data])

	# Find character_creator via group
	var char_creator = find_character_creator()
	if char_creator:
		print("[NetworkHandler] Relaying to character_creator at %s" % char_creator.get_path())
		char_creator.character_creation_response(success, message, character_data)
	else:
		print("[NetworkHandler] WARNING: character_creator not found via group")

@rpc
func character_deletion_response(success: bool, message: String):
	"""Server response - find and call character select's handler"""
	print("[NetworkHandler] Received character_deletion_response: success=%s, msg=%s" % [success, message])

	# Find character select screen via group
	var char_select = find_character_select_screen()
	if char_select:
		print("[NetworkHandler] Relaying to character_select at %s" % char_select.get_path())
		char_select.character_deletion_response(success, message)
	else:
		print("[NetworkHandler] WARNING: character_select not found via group")


# ========== SERVER RESPONSE SENDERS (called by server_world, send RPC from NetworkHandler context) ==========

func send_account_creation_response(peer_id: int, success: bool, message: String):
	"""Send account creation response to specific peer (called from server_world)"""
	rpc_id(peer_id, "account_creation_response", success, message)
 
func send_login_response(peer_id: int, success: bool, message: String, data: Dictionary):
	"""Send login response to specific peer (called from server_world)"""
	print("[NetworkHandler] send_login_response called - peer_id: %d, success: %s" % [peer_id, success])
	print("[NetworkHandler] Data keys: %s" % str(data.keys()))
	if data.has("characters"):
		print("[NetworkHandler] Characters in data: %d" % data.characters.size())
		if data.characters.size() > 0:
			print("[NetworkHandler] First character name: %s" % data.characters[0].get("name", "Unknown"))
	else:
		print("[NetworkHandler] WARNING: 'characters' key not found in data!")
	rpc_id(peer_id, "login_response", success, message, data)

func send_character_creation_response(peer_id: int, success: bool, message: String, character_id: String):
	"""Send character creation response to specific peer (called from server_world)"""
	rpc_id(peer_id, "character_creation_response", success, message, character_id)

func send_character_deletion_response(peer_id: int, success: bool, message: String):
	"""Send character deletion response to specific peer (called from server_world)"""
	rpc_id(peer_id, "character_deletion_response", success, message)

# ========== GAMEPLAY RESPONSE SENDERS ==========

func send_spawn_accepted(peer_id: int, player_data: Dictionary):
	"""Send spawn accepted response to specific peer"""
	rpc_id(peer_id, "spawn_accepted", player_data)

func send_spawn_rejected(peer_id: int, reason: String):
	"""Send spawn rejected response to specific peer"""
	rpc_id(peer_id, "spawn_rejected", reason)

func send_player_spawned(peer_id: int, spawned_peer_id: int, player_data: Dictionary):
	"""Notify a peer that another player spawned"""
	rpc_id(peer_id, "player_spawned", spawned_peer_id, player_data)

func send_player_despawned(peer_id: int, despawned_peer_id: int):
	"""Notify a peer that another player despawned"""
	rpc_id(peer_id, "player_despawned", despawned_peer_id)

func send_sync_positions(peer_id: int, positions: Dictionary):
	"""Send position sync to specific peer"""
	rpc_id(peer_id, "sync_positions", positions)

func broadcast_chat_to_peer(peer_id: int, player_name: String, message: String):
	"""Send chat message to specific peer"""
	rpc_id(peer_id, "receive_chat_message", player_name, message)

# ========== NPC RESPONSE SENDERS ==========

func send_npc_spawn(peer_id: int, npc_id: int, npc_data: Dictionary):
	"""Send NPC spawn notification to specific peer"""
	rpc_id(peer_id, "npc_spawned", npc_id, npc_data)

func send_sync_npc_positions(peer_id: int, npc_positions: Dictionary):
	"""Send NPC position sync to specific peer"""
	rpc_id(peer_id, "sync_npc_positions", npc_positions)

# ========== GAMEPLAY RESPONSE RECEIVERS (called by server, executed on client) ==========

@rpc
func spawn_accepted(player_data: Dictionary):
	"""Server accepted spawn request - relay to client handler"""
	var handler = find_node_with_method(get_tree().root, "handle_spawn_accepted")
	if handler and handler != self:
		handler.handle_spawn_accepted(player_data)
	else:
		print("[NetworkHandler] WARNING: No handler found for spawn_accepted")

@rpc
func spawn_rejected(reason: String):
	"""Server rejected spawn request - relay to client handler"""
	var handler = find_node_with_method(get_tree().root, "handle_spawn_rejected")
	if handler and handler != self:
		handler.handle_spawn_rejected(reason)
	else:
		print("[NetworkHandler] WARNING: No handler found for spawn_rejected")

@rpc
func player_spawned(spawned_peer_id: int, player_data: Dictionary):
	"""Another player spawned - relay to client handler"""
	var handler = find_node_with_method(get_tree().root, "handle_player_spawned")
	if handler and handler != self:
		handler.handle_player_spawned(spawned_peer_id, player_data)
	else:
		print("[NetworkHandler] WARNING: No handler found for player_spawned")

@rpc
func player_despawned(despawned_peer_id: int):
	"""Another player despawned - relay to client handler"""
	var handler = find_node_with_method(get_tree().root, "handle_player_despawned")
	if handler and handler != self:
		handler.handle_player_despawned(despawned_peer_id)
	else:
		print("[NetworkHandler] WARNING: No handler found for player_despawned")

@rpc
func sync_positions(positions: Dictionary):
	"""Receive position sync from server - relay to client handler"""
	var handler = find_node_with_method(get_tree().root, "handle_sync_positions")
	if handler and handler != self:
		handler.handle_sync_positions(positions)

@rpc
func receive_chat_message(player_name: String, message: String):
	"""Receive chat message from server - relay to client handler"""
	var handler = find_node_with_method(get_tree().root, "handle_chat_message")
	if handler and handler != self:
		handler.handle_chat_message(player_name, message)
	else:
		print("[NetworkHandler] WARNING: No handler found for receive_chat_message")

@rpc
func npc_spawned(npc_id: int, npc_data: Dictionary):
	"""NPC spawned - relay to client handler"""
	var handler = find_node_with_method(get_tree().root, "handle_npc_spawned")
	if handler and handler != self:
		handler.handle_npc_spawned(npc_id, npc_data)

@rpc
func sync_npc_positions(npc_positions: Dictionary):
	"""Receive NPC position sync from server - relay to client handler"""
	var handler = find_node_with_method(get_tree().root, "handle_sync_npc_positions")
	if handler and handler != self:
		handler.handle_sync_npc_positions(npc_positions)

# ========== BINARY PACKET RPC ==========

@rpc("any_peer", "unreliable")
func binary_positions(packet: PackedByteArray):
	"""Receive binary position packet from server (unreliable for performance)"""
	# Emit signal for client to handle
	if world_client and world_client.has_method("handle_binary_positions"):
		world_client.handle_binary_positions(packet)
	else:
		# Find any node that can handle position updates
		var handler = find_node_with_method(get_tree().root, "handle_binary_positions")
		if handler and handler != self:
			handler.handle_binary_positions(packet)

# ========== BINARY COMBAT PACKET SENDERS ==========

func send_binary_combat_start(peer_id: int, packet: PackedByteArray):
	"""Send COMBAT_START binary packet to specific client"""
	if multiplayer and multiplayer.is_server():
		binary_combat_start.rpc_id(peer_id, packet)

func send_binary_packet(peer_id: int, packet: PackedByteArray):
	"""Send generic binary packet to specific client"""
	if multiplayer and multiplayer.is_server():
		binary_packet.rpc_id(peer_id, packet)

@rpc("any_peer", "unreliable")
func binary_combat_start(packet: PackedByteArray):
	"""Receive binary combat start packet from server"""
	# Route to client sync handler
	var handler = find_node_with_method(get_tree().root, "receive_packet")
	if handler and handler != self:
		handler.receive_packet(packet)

@rpc("any_peer", "unreliable")
func binary_packet(packet: PackedByteArray):
	"""Receive generic binary packet from server"""
	# Route to client sync handler
	var handler = find_node_with_method(get_tree().root, "receive_packet")
	if handler and handler != self:
		handler.receive_packet(packet)
