class_name PacketEncoder
## Binary packet encoding/decoding utilities
## Provides efficient serialization for network transmission

## ========== ENCODING FUNCTIONS ==========

static func encode_u8(value: int) -> PackedByteArray:
	"""Encode unsigned 8-bit integer (0-255)"""
	var bytes = PackedByteArray()
	bytes.append(value & 0xFF)
	return bytes

static func encode_u16(value: int) -> PackedByteArray:
	"""Encode unsigned 16-bit integer (0-65535)"""
	var bytes = PackedByteArray()
	bytes.append((value >> 8) & 0xFF)  # High byte
	bytes.append(value & 0xFF)         # Low byte
	return bytes

static func encode_u32(value: int) -> PackedByteArray:
	"""Encode unsigned 32-bit integer"""
	var bytes = PackedByteArray()
	bytes.append((value >> 24) & 0xFF)
	bytes.append((value >> 16) & 0xFF)
	bytes.append((value >> 8) & 0xFF)
	bytes.append(value & 0xFF)
	return bytes

static func encode_f32(value: float) -> PackedByteArray:
	"""Encode 32-bit float"""
	var bytes = PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, value)
	return bytes

static func encode_vector2(vec: Vector2) -> PackedByteArray:
	"""Encode Vector2 as two 32-bit floats (8 bytes)"""
	var bytes = PackedByteArray()
	bytes.append_array(encode_f32(vec.x))
	bytes.append_array(encode_f32(vec.y))
	return bytes

static func encode_string(text: String) -> PackedByteArray:
	"""Encode string with length prefix"""
	var bytes = PackedByteArray()
	var text_bytes = text.to_utf8_buffer()
	bytes.append_array(encode_u16(text_bytes.size()))
	bytes.append_array(text_bytes)
	return bytes

## ========== DECODING FUNCTIONS ==========

static func decode_u8(data: PackedByteArray, offset: int) -> int:
	"""Decode unsigned 8-bit integer"""
	if offset >= data.size():
		push_error("PacketEncoder: decode_u8 offset out of bounds")
		return 0
	return data[offset]

static func decode_u16(data: PackedByteArray, offset: int) -> int:
	"""Decode unsigned 16-bit integer"""
	if offset + 1 >= data.size():
		push_error("PacketEncoder: decode_u16 offset out of bounds")
		return 0
	return (data[offset] << 8) | data[offset + 1]

static func decode_u32(data: PackedByteArray, offset: int) -> int:
	"""Decode unsigned 32-bit integer"""
	if offset + 3 >= data.size():
		push_error("PacketEncoder: decode_u32 offset out of bounds")
		return 0
	return (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3]

static func decode_f32(data: PackedByteArray, offset: int) -> float:
	"""Decode 32-bit float"""
	if offset + 3 >= data.size():
		push_error("PacketEncoder: decode_f32 offset out of bounds")
		return 0.0
	return data.decode_float(offset)

static func decode_vector2(data: PackedByteArray, offset: int) -> Vector2:
	"""Decode Vector2 from two 32-bit floats"""
	if offset + 7 >= data.size():
		push_error("PacketEncoder: decode_vector2 offset out of bounds")
		return Vector2.ZERO
	var x = decode_f32(data, offset)
	var y = decode_f32(data, offset + 4)
	return Vector2(x, y)

static func decode_string(data: PackedByteArray, offset: int) -> String:
	"""Decode string with length prefix"""
	if offset + 1 >= data.size():
		push_error("PacketEncoder: decode_string offset out of bounds")
		return ""
	var length = decode_u16(data, offset)
	if offset + 2 + length > data.size():
		push_error("PacketEncoder: decode_string length exceeds data size")
		return ""
	var text_bytes = data.slice(offset + 2, offset + 2 + length)
	return text_bytes.get_string_from_utf8()

## ========== HELPER FUNCTIONS ==========

static func get_class_id(cls_name: String) -> int:
	"""Map class names to single-byte IDs"""
	match cls_name:
		"Warrior": return 1
		"Mage": return 2
		"Rogue": return 3
		"Cleric": return 4
		"Ranger": return 5
		"Paladin": return 6
		"Goblin": return 10
		"Orc": return 11
		"Skeleton": return 12
		"OrcWarrior": return 13
		"DarkMage": return 14
		"EliteGuard": return 15
		"RogueBandit": return 16
		_: return 0  # Unknown

static func get_class_name(cls_id: int) -> String:
	"""Map single-byte IDs back to class names"""
	match cls_id:
		1: return "Warrior"
		2: return "Mage"
		3: return "Rogue"
		4: return "Cleric"
		5: return "Ranger"
		6: return "Paladin"
		10: return "Goblin"
		11: return "Orc"
		12: return "Skeleton"
		13: return "OrcWarrior"
		14: return "DarkMage"
		15: return "EliteGuard"
		16: return "RogueBandit"
		_: return "Unknown"

## ========== PACKET BUILDERS ==========

