class_name MultiplayerManager
extends Node

## ============================================================================
## MULTIPLAYER MANAGER
## ============================================================================
## Handles all multiplayer client functionality including:
## - Client connection and spawning
## - Position update sending and receiving
## - Remote player sprite management
## - Binary packet processing
## - Chat message routing
## - Combat initialization from server
## ============================================================================

# Preloaded resources
const RemotePlayer = preload("res://source/client/gameplay/remote_player.tscn")
const ChatUI = preload("res://source/client/ui/chat_ui.tscn")

# Dependencies (injected during initialization)
var game_world: Node2D
var test_character: CharacterBody2D
var character_sprite_manager: Node
var input_handler_manager: Node

# Multiplayer state
var client: Node  # WorldClient or ServerConnection reference
var remote_players: Dictionary = {}  # peer_id -> RemotePlayer instance
var chat_ui: Control
var name_label: Label
var my_peer_id: int = 0
var my_username: String = ""
var my_character_data: Dictionary = {}
var team_npc_ids: Array = []  # NPC IDs assigned to player's team

# Sprite cache references (shared from parent controller)
var spriteframes_cache: Dictionary = {}
var character_data_cache: Dictionary = {}
var current_character_data: Dictionary = {}

# Binary packet tracking
var binary_packet_count: int = 0

func initialize(
	_game_world: Node2D,
	_test_character: CharacterBody2D,
	_character_sprite_manager: Node,
	_spriteframes_cache: Dictionary,
	_character_data_cache: Dictionary
) -> void:
	"""Initialize manager with dependency injection."""
	game_world = _game_world
	test_character = _test_character
	character_sprite_manager = _character_sprite_manager
	spriteframes_cache = _spriteframes_cache
	character_data_cache = _character_data_cache

func set_input_handler_manager(mgr: Node) -> void:
	input_handler_manager = mgr

## ============================================================================
## MULTIPLAYER INITIALIZATION
## ============================================================================

func setup_multiplayer(on_character_loaded: Callable) -> void:
	"""Initialize multiplayer client and connect to server"""
	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		print("[MULTIPLAYER] ERROR: No GameState found - running in offline mode")
		return

	my_username = game_state.get("current_username")
	my_character_data = game_state.get("current_character")
	var client_ref = game_state.get("client")

	# Validate client reference
	if not is_instance_valid(client_ref):
		print("[MULTIPLAYER] ERROR: Client connection was freed!")
		return

	if not client_ref:
		print("[MULTIPLAYER] ERROR: No client connection in GameState!")
		return

	client = client_ref
	game_state.world_client = client_ref

	# Wait for connection, then request spawn
	await get_tree().create_timer(0.5).timeout
	my_peer_id = multiplayer.get_unique_id()

	# Load player's class sprite
	var player_class = my_character_data.get("class_name", "")
	var character_id = my_character_data.get("character_id", "")

	if player_class.is_empty():
		print("[MULTIPLAYER] ERROR: No class_name in character data!")
		return

	if character_id.is_empty():
		print("[MULTIPLAYER] ERROR: No character_id in character data!")
		return

	if not my_character_data.has("animations"):
		print("[MULTIPLAYER] ERROR: Character has NO animations!")

	# Clear sprite caches to ensure fresh load
	spriteframes_cache.clear()
	character_data_cache.clear()

	current_character_data = my_character_data

	# Setup character sprite
	if on_character_loaded.is_valid():
		on_character_loaded.call()

	test_character.modulate = Color.WHITE

	# Create UI
	create_name_label()
	create_chat_ui()

	# Request spawn
	print("[MULTIPLAYER] Requesting spawn for character: ", character_id)
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if server_conn:
		# CRITICAL FIX: Use rpc_id(1) to send to server
		server_conn.request_spawn_character.rpc_id(1, my_username, character_id)
	else:
		print("[MULTIPLAYER] ERROR: ServerConnection not found!")

func create_name_label() -> void:
	"""Create name label above local player"""
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-50, -75)
	name_label.size = Vector2(100, 20)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.text = my_character_data.get("name", "Player")
	test_character.add_child(name_label)

func create_chat_ui() -> void:
	"""Create chat UI"""
	chat_ui = ChatUI.instantiate()
	get_parent().add_child(chat_ui)

	chat_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chat_ui.z_index = 100
	chat_ui.mouse_filter = Control.MOUSE_FILTER_PASS

	chat_ui.message_sent.connect(_on_chat_message_sent)

	# Add welcome messages
	if chat_ui.has_method("add_server_message"):
		chat_ui.add_server_message("Welcome to Odysseys Revival!")
	if chat_ui.has_method("add_system_message"):
		chat_ui.add_system_message("Press ENTER to open chat")
		chat_ui.add_system_message("Type your message and press ENTER to send")

