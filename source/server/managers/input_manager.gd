## Input Manager - Server-authoritative input processing and movement validation
## Handles all player input (Dictionary RPC and binary packets), validates movement, and updates positions
extends Node
class_name InputManager

# Preload PacketEncoder
const PacketEncoder = preload("res://source/common/network/packet_encoder.gd")

# ========== REFERENCES ==========
var server_world  # Reference to main server_world
var player_manager  # Reference to player_manager
var input_processor  # Reference to input_processor (calculates movement)
var movement_validator  # Reference to movement_validator (validates movement)
var spatial_manager  # Reference to spatial_manager (interest management)
var anti_cheat  # Reference to anti_cheat (cheat detection)
var tick_rate: float  # Server tick rate for movement calculations

# ========== INITIALIZATION ==========

func initialize(server_ref):
	"""Initialize input manager with server references"""
	server_world = server_ref
	player_manager = server_ref.player_manager
	input_processor = server_ref.input_processor
	movement_validator = server_ref.movement_validator
	spatial_manager = server_ref.spatial_manager
	anti_cheat = server_ref.anti_cheat
	tick_rate = server_ref.tick_rate
	print("[InputManager] Initialized")


# ========== DICTIONARY INPUT HANDLING (Old RPC method) ==========

@rpc("any_peer")
func handle_player_input(input: Dictionary):
	"""
	Receive input from client and calculate authoritative position (Dictionary format)

	SERVER-AUTHORITATIVE INPUT PROCESSING:
	- Client sends input intentions (move_left, move_up, etc.)
	- Server validates input structure
	- Server calculates new position based on input
	- Server validates movement (speed, collision, teleport detection)
	- Server updates position only if valid
	- Client never directly sets their position

	This prevents speed hacks, teleportation, and collision bypassing

	Args:
		input: Dictionary with input state (move_left, move_right, move_up, move_down, delta)
	"""
	var peer_id = multiplayer.get_remote_sender_id()

	# VALIDATION: Check input structure
	if not input_processor or not input_processor.validate_input(input):
		if anti_cheat:
			anti_cheat.log_violation(peer_id, "invalid_input", 1)
		return

	# VALIDATION: Check if player exists
	if not player_manager or not player_manager.player_positions.has(peer_id):
		return

	# Get current position from server state
	var current_position = player_manager.player_positions[peer_id]

	# SERVER-AUTHORITATIVE: Calculate new position server-side
	var result = input_processor.process_input(current_position, input, tick_rate)
	var new_position = result.position

	# Validate and apply movement
	apply_movement(peer_id, current_position, new_position, 0)


# ========== BINARY INPUT HANDLING (Optimized) ==========

func handle_binary_input(peer_id: int, packet: PackedByteArray):
	"""
	Handle binary input packet from client (optimized for network efficiency)

	Binary packets are ~8 bytes vs ~50+ bytes for Dictionary RPC
	This is the preferred input method for MMO scale

	Packet format: [type:u8, flags:u8, seq:u16, timestamp:u32]
	- type: Packet type (PLAYER_INPUT = 0x01)
	- flags: Bitmask (0x01=left, 0x02=right, 0x04=up, 0x08=down)
	- seq: Sequence number for reconciliation
	- timestamp: Time in milliseconds

	Args:
		peer_id: ID of peer sending input
		packet: Binary packet data
	"""
	# VALIDATION: Check if player exists FIRST (silently ignore if not spawned yet)
	if not player_manager or not player_manager.player_positions.has(peer_id):
		return

	# VALIDATION: Check packet size (minimum 8 bytes)
	if packet.size() < 8:
		if anti_cheat:
			anti_cheat.log_violation(peer_id, "invalid_input", 1)
		return

	# Parse binary input packet
	var input = PacketEncoder.parse_player_input_packet(packet)
	if input.is_empty():
		if anti_cheat:
			anti_cheat.log_violation(peer_id, "invalid_input", 1)
		return

	# VALIDATION: Check input structure (same as Dictionary method)
	if not input_processor or not input_processor.validate_input(input):
		if anti_cheat:
			anti_cheat.log_violation(peer_id, "invalid_input", 1)
		return

	# Get current position from server state
	var current_position = player_manager.player_positions[peer_id]

	# SERVER-AUTHORITATIVE: Calculate new position server-side
	var result = input_processor.process_input(current_position, input, tick_rate)
	var new_position = result.position
	var sequence = input.get("sequence", 0)

	# Validate and apply movement
	apply_movement(peer_id, current_position, new_position, sequence)


# ========== MOVEMENT VALIDATION & APPLICATION ==========

func apply_movement(peer_id: int, current_position: Vector2, new_position: Vector2, sequence: int = 0):
	"""
	Validate movement and update player position if valid

	ANTI-CHEAT VALIDATION:
	- Speed check: Ensures player isn't moving faster than max_speed
	- Teleport check: Detects impossible position jumps
	- Collision check: Ensures player isn't moving through walls
	- History tracking: Records position history for pattern detection

	Args:
		peer_id: ID of player making the move
		current_position: Current server-side position
		new_position: Requested new position
		sequence: Input sequence number for reconciliation
	"""
	# VALIDATION: Check movement validity
	if movement_validator:
		var validation = movement_validator.validate_movement(current_position, new_position, tick_rate)

		if not validation.valid:
			# ANTI-CHEAT: Log violation with reason and severity
			if anti_cheat:
				anti_cheat.log_violation(peer_id, validation.reason, validation.severity, validation)

			# REJECT MOVEMENT: Keep old position (client will be corrected)
			# TODO: Send explicit correction/reject packet?
			# For now, the next position update will correct them.
			return

	# MOVEMENT IS VALID: Update server-side position
	player_manager.player_positions[peer_id] = new_position

	# Update spatial manager for interest management
	if spatial_manager:
		spatial_manager.update_entity_position(peer_id, new_position)

	# Update anti-cheat position history for pattern detection
	if anti_cheat:
		anti_cheat.update_position_history(peer_id, new_position)

	# Update player data dictionary
	if player_manager.connected_players.has(peer_id):
		player_manager.connected_players[peer_id]["position"] = new_position
		player_manager.connected_players[peer_id]["last_sequence"] = sequence

	# Send ACK to client for reconciliation
	if server_world and server_world.network_handler:
		server_world.network_handler.send_prediction_ack(peer_id, sequence, new_position)


# ========== FUTURE ENHANCEMENTS ==========
# TODO: Add input prediction reconciliation for smoother client movement
# TODO: Add input buffering for laggy connections
# TODO: Add movement smoothing for spectators
# TODO: Add movement state tracking (walking, running, jumping)
# TODO: Add stamina system for movement costs