static func build_player_input_packet(up: bool, down: bool, left: bool, right: bool, timestamp: int) -> PackedByteArray:
	"""Build PLAYER_INPUT packet (6 bytes)
	Packs 4 boolean inputs into 1 byte as bit flags"""
	var packet = PackedByteArray()
	packet.append(PacketTypes.Type.PLAYER_INPUT)

	# Pack input flags into single byte (bit 0=up, 1=down, 2=left, 3=right)
	var flags = 0
	if up: flags |= (1 << 0)
	if down: flags |= (1 << 1)
	if left: flags |= (1 << 2)
	if right: flags |= (1 << 3)
	packet.append(flags)

	# Add timestamp (4 bytes)
	packet.append_array(encode_u32(timestamp))
	return packet  # Total: 6 bytes

static func build_player_position_packet(peer_id: int, position: Vector2) -> PackedByteArray:
	"""Build PLAYER_POSITION packet (11 bytes)"""
	var packet = PackedByteArray()
	packet.append(PacketTypes.Type.PLAYER_POSITION)
	packet.append_array(encode_u16(peer_id))
	packet.append_array(encode_vector2(position))
	return packet

static func build_npc_position_packet(npc_id: int, position: Vector2) -> PackedByteArray:
	"""Build NPC_POSITION packet (11 bytes)"""
	var packet = PackedByteArray()
	packet.append(PacketTypes.Type.NPC_POSITION)
	packet.append_array(encode_u16(npc_id))
	packet.append_array(encode_vector2(position))
	return packet

static func build_bulk_npc_positions_packet(npc_list: Array) -> PackedByteArray:
	"""Build bulk packet with multiple NPC positions (uses BULK_POSITIONS type)
	Format: type(1) + count(2) + [npc_id(2) + x(4) + y(4)] * count
	Reduces 100 NPCs × 1000 players from 2M packets/sec to ~2K bulk packets/sec"""
	var packet = PackedByteArray()

	# Packet type
	packet.append(PacketTypes.Type.BULK_POSITIONS)

	# Count of NPCs
	packet.append_array(encode_u16(npc_list.size()))

	# For each NPC: ID (uint16) + position (2x float32)
	for npc_data in npc_list:
		var npc_id: int = npc_data.id
		var npc_pos: Vector2 = npc_data.pos

		packet.append_array(encode_u16(npc_id))
		packet.append_array(encode_vector2(npc_pos))

	return packet

static func build_bulk_positions_packet(positions: Dictionary) -> PackedByteArray:
	"""Build BULK_POSITIONS packet with multiple entities"""
	var packet = PackedByteArray()
	packet.append(PacketTypes.Type.BULK_POSITIONS)
	packet.append_array(encode_u16(positions.size()))

	for entity_id in positions:
		packet.append_array(encode_u16(entity_id))
		packet.append_array(encode_vector2(positions[entity_id]))

	return packet

static func build_entity_state_packet(entity_id: int, state: int, direction: int, velocity: Vector2) -> PackedByteArray:
	"""Build ENTITY_STATE packet (animation, direction, velocity)"""
	var packet = PackedByteArray()
	packet.append(PacketTypes.Type.ENTITY_STATE)
	packet.append_array(encode_u16(entity_id))
	packet.append(state)
	packet.append(direction)
	# Compress velocity to 16-bit signed integers (-32k to +32k range)
	packet.append_array(encode_u16(int(velocity.x * 10.0) & 0xFFFF))
	packet.append_array(encode_u16(int(velocity.y * 10.0) & 0xFFFF))
	return packet

static func build_combat_start_packet(combat_id: int, npc_id: int, enemy_squad: Array) -> PackedByteArray:
	"""Build COMBAT_START packet (binary optimized)
	Format: type(1) + combat_id(2) + npc_id(2) + enemy_count(1) + [enemies...]
	Per enemy (15 bytes): level(1) + hp(2) + max_hp(2) + attack(2) + defense(2) + class_id(1) + name_suffix(1) + padding(4)
	Total: ~5-50 bytes (vs 1500+ bytes for Dictionary RPC)"""
	var packet = PackedByteArray()
	packet.append(PacketTypes.Type.COMBAT_START)
	packet.append_array(encode_u16(combat_id))
	packet.append_array(encode_u16(npc_id))
	packet.append(enemy_squad.size())

	# Encode each enemy
	for enemy in enemy_squad:
		packet.append(enemy.get("level", 1))
		packet.append_array(encode_u16(enemy.get("hp", 100)))
		packet.append_array(encode_u16(enemy.get("max_hp", 100)))
		packet.append_array(encode_u16(enemy.get("attack", 10)))
		packet.append_array(encode_u16(enemy.get("defense", 10)))

		# Encode class as single byte (map common classes to IDs)
		# Try "class" first, then extract base name from "character_name" (e.g., "Goblin 1" -> "Goblin")
		var enemy_class = enemy.get("class", "")
		if enemy_class.is_empty():
			var full_name = enemy.get("character_name", "Rogue")
			# Extract base name by removing number suffix (e.g., "Goblin 1" -> "Goblin")
			var parts = full_name.split(" ")
			enemy_class = parts[0] if parts.size() > 0 else "Rogue"
		var cls_id = get_class_id(enemy_class)
		packet.append(cls_id)

		# Extract name suffix (e.g., "Rogue 2" -> 2)
		var name = enemy.get("name", "Enemy 1")
		var name_suffix = 1
		var parts = name.split(" ")
		if parts.size() > 1:
			name_suffix = int(parts[-1])
		packet.append(name_suffix)

		# Padding for future expansion (magic power, speed, etc.)
		packet.append_array(encode_u32(0))

	return packet

