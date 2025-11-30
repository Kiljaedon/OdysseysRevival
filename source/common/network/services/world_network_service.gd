class_name WorldNetworkService
extends Node
## Handles player/NPC presence, movement, world state

var server_world: Node  # Set by ServerConnection


## ========== CLIENT → SERVER HANDLERS ==========

func handle_binary_input(packet: PackedByteArray):
	if multiplayer.is_server() and server_world:
		server_world.handle_binary_input(packet)


## ========== SERVER → CLIENT SENDERS ==========

func send_player_spawned(peer_id: int, spawned_peer_id: int, player_data: Dictionary):
	get_parent().player_spawned.rpc_id(peer_id, spawned_peer_id, player_data)


func send_player_despawned(peer_id: int, despawned_peer_id: int):
	get_parent().player_despawned.rpc_id(peer_id, despawned_peer_id)


func send_sync_positions(peer_id: int, positions: Dictionary):
	get_parent().sync_positions.rpc_id(peer_id, positions)


func send_binary_positions(peer_id: int, packet: PackedByteArray):
	get_parent().binary_positions.rpc_id(peer_id, packet)


func send_npc_spawn(peer_id: int, npc_id: int, npc_data: Dictionary):
	print("[WorldService] Sending NPC spawn to peer %d: NPC %d" % [peer_id, npc_id])
	get_parent().npc_spawned.rpc_id(peer_id, npc_id, npc_data)


func send_sync_npc_positions(peer_id: int, npc_positions: Dictionary):
	get_parent().sync_npc_positions.rpc_id(peer_id, npc_positions)


## ========== CLIENT-SIDE RESPONSE HANDLERS ==========

func on_player_spawned(spawned_peer_id: int, player_data: Dictionary):
	var controller = get_parent()._find_node_with_script("dev_client_controller.gd")
	if controller:
		controller.handle_player_spawned(spawned_peer_id, player_data)


func on_player_despawned(despawned_peer_id: int):
	var controller = get_parent()._find_node_with_script("dev_client_controller.gd")
	if controller:
		controller.handle_player_despawned(despawned_peer_id)


func on_sync_positions(positions: Dictionary):
	var controller = get_parent()._find_node_with_script("dev_client_controller.gd")
	if controller:
		controller.handle_sync_positions(positions)


func on_binary_positions(packet: PackedByteArray):
	var controller = get_parent()._find_node_with_script("dev_client_controller.gd")
	if controller:
		controller.handle_binary_positions(packet)


func on_npc_spawned(npc_id: int, npc_data: Dictionary):
	print("[WorldService] NPC spawned received: %d" % npc_id)
	var controller = get_parent()._find_node_with_script("dev_client_controller.gd")
	if controller:
		controller.handle_npc_spawned(npc_id, npc_data)


func on_sync_npc_positions(npc_positions: Dictionary):
	var controller = get_parent()._find_node_with_script("dev_client_controller.gd")
	if controller:
		controller.handle_sync_npc_positions(npc_positions)


## ========== MAP TRANSITION ==========

func handle_map_change_request(peer_id: int, map_name: String, x: float, y: float):
	"""Server-side: Handle map change request from client"""
	if not server_world:
		print("[WorldService] ERROR: No server_world for map change")
		return

	print("[WorldService] Map change request from peer %d: %s at (%f, %f)" % [peer_id, map_name, x, y])

	# Update player's map and position in server state
	if server_world.has_node("PlayerManager"):
		var player_manager = server_world.get_node("PlayerManager")
		if player_manager.has_method("update_player_map"):
			player_manager.update_player_map(peer_id, map_name, Vector2(x, y))
		else:
			# Fallback: just update position
			player_manager.player_positions[peer_id] = Vector2(x, y)

	# Notify other players on the same map (future: map-based player lists)
	# For now, just log the change
	print("[WorldService] Player %d moved to map: %s" % [peer_id, map_name])


func on_map_changed(map_name: String, spawn_x: float, spawn_y: float):
	"""Client-side: Server confirmed map change"""
	print("[WorldService] Map change confirmed: %s at (%f, %f)" % [map_name, spawn_x, spawn_y])
	# Client already loaded the map, this is just confirmation