## ============================================================================
## POSITION UPDATES
## ============================================================================

func send_player_input(packet: PackedByteArray) -> void:
	"""Send binary input packet to server via unreliable RPC"""
	if not client or not multiplayer.has_multiplayer_peer():
		return

	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if server_conn and is_instance_valid(server_conn) and multiplayer.has_multiplayer_peer():
		server_conn.binary_input.rpc_id(1, packet)
	elif not multiplayer.has_multiplayer_peer():
		print("[MULTIPLAYER] ERROR: Cannot send input - no multiplayer peer connected")

## ============================================================================
## CHAT MESSAGE HANDLING
## ============================================================================

func _on_chat_message_sent(message: String) -> void:
	"""Player sent a chat message - send to server via RPC"""
	if not client or not multiplayer.has_multiplayer_peer():
		print("[CHAT] ERROR: Not connected to server")
		if chat_ui and chat_ui.has_method("add_system_message"):
			chat_ui.add_system_message("Not connected to server")
		return

	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if server_conn:
		# CRITICAL FIX: Use rpc_id(1) to send to server
		server_conn.send_chat_message.rpc_id(1, message)
	else:
		print("[CHAT] ERROR: ServerConnection not found!")

func handle_chat_message(player_name: String, message: String) -> void:
	"""Receive chat message from server"""
	if chat_ui and chat_ui.has_method("add_message"):
		chat_ui.add_message(player_name, message)

func receive_chat_message(player_name: String, message: String) -> void:
	"""Received chat message from server - display in chat UI (called by ServerConnection)"""
	if chat_ui:
		if chat_ui.has_method("add_message"):
			chat_ui.add_message(player_name, message)
		else:
			print("[CHAT] ERROR: chat_ui doesn't have add_message method!")
	else:
		print("[CHAT] ERROR: chat_ui is null!")

## ============================================================================
## SPAWN/DESPAWN HANDLERS
## ============================================================================

func handle_spawn_accepted(player_data: Dictionary, on_character_loaded: Callable) -> void:
	"""Server accepted our spawn request"""
	print("[MULTIPLAYER] Spawn accepted")

	# Update character data with server's authoritative version
	current_character_data = player_data

	# Extract team assignment from server
	team_npc_ids = player_data.get("team_npc_ids", [])

	# Set player position from server's authoritative data
	var spawn_pos = player_data.get("position", Vector2(1344, 960))
	if test_character:
		test_character.position = spawn_pos
		print("[MULTIPLAYER] Set player position from server: ", spawn_pos)

	# Reload sprite with server's character data
	if on_character_loaded.is_valid():
		on_character_loaded.call()

	if chat_ui and chat_ui.has_method("add_system_message"):
		var team_msg = "Team: %d NPCs assigned" % team_npc_ids.size() if team_npc_ids.size() > 0 else "Team: No NPCs available"
		var char_name = player_data.get("name", "Unknown")
		chat_ui.add_system_message("Entered world as " + char_name + " - " + team_msg)

func handle_spawn_rejected(reason: String) -> void:
	"""Server rejected our spawn request"""
	print("[MULTIPLAYER] Spawn rejected: ", reason)
	if chat_ui and chat_ui.has_method("add_system_message"):
		chat_ui.add_system_message("Spawn failed: " + reason)

func handle_player_spawned(peer_id: int, player_data: Dictionary) -> void:
	"""Another player spawned in the world"""
	if peer_id == my_peer_id:
		return

	print("[MULTIPLAYER] Player spawned: ", player_data.character_name)

	# Check if player already exists
	if remote_players.has(peer_id):
		var remote = remote_players[peer_id]
		if is_instance_valid(remote):
			remote.setup(player_data)
		return

	# Create new remote player
	var remote = RemotePlayer.instantiate()
	game_world.add_child(remote)
	remote.setup(player_data)
	remote.position = player_data.get("position", Vector2(400, 300))
	remote_players[peer_id] = remote

	if chat_ui and chat_ui.has_method("add_system_message"):
		chat_ui.add_system_message(player_data.character_name + " joined the world")

func handle_player_despawned(peer_id: int) -> void:
	"""A player left the world"""
	if not remote_players.has(peer_id):
		return

	var remote = remote_players[peer_id]
	var player_name = "Unknown"
	if is_instance_valid(remote) and remote.has_method("get"):
		player_name = remote.character_name
		remote.queue_free()

	remote_players.erase(peer_id)

	if chat_ui and chat_ui.has_method("add_system_message"):
		chat_ui.add_system_message(player_name + " left the world")

## ============================================================================
## POSITION SYNC HANDLERS
## ============================================================================