static func build_combat_state_packet(entity_id: int, hp: int, max_hp: int, effects: int) -> PackedByteArray:
	"""Build COMBAT_STATE packet (HP and status updates)
	Format: type(1) + entity_id(2) + hp(2) + max_hp(2) + effects(2)
	Total: 9 bytes"""
	var packet = PackedByteArray()
	packet.append(PacketTypes.Type.COMBAT_STATE)
	packet.append_array(encode_u16(entity_id))
	packet.append_array(encode_u16(hp))
	packet.append_array(encode_u16(max_hp))
	packet.append_array(encode_u16(effects))
	return packet

## ========== PACKET PARSERS ==========

static func parse_player_input_packet(data: PackedByteArray) -> Dictionary:
	"""Parse PLAYER_INPUT packet"""
	if data.size() < 6:
		push_error("PacketEncoder: Invalid PLAYER_INPUT packet size")
		return {}

	# Extract bit flags
	var flags = data[1]
	var up = (flags & (1 << 0)) != 0
	var down = (flags & (1 << 1)) != 0
	var left = (flags & (1 << 2)) != 0
	var right = (flags & (1 << 3)) != 0

	# Extract timestamp
	var timestamp = decode_u32(data, 2)

	return {
		"up": up,
		"down": down,
		"left": left,
		"right": right,
		"timestamp": timestamp
	}

static func parse_player_position_packet(data: PackedByteArray) -> Dictionary:
	"""Parse PLAYER_POSITION packet"""
	if data.size() < 11:
		push_error("PacketEncoder: Invalid PLAYER_POSITION packet size")
		return {}

	return {
		"peer_id": decode_u16(data, 1),
		"position": decode_vector2(data, 3)
	}

static func parse_npc_position_packet(data: PackedByteArray) -> Dictionary:
	"""Parse NPC_POSITION packet"""
	if data.size() < 11:
		push_error("PacketEncoder: Invalid NPC_POSITION packet size")
		return {}

	return {
		"npc_id": decode_u16(data, 1),
		"position": decode_vector2(data, 3)
	}

static func parse_bulk_positions_packet(data: PackedByteArray) -> Dictionary:
	"""Parse BULK_POSITIONS packet"""
	if data.size() < 3:
		push_error("PacketEncoder: Invalid BULK_POSITIONS packet size")
		return {}

	var count = decode_u16(data, 1)
	var positions = {}
	var offset = 3

	for i in range(count):
		if offset + 10 > data.size():
			push_error("PacketEncoder: BULK_POSITIONS packet truncated")
			break

		var entity_id = decode_u16(data, offset)
		var position = decode_vector2(data, offset + 2)
		positions[entity_id] = position
		offset += 10

	return positions

static func parse_combat_start_packet(data: PackedByteArray) -> Dictionary:
	"""Parse COMBAT_START packet"""
	if data.size() < 6:
		push_error("PacketEncoder: Invalid COMBAT_START packet size")
		return {}

	var combat_id = decode_u16(data, 1)
	var npc_id = decode_u16(data, 3)
	var enemy_count = data[5]

	var enemy_squad = []
	var offset = 6

	for i in range(enemy_count):
		if offset + 14 > data.size():
			push_error("PacketEncoder: COMBAT_START packet truncated")
			break

		var level = data[offset]
		var hp = decode_u16(data, offset + 1)
		var max_hp = decode_u16(data, offset + 3)
		var attack = decode_u16(data, offset + 5)
		var defense = decode_u16(data, offset + 7)
		var cls_id = data[offset + 9]
		var name_suffix = data[offset + 10]
		# offset + 11-14 is padding (4 bytes)

		var enemy_class = get_class_name(cls_id)

		enemy_squad.append({
			"level": level,
			"hp": hp,
			"max_hp": max_hp,
			"attack": attack,
			"defense": defense,
			"class": enemy_class,
			"name": enemy_class + " " + str(name_suffix)
		})

		offset += 15  # 15 bytes per enemy

	return {
		"combat_id": combat_id,
		"npc_id": npc_id,
		"enemy_squad": enemy_squad
	}

## ========== DEBUG UTILITIES ==========

static func packet_to_hex(data: PackedByteArray) -> String:
	"""Convert packet to hex string for debugging"""
	var hex = ""
	for byte in data:
		hex += "%02X " % byte
	return hex.strip_edges()

static func validate_packet(data: PackedByteArray) -> bool:
	"""Validate packet has correct structure"""
	if data.size() < 1:
		return false

	var packet_type = data[0]
	if not PacketTypes.PACKET_SIZE.has(packet_type):
		return true  # Variable size packet

	var expected_size = PacketTypes.PACKET_SIZE[packet_type]
	return data.size() == expected_size
