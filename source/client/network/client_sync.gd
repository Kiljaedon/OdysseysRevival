class_name ClientSync
extends Node
## Client-side packet handling
## Receives and processes binary packets from server

signal position_update_received(entity_id: int, position: Vector2)
signal entity_state_received(entity_id: int, state: int, direction: int, velocity: Vector2)
signal combat_state_received(entity_id: int, hp: int, max_hp: int, effects: int)

# Map transition signals
signal map_transition_approved(target_map: String, spawn_x: int, spawn_y: int, players_on_map: Array)
signal map_transition_denied(reason: String)
signal player_left_map(player_id: int)
signal player_joined_map(player_id: int, spawn_x: int, spawn_y: int, player_data: Dictionary)

# Packet statistics
var packets_received_this_second: int = 0
var bytes_received_this_second: int = 0
var stats_timer: float = 0.0

## ========== PACKET RECEPTION ==========

@rpc
func receive_packet(packet: PackedByteArray):
	"""Receive binary packet from server"""
	if packet.size() < 1:
		push_error("[CLIENT_SYNC] Received empty packet")
		return

	# Update stats
	packets_received_this_second += 1
	bytes_received_this_second += packet.size()

	# Get packet type
	var packet_type = packet[0]

	# Route to appropriate handler
	match packet_type:
		PacketTypes.Type.PLAYER_POSITION:
			_handle_player_position(packet)
		PacketTypes.Type.NPC_POSITION:
			_handle_npc_position(packet)
		PacketTypes.Type.BULK_POSITIONS:
			_handle_bulk_positions(packet)
		PacketTypes.Type.ENTITY_STATE:
			_handle_entity_state(packet)
		PacketTypes.Type.COMBAT_STATE:
			_handle_combat_state(packet)
		PacketTypes.Type.COMBAT_START:
			_handle_combat_start(packet)
		PacketTypes.Type.MAP_TRANSITION_APPROVED:
			_handle_map_transition_approved(packet)
		PacketTypes.Type.MAP_TRANSITION_DENIED:
			_handle_map_transition_denied(packet)
		PacketTypes.Type.PLAYER_LEFT_MAP:
			_handle_player_left_map(packet)
		PacketTypes.Type.PLAYER_JOINED_MAP:
			_handle_player_joined_map(packet)
		_:
			push_warning("[CLIENT_SYNC] Unknown packet type: 0x%02X" % packet_type)


## ========== PACKET HANDLERS ==========

func _handle_player_position(packet: PackedByteArray):
	"""Handle PLAYER_POSITION packet"""
	var data = PacketEncoder.parse_player_position_packet(packet)
	if data.is_empty():
		return

	position_update_received.emit(data.peer_id, data.position)


func _handle_npc_position(packet: PackedByteArray):
	"""Handle NPC_POSITION packet"""
	var data = PacketEncoder.parse_npc_position_packet(packet)
	if data.is_empty():
		return

	position_update_received.emit(data.npc_id, data.position)


func _handle_bulk_positions(packet: PackedByteArray):
	"""Handle BULK_POSITIONS packet (multiple entities)"""
	var positions = PacketEncoder.parse_bulk_positions_packet(packet)
	if positions.is_empty():
		return

	# Emit signal for each entity
	for entity_id in positions.keys():
		position_update_received.emit(entity_id, positions[entity_id])


func _handle_entity_state(packet: PackedByteArray):
	"""Handle ENTITY_STATE packet (animation, direction, velocity)"""
	if packet.size() < 9:
		push_error("[CLIENT_SYNC] Invalid ENTITY_STATE packet size")
		return

	var entity_id = PacketEncoder.decode_u16(packet, 1)
	var state = packet[3]
	var direction = packet[4]
	var vel_x = float(PacketEncoder.decode_u16(packet, 5)) / 10.0
	var vel_y = float(PacketEncoder.decode_u16(packet, 7)) / 10.0

	# Handle signed values (two's complement)
	if vel_x > 3276.7:
		vel_x -= 6553.5
	if vel_y > 3276.7:
		vel_y -= 6553.5

	var velocity = Vector2(vel_x, vel_y)
	entity_state_received.emit(entity_id, state, direction, velocity)