@rpc
func sync_positions(positions: Dictionary) -> void:
	"""Server sent position updates for all players"""
	for peer_id in positions:
		if peer_id == my_peer_id:
			continue  # Skip our own position

		if not remote_players.has(peer_id):
			continue  # Player not spawned yet

		var remote = remote_players[peer_id]
		if is_instance_valid(remote) and remote.has_method("update_position"):
			remote.update_position(positions[peer_id])

func handle_binary_positions(packet: PackedByteArray, server_npcs: Dictionary) -> void:
	"""Handle binary position packet from server (via unreliable RPC)"""
	if packet.size() < 1:
		return

	binary_packet_count += 1
	if binary_packet_count == 1:
		print("[BINARY] First binary packet received, size=%d" % packet.size())

	var packet_type = packet[0]

	if packet_type == PacketTypes.Type.BULK_POSITIONS:
		var positions = PacketEncoder.parse_bulk_positions_packet(packet)

		# Update entities with new positions (players OR NPCs)
		for entity_id in positions:
			var pos = positions[entity_id]

			# Try players first
			if entity_id == my_peer_id:
				continue  # Skip our own position

			if remote_players.has(entity_id):
				# Update player position
				var remote = remote_players[entity_id]
				if is_instance_valid(remote) and remote.has_method("update_position"):
					remote.update_position(pos)

			# Also check NPCs
			elif server_npcs.has(entity_id):
				# Update NPC position
				var npc = server_npcs[entity_id]
				if is_instance_valid(npc):
					var old_pos = npc.position
					npc.position = pos

					# Update animation based on movement
					var movement_delta = pos - old_pos
					if movement_delta.length() > 1.0:
						# NPC is moving - play walk animation
						if abs(movement_delta.x) > abs(movement_delta.y):
							npc.current_direction = "right" if movement_delta.x > 0 else "left"
						else:
							npc.current_direction = "down" if movement_delta.y > 0 else "up"

						# Play walk animation
						var anim_name = "walk_" + npc.current_direction
						if npc.animated_sprite and npc.animated_sprite.sprite_frames.has_animation(anim_name):
							if not npc.animated_sprite.is_playing() or npc.animated_sprite.animation != anim_name:
								npc.animated_sprite.play(anim_name)
					else:
						# NPC is idle - pause animation
						var anim_name = "walk_" + npc.current_direction
						if npc.animated_sprite and npc.animated_sprite.sprite_frames.has_animation(anim_name):
							npc.animated_sprite.play(anim_name)
							npc.animated_sprite.pause()
							npc.animated_sprite.frame = 0

	elif packet_type == PacketTypes.Type.PREDICTION_ACK:
		var data = PacketEncoder.parse_prediction_ack_packet(packet)
		if data:
			var peer_id = data.peer_id
			if peer_id == my_peer_id and input_handler_manager:
				if input_handler_manager.has_method("reconcile"):
					input_handler_manager.reconcile(data.sequence, data.position)

	elif packet_type == PacketTypes.Type.NPC_POSITION:
		var npc_data = PacketEncoder.parse_npc_position_packet(packet)
		if npc_data:
			var npc_id = npc_data.npc_id
			var position = npc_data.position

			if binary_packet_count <= 5:
				print("[NPC_POS] Received position for NPC #%d: %s" % [npc_id, str(position)])

			# Update NPC position if it exists (server-authoritative)
			if server_npcs.has(npc_id):
				var npc = server_npcs[npc_id]
				if is_instance_valid(npc):
					if not npc.animated_sprite:
						print("[NPC_CLIENT] WARNING: NPC #%d has no animated_sprite!" % npc_id)
						return
					# Update position from server
					var old_pos = npc.position
					npc.position = position

					# Calculate movement and update animation
					var movement_delta = position - old_pos
					if binary_packet_count <= 5:
						print("[NPC_ANIM] NPC #%d delta: %s (length: %.2f)" % [npc_id, str(movement_delta), movement_delta.length()])

					if movement_delta.length() > 1.0:
						# NPC is moving - determine direction and play walk animation
						if abs(movement_delta.x) > abs(movement_delta.y):
							npc.current_direction = "right" if movement_delta.x > 0 else "left"
						else:
							npc.current_direction = "down" if movement_delta.y > 0 else "up"

						# Play walk animation
						var anim_name = "walk_" + npc.current_direction
						if npc.animated_sprite.sprite_frames.has_animation(anim_name):
							if not npc.animated_sprite.is_playing() or npc.animated_sprite.animation != anim_name:
								npc.animated_sprite.play(anim_name)
					else:
						# NPC is idle - pause on first frame
						var anim_name = "walk_" + npc.current_direction
						if npc.animated_sprite.sprite_frames.has_animation(anim_name):
							npc.animated_sprite.play(anim_name)
							npc.animated_sprite.pause()
							npc.animated_sprite.frame = 0

