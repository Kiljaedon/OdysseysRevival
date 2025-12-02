class_name PacketTypes
## Packet type definitions for binary network protocol
## Keeps network code organized and prevents magic numbers

enum Type {
	# Input packets (client → server, unreliable)
	PLAYER_INPUT = 0x01,         # Client keyboard input (5 bytes: type + flags + timestamp)

	# Movement packets (server → client, unreliable)
	PLAYER_POSITION = 0x02,      # Player position update
	NPC_POSITION = 0x03,         # Single NPC position
	BULK_POSITIONS = 0x04,       # Multiple entity positions
	PREDICTION_ACK = 0x05,       # Server acknowledgment of input with corrected position

	# Entity state (unreliable UDP)
	ENTITY_STATE = 0x10,         # Animation, direction, velocity
	COMBAT_STATE = 0x11,         # HP, status effects

	# Combat (reliable RPC but binary encoded for efficiency)
	COMBAT_START = 0x12,         # Start combat with NPC

	# Events (reliable TCP - use RPC)
	# These stay as RPC: login, spawn, chat, abilities

	# Spatial (unreliable UDP)
	ZONE_ENTER = 0x20,           # Entity entered zone
	ZONE_EXIT = 0x21,            # Entity left zone

	# Map Transitions (reliable - uses RPC underneath)
	MAP_TRANSITION_REQUEST = 0x30,   # Client requests map transition
	MAP_TRANSITION_APPROVED = 0x31,  # Server approves transition
	MAP_TRANSITION_DENIED = 0x32,    # Server denies transition
	PLAYER_LEFT_MAP = 0x33,          # Broadcast: player left this map
	PLAYER_JOINED_MAP = 0x34,        # Broadcast: player joined this map
}

## Packet size constants (for validation)
const PACKET_SIZE = {
	Type.PLAYER_INPUT: 8,        # type(1) + flags(1) + sequence(2) + timestamp(4)
	Type.PLAYER_POSITION: 11,    # type(1) + peer_id(2) + x(4) + y(4)
	Type.NPC_POSITION: 11,       # type(1) + npc_id(2) + x(4) + y(4)
	Type.PREDICTION_ACK: 13,     # type(1) + peer_id(2) + sequence(2) + x(4) + y(4)
	Type.ENTITY_STATE: 7,        # type(1) + entity_id(2) + state(1) + dir(1) + vel_x(2) + vel_y(2)
	Type.COMBAT_STATE: 9,        # type(1) + entity_id(2) + hp(2) + max_hp(2) + effects(2)
}

## Get packet type name for debugging
static func get_packet_name(type: int) -> String:
	match type:
		Type.PLAYER_INPUT: return "PLAYER_INPUT"
		Type.PLAYER_POSITION: return "PLAYER_POSITION"
		Type.NPC_POSITION: return "NPC_POSITION"
		Type.BULK_POSITIONS: return "BULK_POSITIONS"
		Type.PREDICTION_ACK: return "PREDICTION_ACK"
		Type.ENTITY_STATE: return "ENTITY_STATE"
		Type.COMBAT_STATE: return "COMBAT_STATE"
		Type.COMBAT_START: return "COMBAT_START"
		Type.ZONE_ENTER: return "ZONE_ENTER"
		Type.ZONE_EXIT: return "ZONE_EXIT"
		Type.MAP_TRANSITION_REQUEST: return "MAP_TRANSITION_REQUEST"
		Type.MAP_TRANSITION_APPROVED: return "MAP_TRANSITION_APPROVED"
		Type.MAP_TRANSITION_DENIED: return "MAP_TRANSITION_DENIED"
		Type.PLAYER_LEFT_MAP: return "PLAYER_LEFT_MAP"
		Type.PLAYER_JOINED_MAP: return "PLAYER_JOINED_MAP"
		_: return "UNKNOWN(%d)" % type
