class_name NetworkSync
extends Node
## Server-side network synchronization using binary packets
## Handles efficient broadcasting of entity positions to relevant clients

# Preload PacketEncoder to avoid scope issues
const PacketEncoder = preload("res://source/common/network/packet_encoder.gd")

var server
var spatial_manager
var network_handler: Node  # For RPC events
var map_manager: ServerMapManager  # For map transitions

# Packet statistics
var packets_sent_this_second: int = 0
var bytes_sent_this_second: int = 0
var stats_timer: float = 0.0

## ========== INITIALIZATION ==========

func _ready():
	print("[NETWORK_SYNC] Initialized binary packet synchronization")


func set_server(server_ref):
	"""Set reference to server"""
	server = server_ref


func set_spatial_manager(spatial_ref):
	"""Set reference to spatial manager"""
	spatial_manager = spatial_ref


func set_network_handler(handler_ref: Node):
	"""Set reference to network handler (for RPC events)"""
	network_handler = handler_ref
	print("[NetworkSync] network_handler set to: %s" % network_handler)


func set_map_manager(map_mgr: ServerMapManager):
	"""Set reference to map manager (for transitions)"""
	map_manager = map_mgr
	print("[NetworkSync] map_manager set")


## ========== POSITION BROADCASTING ==========

func broadcast_player_positions(player_positions: Dictionary):
	"""Broadcast player positions using binary packets with interest management"""
	if not server or not spatial_manager:
		return

	# For each player, send only nearby entities
	for peer_id in player_positions.keys():
		# Get entities visible to this player
		var visible_entities = spatial_manager.get_entities_for_player(peer_id)

		if visible_entities.is_empty():
			continue

		# Build bulk positions packet
		var packet = PacketEncoder.build_bulk_positions_packet(visible_entities)

		# Send unreliable packet to this player
		send_unreliable_packet(peer_id, packet)


var npc_broadcast_count = 0  # Track broadcasts

func broadcast_npc_positions(npc_positions: Dictionary, spatial_mgr = null):
	"""Broadcast NPC positions using spatial culling (only to players who can see them)"""
	if not server or npc_positions.is_empty():
		return

	# Use spatial manager if provided, otherwise fallback to broadcast all
	if not spatial_mgr:
		spatial_mgr = spatial_manager

	if not spatial_mgr:
		return

	# One-time debug log
	if npc_broadcast_count == 0:
		print("[NetworkSync] Broadcasting %d NPCs with spatial culling" % [npc_positions.size()])

	npc_broadcast_count += 1

	# Build bulk packet per player with only visible NPCs
	var player_visible_npcs: Dictionary = {}  # {peer_id: [npc positions]}

	for npc_id in npc_positions.keys():
		var npc_pos = npc_positions[npc_id]

		# NEW: Get only players who can see this NPC using spatial manager
		var viewers = spatial_mgr.get_players_who_can_see(npc_id)

		for peer_id in viewers:
			if not player_visible_npcs.has(peer_id):
				player_visible_npcs[peer_id] = []
			player_visible_npcs[peer_id].append({"id": npc_id, "pos": npc_pos})

	# Send bulk packet to each player with their visible NPCs
	for peer_id in player_visible_npcs.keys():
		var visible_npcs = player_visible_npcs[peer_id]
		var bulk_packet = PacketEncoder.build_bulk_npc_positions_packet(visible_npcs)
		send_unreliable_packet(peer_id, bulk_packet)


func broadcast_entity_state(entity_id: int, state: int, direction: int, velocity: Vector2):
	"""Broadcast entity animation/movement state"""
	if not server or not spatial_manager:
		return

	# Get players who can see this entity
	var viewers = spatial_manager.get_players_who_can_see(entity_id)

	if viewers.is_empty():
		return

	# Build entity state packet
	var packet = PacketEncoder.build_entity_state_packet(entity_id, state, direction, velocity)

	# Send to all viewers
	for peer_id in viewers:
		send_unreliable_packet(peer_id, packet)


## ========== PACKET SENDING ==========

var packet_send_logged = false

func send_unreliable_packet(peer_id: int, packet: PackedByteArray):
	"""Send unreliable packet to specific peer via unreliable RPC"""
	if not network_handler:
		print("[SEND_PACKET] ERROR: No network_handler!")
		return

	if not packet_send_logged:
		print("[SEND_PACKET] Sending first packet to peer %d, size=%d bytes" % [peer_id, packet.size()])
		packet_send_logged = true

	# Send via unreliable RPC (adds ~16 bytes overhead but routes correctly)
	network_handler.rpc_id(peer_id, "binary_positions", packet)

	# Update stats
	packets_sent_this_second += 1
	bytes_sent_this_second += packet.size() + 16  # 6-byte payload + ~16 RPC overhead


## ========== STATISTICS ==========

func _process(delta):
	"""Update packet statistics"""
	stats_timer += delta

	if stats_timer >= 1.0:
		stats_timer = 0.0

		# Commented out to reduce console spam - uncomment for network debugging
		#if packets_sent_this_second > 0:
		#       print("[NETWORK_SYNC] Sent %d packets (%d bytes) in last second" % [
		#               packets_sent_this_second,
		#               bytes_sent_this_second
		#       ])

		packets_sent_this_second = 0
		bytes_sent_this_second = 0


func get_stats() -> Dictionary:
	"""Get network sync statistics"""
	return {
		"packets_per_second": packets_sent_this_second,
		"bytes_per_second": bytes_sent_this_second
	}