## ============================================================================
## COMBAT HANDLERS
## ============================================================================

func handle_binary_combat_start(packet: PackedByteArray, server_npcs: Dictionary) -> void:
	"""Server sends binary combat packet - decode and start combat"""
	# Decode binary packet
	var combat_data = PacketEncoder.parse_combat_start_packet(packet)

	if combat_data.is_empty():
		print("[COMBAT_CLIENT] ERROR: Failed to decode combat packet!")
		return

	var combat_id = combat_data.combat_id
	var npc_id = combat_data.npc_id
	var enemy_squad = combat_data.enemy_squad

	# Get NPC name from local NPC data (we already have it)
	var npc_name = "Unknown NPC"
	if server_npcs.has(npc_id):
		npc_name = server_npcs[npc_id].npc_name

	print("[COMBAT_CLIENT] Starting combat #%d with NPC #%d '%s' (%d enemies) - Packet size: %d bytes" % [
		combat_id,
		npc_id,
		npc_name,
		enemy_squad.size(),
		packet.size()
	])

	print("[COMBAT_CLIENT] Enemy squad:")
	for i in range(enemy_squad.size()):
		var enemy = enemy_squad[i]
		print("  %d. %s (Lv %d) - HP: %d/%d, ATK: %d, DEF: %d" % [
			i + 1,
			enemy.get("name", "Unknown"),
			enemy.get("level", 1),
			enemy.get("hp", 0),
			enemy.get("max_hp", 0),
			enemy.get("attack", 0),
			enemy.get("defense", 0)
		])

	# Store combat data in GameState for battle scene to access
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		game_state.set_meta("server_combat_data", combat_data)
		game_state.set_meta("in_server_battle", true)
		print("[COMBAT_CLIENT] Combat data stored in GameState")

		# Save player position before battle
		if test_character and is_instance_valid(test_character):
			game_state.pre_battle_position = test_character.position
			print("[COMBAT_CLIENT] Saved player position before battle: ", game_state.pre_battle_position)
		else:
			print("[COMBAT_CLIENT] WARNING: Could not save player position - test_character not found")

		# Preserve client connection across scene change
		var server_conn = get_tree().root.get_node_or_null("ServerConnection")
		if server_conn:
			game_state.client = server_conn
			print("[COMBAT_CLIENT] Preserved ServerConnection for battle scene")

		# CRITICAL: Preserve WorldClient to prevent disconnection during scene change
		var world_client = game_state.world_client

		if world_client and is_instance_valid(world_client):
			if world_client.get_parent() != get_tree().root:
				print("[COMBAT_CLIENT] Moving WorldClient to /root to preserve connection")
				var old_parent = world_client.get_parent()
				old_parent.remove_child(world_client)
				get_tree().root.add_child(world_client)
				print("[COMBAT_CLIENT] ✓ WorldClient moved to /root successfully")
			else:
				print("[COMBAT_CLIENT] WorldClient already in /root")
		else:
			print("[COMBAT_CLIENT] ⚠️ WARNING: WorldClient not found in GameState - connection may be lost")

		# Store NPC data before battle so we can restore them when returning
		game_state.server_npcs_data = []
		for id in server_npcs:
			var npc = server_npcs[id]
			if is_instance_valid(npc):
				game_state.server_npcs_data.append({
					"npc_id": id,
					"npc_name": npc.npc_name,
					"npc_type": npc.npc_type,
					"position": npc.position,
					"spawn_position": npc.spawn_position
				})
		print("[COMBAT_CLIENT] Stored %d NPCs for post-battle restoration" % game_state.server_npcs_data.size())
	else:
		print("[COMBAT_CLIENT] ERROR: GameState not found!")

	# NOTE: Battle scene loading is handled by RealtimeBattleLauncher via realtime_combat_network_service
	# DO NOT use change_scene_to_file here - it destroys the current map and prevents map cloning
	print("[COMBAT_CLIENT] Combat data stored - waiting for realtime battle system to launch")

func handle_combat_round_results(combat_id: int, results: Dictionary) -> void:
	"""Server sends combat round results - forward to battle_window if active"""
	var battle_window = get_tree().root.get_node_or_null("BattleWindow")
	if battle_window:
		battle_window.receive_round_results(results)
	else:
		print("[COMBAT_CLIENT] ERROR: BattleWindow not found!")

## ============================================================================
## ACCESSORS
## ============================================================================

func get_team_npc_ids() -> Array:
	"""Get list of NPC IDs assigned to player's team"""
	return team_npc_ids

func get_chat_ui() -> Control:
	"""Get reference to chat UI"""
	return chat_ui

func is_chat_open() -> bool:
	"""Check if chat is currently open"""
	return chat_ui != null and chat_ui.is_chat_open