func _handle_combat_state(packet: PackedByteArray):
	"""Handle COMBAT_STATE packet (HP, status effects)"""
	if packet.size() < 9:
		push_error("[CLIENT_SYNC] Invalid COMBAT_STATE packet size")
		return

	var entity_id = PacketEncoder.decode_u16(packet, 1)
	var hp = PacketEncoder.decode_u16(packet, 3)
	var max_hp = PacketEncoder.decode_u16(packet, 5)
	var effects = PacketEncoder.decode_u16(packet, 7)

	# Emit signal for UI to update health bars
	combat_state_received.emit(entity_id, hp, max_hp, effects)
	print("[CLIENT_SYNC] Combat state for entity %d: %d/%d HP, effects=%d" % [
		entity_id, hp, max_hp, effects
	])


func _handle_combat_start(packet: PackedByteArray):
	"""Handle COMBAT_START packet - server initiating battle"""
	var combat_data = PacketEncoder.parse_combat_start_packet(packet)
	if combat_data.is_empty():
		push_error("[CLIENT_SYNC] Failed to parse COMBAT_START packet")
		return

	print("[CLIENT_SYNC] Combat started! Combat ID: %d, NPC ID: %d, Enemy count: %d" % [
		combat_data.combat_id,
		combat_data.npc_id,
		combat_data.enemy_squad.size()
	])

	# Store combat data in GameState for battle scene to access
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		game_state.set_meta("server_combat_data", combat_data)
		game_state.set_meta("in_server_battle", true)
		print("[CLIENT_SYNC] Combat data stored in GameState as metadata")

		# Preserve client connection across scene change
		var server_conn = get_tree().root.get_node_or_null("ServerConnection")
		if server_conn:
			game_state.client = server_conn
			print("[CLIENT_SYNC] Preserved ServerConnection for battle scene")
	else:
		push_warning("[CLIENT_SYNC] GameState not found - combat data may not be accessible to battle scene")

	# NOTE: Battle scene loading is handled by RealtimeBattleLauncher via realtime_combat_network_service
	# DO NOT use change_scene_to_file here - it destroys the current map and prevents map cloning
	print("[CLIENT_SYNC] Combat data stored - waiting for realtime battle system to launch")


## ========== MAP TRANSITION HANDLERS ==========

func _handle_map_transition_approved(packet: PackedByteArray):
	"""Handle MAP_TRANSITION_APPROVED packet from server"""
	# Packet format: type(1) + map_name_len(1) + map_name(N) + spawn_x(2) + spawn_y(2) + player_count(1) + players...
	if packet.size() < 6:
		push_error("[CLIENT_SYNC] Invalid MAP_TRANSITION_APPROVED packet size")
		return

	var offset = 1
	var map_name_len = packet[offset]
	offset += 1

	if packet.size() < offset + map_name_len + 5:
		push_error("[CLIENT_SYNC] MAP_TRANSITION_APPROVED packet too short for map name")
		return

	var map_name = packet.slice(offset, offset + map_name_len).get_string_from_utf8()
	offset += map_name_len

	var spawn_x = PacketEncoder.decode_u16(packet, offset)
	offset += 2
	var spawn_y = PacketEncoder.decode_u16(packet, offset)
	offset += 2

	var player_count = packet[offset] if packet.size() > offset else 0
	offset += 1

	# Parse players already on the map
	var players_on_map: Array = []
	for i in range(player_count):
		if packet.size() < offset + 6:
			break
		var player_id = PacketEncoder.decode_u16(packet, offset)
		offset += 2
		var px = PacketEncoder.decode_u16(packet, offset)
		offset += 2
		var py = PacketEncoder.decode_u16(packet, offset)
		offset += 2
		players_on_map.append({"player_id": player_id, "x": px, "y": py})

	print("[CLIENT_SYNC] Map transition approved: %s at (%d, %d), %d players already there" % [
		map_name, spawn_x, spawn_y, players_on_map.size()
	])

	map_transition_approved.emit(map_name, spawn_x, spawn_y, players_on_map)