func get_stats_summary() -> Dictionary:
	"""Get network sync statistics (alias for get_stats)"""
	return {
		"packets_sent_this_second": packets_sent_this_second,
		"bytes_sent_this_second": bytes_sent_this_second
	}


## ========== MAP TRANSITION HANDLING ==========

func handle_map_transition_request(peer_id: int, packet: PackedByteArray):
	"""Handle MAP_TRANSITION_REQUEST packet from client"""
	if not map_manager:
		print("[NetworkSync] ERROR: No map_manager for transition request")
		return

	# Parse packet: type(1) + map_name_len(1) + map_name(N) + spawn_x(2) + spawn_y(2)
	if packet.size() < 6:
		print("[NetworkSync] Invalid MAP_TRANSITION_REQUEST packet size")
		return

	var offset = 1
	var map_name_len = packet[offset]
	offset += 1

	if packet.size() < offset + map_name_len + 4:
		print("[NetworkSync] MAP_TRANSITION_REQUEST packet too short")
		return

	var target_map = packet.slice(offset, offset + map_name_len).get_string_from_utf8()
	offset += map_name_len

	var spawn_x = PacketEncoder.decode_u16(packet, offset)
	offset += 2
	var spawn_y = PacketEncoder.decode_u16(packet, offset)

	print("[NetworkSync] Transition request from peer %d: %s at (%d, %d)" % [peer_id, target_map, spawn_x, spawn_y])

	# Process the transition
	var result = map_manager.process_map_transition(peer_id, target_map, spawn_x, spawn_y)

	if result.success:
		# Send approval to transitioning player
		_send_transition_approved(peer_id, result.new_map, result.spawn_x, result.spawn_y, result.players_info)

		# Notify players on old map that this player left
		for old_peer_id in result.old_map_players:
			_send_player_left_map(old_peer_id, peer_id)

		# Notify players on new map that this player joined
		var player_name = "Player_%d" % peer_id  # TODO: Get actual player name
		for new_peer_id in result.new_map_players:
			_send_player_joined_map(new_peer_id, peer_id, result.spawn_x, result.spawn_y, player_name)

		print("[NetworkSync] Transition completed: peer %d moved from '%s' to '%s'" % [peer_id, result.old_map, result.new_map])
	else:
		# Send denial
		_send_transition_denied(peer_id, result.reason)
		print("[NetworkSync] Transition denied for peer %d: %s" % [peer_id, result.reason])


func _send_transition_approved(peer_id: int, map_name: String, spawn_x: int, spawn_y: int, players_info: Array):
	"""Send MAP_TRANSITION_APPROVED packet to client"""
	var map_bytes = map_name.to_utf8_buffer()
	var packet = PackedByteArray()
	packet.append(PacketTypes.Type.MAP_TRANSITION_APPROVED)
	packet.append(map_bytes.size())
	packet.append_array(map_bytes)
	packet.append_array(PacketEncoder.encode_u16(spawn_x))
	packet.append_array(PacketEncoder.encode_u16(spawn_y))
	packet.append(players_info.size())

	# Add player info
	for player in players_info:
		packet.append_array(PacketEncoder.encode_u16(player.player_id))
		packet.append_array(PacketEncoder.encode_u16(player.x))
		packet.append_array(PacketEncoder.encode_u16(player.y))

	_send_reliable_packet(peer_id, packet)


func _send_transition_denied(peer_id: int, reason: String):
	"""Send MAP_TRANSITION_DENIED packet to client"""
	var reason_bytes = reason.to_utf8_buffer()
	var packet = PackedByteArray()
	packet.append(PacketTypes.Type.MAP_TRANSITION_DENIED)
	packet.append(reason_bytes.size())
	packet.append_array(reason_bytes)

	_send_reliable_packet(peer_id, packet)


func _send_player_left_map(peer_id: int, leaving_player_id: int):
	"""Send PLAYER_LEFT_MAP packet to client"""
	var packet = PackedByteArray()
	packet.append(PacketTypes.Type.PLAYER_LEFT_MAP)
	packet.append_array(PacketEncoder.encode_u16(leaving_player_id))

	_send_reliable_packet(peer_id, packet)


func _send_player_joined_map(peer_id: int, joining_player_id: int, spawn_x: int, spawn_y: int, player_name: String):
	"""Send PLAYER_JOINED_MAP packet to client"""
	var name_bytes = player_name.to_utf8_buffer()
	var packet = PackedByteArray()
	packet.append(PacketTypes.Type.PLAYER_JOINED_MAP)
	packet.append_array(PacketEncoder.encode_u16(joining_player_id))
	packet.append_array(PacketEncoder.encode_u16(spawn_x))
	packet.append_array(PacketEncoder.encode_u16(spawn_y))
	packet.append(name_bytes.size())
	packet.append_array(name_bytes)

	_send_reliable_packet(peer_id, packet)


func _send_reliable_packet(peer_id: int, packet: PackedByteArray):
	"""Send reliable packet (using RPC channel 0 for reliable delivery)"""
	if not network_handler:
		print("[NetworkSync] ERROR: No network_handler for reliable packet!")
		return

	# Use reliable RPC for map transitions
	network_handler.rpc_id(peer_id, "receive_packet", packet)

	# Update stats
	packets_sent_this_second += 1
	bytes_sent_this_second += packet.size() + 16