func _handle_map_transition_denied(packet: PackedByteArray):
	"""Handle MAP_TRANSITION_DENIED packet from server"""
	# Packet format: type(1) + reason_len(1) + reason(N)
	if packet.size() < 2:
		push_error("[CLIENT_SYNC] Invalid MAP_TRANSITION_DENIED packet size")
		return

	var reason_len = packet[1]
	var reason = "Unknown"
	if packet.size() >= 2 + reason_len:
		reason = packet.slice(2, 2 + reason_len).get_string_from_utf8()

	print("[CLIENT_SYNC] Map transition denied: %s" % reason)
	map_transition_denied.emit(reason)


func _handle_player_left_map(packet: PackedByteArray):
	"""Handle PLAYER_LEFT_MAP packet - another player left our map"""
	# Packet format: type(1) + player_id(2)
	if packet.size() < 3:
		push_error("[CLIENT_SYNC] Invalid PLAYER_LEFT_MAP packet size")
		return

	var player_id = PacketEncoder.decode_u16(packet, 1)
	print("[CLIENT_SYNC] Player %d left the map" % player_id)
	player_left_map.emit(player_id)


func _handle_player_joined_map(packet: PackedByteArray):
	"""Handle PLAYER_JOINED_MAP packet - another player joined our map"""
	# Packet format: type(1) + player_id(2) + spawn_x(2) + spawn_y(2) + name_len(1) + name(N)
	if packet.size() < 8:
		push_error("[CLIENT_SYNC] Invalid PLAYER_JOINED_MAP packet size")
		return

	var player_id = PacketEncoder.decode_u16(packet, 1)
	var spawn_x = PacketEncoder.decode_u16(packet, 3)
	var spawn_y = PacketEncoder.decode_u16(packet, 5)

	var name_len = packet[7] if packet.size() > 7 else 0
	var player_name = ""
	if packet.size() >= 8 + name_len:
		player_name = packet.slice(8, 8 + name_len).get_string_from_utf8()

	var player_data = {
		"name": player_name
	}

	print("[CLIENT_SYNC] Player %d (%s) joined at (%d, %d)" % [player_id, player_name, spawn_x, spawn_y])
	player_joined_map.emit(player_id, spawn_x, spawn_y, player_data)


## ========== SEND MAP TRANSITION REQUEST ==========

func request_map_transition(target_map: String, spawn_x: int, spawn_y: int):
	"""Send MAP_TRANSITION_REQUEST to server"""
	# Build packet: type(1) + map_name_len(1) + map_name(N) + spawn_x(2) + spawn_y(2)
	var map_bytes = target_map.to_utf8_buffer()
	var packet = PackedByteArray()
	packet.append(PacketTypes.Type.MAP_TRANSITION_REQUEST)
	packet.append(map_bytes.size())
	packet.append_array(map_bytes)
	packet.append_array(PacketEncoder.encode_u16(spawn_x))
	packet.append_array(PacketEncoder.encode_u16(spawn_y))

	# Send via RPC to server
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if server_conn and server_conn.has_method("send_packet"):
		server_conn.send_packet(packet)
		print("[CLIENT_SYNC] Sent MAP_TRANSITION_REQUEST: %s at (%d, %d)" % [target_map, spawn_x, spawn_y])
	else:
		push_warning("[CLIENT_SYNC] Cannot send transition request - no server connection")


## ========== STATISTICS ==========

func _process(delta):
	"""Update packet statistics"""
	stats_timer += delta

	if stats_timer >= 1.0:
		stats_timer = 0.0

		if packets_received_this_second > 0:
			print("[CLIENT_SYNC] Received %d packets (%d bytes) in last second" % [
				packets_received_this_second,
				bytes_received_this_second
			])

		packets_received_this_second = 0
		bytes_received_this_second = 0


func get_stats() -> Dictionary:
	"""Get client sync statistics"""
	return {
		"packets_per_second": packets_received_this_second,
		"bytes_per_second": bytes_received_this_second
	}
