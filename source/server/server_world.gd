################################################################################
## ODYSSEYS REVIVAL - SERVER WORLD (Main Orchestrator)
################################################################################
##
## PURPOSE:
## This is the central orchestrator for the Golden Sun MMO server. It acts as
## a lightweight coordinator that initializes, manages, and delegates work to
## specialized subsystem managers. The server_world does NOT implement game
## logic directly - it connects the pieces and provides RPC entry points.
##
## ARCHITECTURE PATTERN: Manager Orchestration
## - server_world.gd: Thin orchestrator layer (this file)
## - managers/: Specialized subsystems handling specific domains
## - RPC Proxy Pattern: RPCs received here, forwarded to appropriate managers
##
## MANAGED SUBSYSTEMS:
## 1. AuthenticationManager - Account creation, login, session management
## 2. PlayerManager - Character creation, spawning, state tracking
## 3. NPCManager - NPC spawning, AI behavior, movement
## 4. CombatManager - Combat resolution, battle management
## 5. ChatManager - Message handling and broadcasting
## 6. InputManager - Player input processing and validation
## 7. NetworkManager - Position broadcasting, delta compression
## 8. ConnectionManager - Connection lifecycle, cleanup
## 9. MapManager - Collision data loading and management
## 10. StatsManager - Server statistics and admin tools
## 11. UIManager - Admin UI rendering and updates
##
## ADDITIONAL SYSTEMS:
## - SpatialManager: Interest management (who sees what)
## - NetworkSync: Binary packet broadcasting system
## - InputProcessor: Server-authoritative movement processing
## - MovementValidator: Movement cheat detection
## - AntiCheat: General cheat detection system
##
## RPC PROXY PATTERN:
## Client sends RPC -> server_world receives it -> forwards to manager
## Example:
##   @rpc("any_peer")
##   func request_login(username: String, password: String):
##       if auth_manager:
##           auth_manager.request_login(username, password)
##
## This pattern keeps server_world clean and delegates domain logic to experts.
##
## MAIN RESPONSIBILITIES:
## 1. Initialize all subsystems in correct order
## 2. Provide main _process() tick for NPC updates and broadcasts
## 3. Route RPC calls to appropriate managers
## 4. Maintain convenience accessors for shared state
## 5. Centralize logging and monitoring
##
## WHAT THIS FILE DOES NOT DO:
## - Game logic implementation (delegated to managers)
## - Direct database access (uses GameDatabase singleton)
## - Complex state management (managers own their state)
## - Business rule enforcement (managers validate their domains)
##
## REFACTORING HISTORY:
## Originally 1,912 lines with tangled game logic. Refactored across 7 phases
## to extract 11 specialized managers, reducing this file to ~530 lines of
## pure orchestration code. Each manager is independently testable and focused
## on a single responsibility.
##
################################################################################

extends Node2D
# Preload all manager classes
const ConfigManager = preload("res://source/common/config/config_manager.gd")
const BaseServer = preload("res://source/common/network/base_server.gd")
const UIManager = preload("res://source/server/managers/ui_manager.gd")
const ServerAdminUI = preload("res://source/server/server_admin_ui.gd")
const SpatialManager = preload("res://source/server/spatial_manager.gd")
const NetworkSync = preload("res://source/server/network_sync.gd")
const InputProcessor = preload("res://source/server/input_processor.gd")
const MovementValidator = preload("res://source/server/movement_validator.gd")
const AntiCheat = preload("res://source/server/anti_cheat.gd")
const RateLimiter = preload("res://source/server/rate_limiter.gd")
const AuthenticationManager = preload("res://source/server/managers/authentication_manager.gd")
const PlayerManager = preload("res://source/server/managers/player_manager.gd")
const ServerNPCManager = preload("res://source/server/managers/npc_manager.gd")
const CombatManager = preload("res://source/server/managers/combat_manager.gd")
const StatsManager = preload("res://source/server/managers/stats_manager.gd")
const ServerMapManager = preload("res://source/server/managers/map_manager.gd")
const NetworkManager = preload("res://source/server/managers/network_manager.gd")
const ChatManager = preload("res://source/server/managers/chat_manager.gd")
const InputManager = preload("res://source/server/managers/input_manager.gd")
const ConnectionManager = preload("res://source/server/managers/connection_manager.gd")
const RealtimeCombatManager = preload("res://source/server/managers/realtime_combat_manager.gd")

################################################################################
# SECTION 1: MANAGER REFERENCES
################################################################################
# This section declares references to all subsystem managers.
# Managers are initialized in _ready() and handle specific domains.
var server
var debug_console: CanvasLayer
var network_handler: Node  # Set by NetworkHandler when it finds us
var spatial_manager  # Interest management
var network_sync  # Binary packet broadcasting
var input_processor  # Server-side movement authority
var movement_validator  # Movement validation
var anti_cheat  # Cheat detection
var rate_limiter = null  # RPC rate limiting
var collision_world: Node2D  # Server-side collision shapes for validation
var admin_ui  # Admin panel UI and handlers
var ui_manager = null  # UI manager (extracted module)
var auth_manager = null  # Authentication manager (extracted module)
var player_manager = null  # Player manager (character creation/deletion/spawning)
var npc_manager = null  # NPC manager (spawning, AI, movement)
var combat_manager = null  # Combat manager (NPC combat, player actions, enemy AI)
var stats_manager = null  # Stats manager (server statistics and admin tools)
var map_manager = null  # Map manager (collision loading and management)
var network_manager = null  # Network manager
var chat_manager = null  # Chat manager (message handling and broadcasting)
var input_manager = null  # Input manager (player input processing and validation)
var connection_manager = null  # Connection manager
var realtime_combat_manager = null  # Realtime combat manager (new tactical combat system)

################################################################################
# SECTION 2: CONVENIENCE ACCESSORS
################################################################################
# These functions provide quick access to manager-owned state.
# Useful for cross-manager coordination without tight coupling.

# Convenience properties to access player_manager's state
func get_connected_players() -> Dictionary:
	return player_manager.connected_players if player_manager else {}

func get_player_positions() -> Dictionary:
	return player_manager.player_positions if player_manager else {}

func get_player_teams() -> Dictionary:
	return player_manager.player_teams if player_manager else {}

# Convenience property to access npc_manager's state
func get_server_npcs() -> Dictionary:
	return npc_manager.server_npcs if npc_manager else {}

################################################################################
# SECTION 3: STATE DELEGATION NOTES
################################################################################
# All game state is owned by managers, not server_world.
# PLAYER STATE -> PlayerManager
#   - connected_players, player_positions, player_teams
# NPC STATE -> NPCManager
#   - server_npcs, npc_positions, next_npc_id
# COMBAT STATE -> CombatManager
#   - npc_combat_instances, next_combat_id

################################################################################
# SECTION 4: SERVER CONFIGURATION
################################################################################
var server_port: int = 9123
var tick_rate: float = 0.05     # 20 updates per second
var tick_timer: float = 0.0

var server_start_time: float = 0.0  # For uptime calculation
var detected_local_ip: String = ""  # Local network IP
var detected_public_ip: String = "Detecting..."  # External IP


################################################################################
# SECTION 5: INITIALIZATION
################################################################################
# This is the main initialization sequence. Managers are created in dependency
# order (e.g., AuthenticationManager before PlayerManager).

func _ready():
	print("=== ODYSSEYS REVIVAL - DEVELOPMENT SERVER ===")

	# Track server start time for uptime display
	server_start_time = Time.get_ticks_msec() / 1000.0

	# ServerConnection is now an autoload - get it from root
	# The ServerConnection is shared between server and client for bidirectional communication
	network_handler = get_tree().root.get_node_or_null("ServerConnection")
	if network_handler:
		network_handler.server_world = self
		print("[SERVER] ServerConnection autoload found at /root/ServerConnection")
	else:
		print("[SERVER] ERROR: ServerConnection autoload not found!")

	# Add debug console only if NOT in headless mode (headless has no display/UI)
	if DisplayServer.get_name() != "headless":
		var console_script = load("res://source/common/debug/debug_console.gd")
		if console_script:
			debug_console = console_script.new()
			debug_console.name = "DebugConsole"  # Name it for easy retrieval in cleanup
			get_tree().root.add_child(debug_console)
			print("[DEBUG] Debug console created and added to root")
			debug_console.set_motd("Welcome to Odysseys Revival! Your adventure begins now!")
			debug_console.add_log("Server Debug Console Active", "green")
			debug_console.add_log("Waiting for connections on port 9043...", "white")
			if debug_console.log_text:
				debug_console.log_text.append_text(
					"[DEBUG] If you see this, the debug console is rendering correctly.\n"
				)
		else:
			print("[DEBUG] ERROR: Could not load debug console script!")
	else:
		print("[DEBUG] Running in headless mode - skipping debug console UI")
	
	# Initialize database
	GameDatabase.init_database()
	log_message("[DATABASE] Initialized")

	# Load server configuration
	var server_config = ConfigManager.get_server_config()
	server_port = server_config.get("port", 8043)
	tick_rate = server_config.get("tick_rate", 0.05)
	print("[CONFIG] Loaded server config - Port: %d, Tick Rate: %.3f" % [server_port, tick_rate])

	print("[DEBUG] Step 5: Detecting Local IP")
	# Detect local IP
	detected_local_ip = ConfigManager.get_local_ip()
	print("[NETWORK] Detected local IP: %s" % detected_local_ip)

	print("[DEBUG] Step 6: Detecting Public IP")
	# Detect public IP asynchronously
	# ConfigManager.get_public_ip_async(func(public_ip):
	# 	detected_public_ip = public_ip
	# 	print("[NETWORK] Detected public IP: %s" % public_ip)
	# 	if ui_manager:
	# 		ui_manager.update_connection_info_display()
	# )
	print("[NETWORK] Public IP detection skipped for stability.")

	print("[DEBUG] Step 7: Init UI Manager")
	ui_manager = UIManager.new()
	add_child(ui_manager)
	ui_manager.initialize(self)

	# Initialize admin UI handler (needed before create_server_ui) - skip in headless
	if DisplayServer.get_name() != "headless":
		admin_ui = ServerAdminUI.new(self)
		add_child(admin_ui)

	# Create server UI - will auto-skip in headless mode
	ui_manager.create_server_ui()

	# Initialize server (but don't start yet)
	server = BaseServer.new()
	add_child(server)
	server.port = server_port

	# Initialize spatial manager (interest management)
	spatial_manager = SpatialManager.new()
	spatial_manager.name = "SpatialManager"
	spatial_manager.grid_cell_size = 512  # 4 tiles at 128px
	spatial_manager.visibility_radius = 2  # 2 grid cells around player
	add_child(spatial_manager)
	log_message("[SPATIAL] Interest management initialized (cell_size=%d, radius=%d)" % [
		spatial_manager.grid_cell_size,
		spatial_manager.visibility_radius
	])

	# Initialize network sync (binary packet broadcasting)
	network_sync = NetworkSync.new()
	network_sync.name = "NetworkSync"
	network_sync.set_server(server)
	network_sync.set_spatial_manager(spatial_manager)
	add_child(network_sync)
	log_message("[NETWORK_SYNC] Binary packet system initialized")

	# If network_handler was set before network_sync existed, set it now
	if network_handler:
		print("[SERVER] Re-setting network_handler on network_sync (timing fix)")
		network_sync.set_network_handler(network_handler)

	# Wait for NetworkHandler to be ready (it registers itself with us)
	# network_sync.set_network_handler() will be called by set_network_handler()

	# Initialize input processor (server-side movement authority)
	input_processor = InputProcessor.new()
	input_processor.name = "InputProcessor"
	input_processor.movement_speed = 200.0
	add_child(input_processor)
	log_message("[INPUT_PROCESSOR] Server-side movement authority enabled")

	# Initialize collision world for server-side validation
	collision_world = Node2D.new()
	collision_world.name = "CollisionWorld"
	add_child(collision_world)
	log_message("[COLLISION] Server-side collision world initialized")

	# Initialize map manager
	map_manager = ServerMapManager.new()
	map_manager.initialize(self, collision_world)
	add_child(map_manager)
	log_message("[MAP] Map manager initialized")

	# Load map collision data (same map as client uses)
	map_manager.load_map_collision("res://maps/sample_map.tmx")

	# Initialize movement validator (after collision world is created)
	movement_validator = MovementValidator.new()
	movement_validator.name = "MovementValidator"
	movement_validator.max_speed = 250.0
	movement_validator.teleport_distance_threshold = 100.0
	movement_validator.collision_world = collision_world  # Pass collision reference
	add_child(movement_validator)
	log_message("[MOVEMENT_VALIDATOR] Movement validation enabled (with collision checking)")

	# Initialize anti-cheat system
	anti_cheat = AntiCheat.new()
	anti_cheat.name = "AntiCheat"
	add_child(anti_cheat)
	log_message("[ANTI_CHEAT] Cheat detection system enabled")

	# Initialize rate limiter
	rate_limiter = RateLimiter.new()
	rate_limiter.name = "RateLimiter"
	add_child(rate_limiter)
	log_message("[RATE_LIMITER] RPC rate limiting enabled")

	# Initialize authentication manager
	auth_manager = AuthenticationManager.new()
	auth_manager.initialize(self, network_handler, GameDatabase, debug_console)
	add_child(auth_manager)
	log_message("[AUTH] Authentication manager initialized")

	# Initialize player manager
	player_manager = PlayerManager.new()
	player_manager.initialize(self, network_handler, auth_manager, spatial_manager, null, map_manager)
	add_child(player_manager)
	log_message("[PLAYER] Player manager initialized")

	# Initialize NPC manager
	npc_manager = ServerNPCManager.new()
	npc_manager.initialize(
		self, network_handler, spatial_manager, network_sync,
		movement_validator, player_manager, map_manager
	)
	add_child(npc_manager)
	log_message("[NPC] NPC manager initialized")

	# Set npc_manager reference on player_manager (for sending NPCs to new players)
	player_manager.npc_manager = npc_manager

	# Spawn NPCs
	if npc_manager:
		npc_manager.spawn_server_npcs()

	# Initialize combat manager
	combat_manager = CombatManager.new()
	add_child(combat_manager)
	# Pass references to managers that combat_manager depends on
	combat_manager.initialize(self, player_manager, npc_manager)
	log_message("[COMBAT] Combat manager initialized")

	# Initialize realtime combat manager (new tactical system)
	realtime_combat_manager = RealtimeCombatManager.new()
	add_child(realtime_combat_manager)
	realtime_combat_manager.initialize(self, player_manager, npc_manager)
	log_message("[RT_COMBAT] Realtime combat manager initialized")

	# Initialize stats manager
	stats_manager = StatsManager.new()
	stats_manager.initialize(self)
	add_child(stats_manager)
	log_message("[STATS] Stats manager initialized")

	# Initialize network manager
	network_manager = NetworkManager.new()
	network_manager.initialize(self)
	add_child(network_manager)
	log_message("[NETWORK] Network manager initialized")

	# Initialize chat manager
	chat_manager = ChatManager.new()
	chat_manager.initialize(self)
	add_child(chat_manager)
	log_message("[CHAT] Chat manager initialized")

	# Initialize input manager
	input_manager = InputManager.new()
	input_manager.initialize(self)
	add_child(input_manager)
	log_message("[INPUT] Input manager initialized")

	# Initialize connection manager (must be after all other managers)
	connection_manager = ConnectionManager.new()
	connection_manager.initialize(
		self,
		server,
		network_handler,
		auth_manager,
		player_manager,
		spatial_manager,
		anti_cheat,
		network_manager,
		admin_ui,
		debug_console
	)
	add_child(connection_manager)
	log_message("[CONNECTION] Connection manager initialized")

	# CRITICAL: Set authentication callback BEFORE starting server
	# This must happen before init_multiplayer_api() is called
	server.authentication_callback = connection_manager.handle_authentication_callback

	# Initialize multiplayer API with authentication callback set
	server.init_multiplayer_api()

	# Connect connection/disconnection signals AFTER multiplayer_api is initialized
	server.multiplayer_api.peer_connected.connect(connection_manager.handle_player_connected)
	server.multiplayer_api.peer_disconnected.connect(connection_manager.handle_player_disconnected)

	# NOW start the server - it's ready to authenticate clients
	server.start_server()

	log_message("[SERVER] Starting on port %d..." % server_port)
	log_message("[SERVER] Waiting for players to connect...")

	if ui_manager:
		ui_manager.update_status("RUNNING", Color.GREEN)

	# Update debug console with server status
	if debug_console:
		debug_console.update_stats("SERVER RUNNING - Port 9123", -1, 0)
		debug_console.add_log("Server started successfully", "green")
		debug_console.add_log("Listening on UDP port 9123 (ENet)", "cyan")

	# Update admin UI stats now that all managers are initialized
	if admin_ui:
		admin_ui.update_server_stats()


func _exit_tree():
	"""Clean up DebugConsole when server_world scene unloads"""
	var debug_console_node = get_tree().root.get_node_or_null("DebugConsole")
	if debug_console_node:
		debug_console_node.queue_free()
		print("[SERVER] DebugConsole cleanup: queued for deletion")
	else:
		print("[SERVER] DebugConsole cleanup: node not found at /root/DebugConsole")


################################################################################
# SECTION 6: MAIN PROCESS LOOP
################################################################################
# Runs at 20 ticks per second. Coordinates NPC updates and position broadcasts.

func _process(delta):
	"""Server tick for position updates and NPC AI"""
	tick_timer += delta
	if tick_timer >= tick_rate:
		tick_timer = 0.0
		if npc_manager:
			npc_manager.update_npcs(tick_rate)
		if network_manager:
			network_manager.broadcast_player_positions()
		if npc_manager:
			npc_manager.broadcast_npc_positions()

	# Network and server stats are now updated by UIManager


################################################################################
# SECTION 7: NETWORK HANDLER SETUP
################################################################################
# Called by NetworkHandler when it's ready. Propagates handler to subsystems.

func set_network_handler(handler: Node):
	"""Set the network handler reference (called by NetworkHandler)"""
	network_handler = handler
	print("[SERVER] Network handler reference set: %s" % network_handler)

	# Pass to network_sync if it exists
	if network_sync:
		print("[SERVER] Passing handler to network_sync...")
		network_sync.set_network_handler(handler)
	else:
		print("[SERVER] WARNING: network_sync is null, cannot set handler!")


################################################################################
# SECTION 8: RPC PROXIES - ACCOUNT MANAGEMENT
################################################################################
# These RPCs are called by clients and forwarded to AuthenticationManager.

## RPC Proxy: Create Account
## Forwards to AuthenticationManager
@rpc("any_peer")
func request_create_account(username: String, password: String):
	if auth_manager:
		auth_manager.request_create_account(username, password)


## RPC Proxy: Login
## Forwards to AuthenticationManager
@rpc("any_peer")
func request_login(username: String, password: String):
	if auth_manager:
		auth_manager.request_login(username, password)


## RPC Proxy: Logout
## Forwards to AuthenticationManager
@rpc("any_peer")
func request_logout():
	if auth_manager:
		auth_manager.request_logout()


################################################################################
# SECTION 9: RPC PROXIES - CHARACTER MANAGEMENT
################################################################################
# These RPCs are called by clients and forwarded to PlayerManager.

## RPC Proxy: Create Character
func request_create_character(peer_id: int, username: String, character_data: Dictionary):
	if player_manager:
		player_manager.request_create_character(peer_id, username, character_data)


## RPC Proxy: Delete Character
@rpc("any_peer")
func request_delete_character(username: String, character_id: String):
	if player_manager:
		player_manager.request_delete_character(username, character_id)


## RPC Proxy: Spawn Character
@rpc("any_peer")
func request_spawn_character(username: String, character_id: String):
	if player_manager:
		player_manager.request_spawn_character(username, character_id)


################################################################################
# SECTION 10: RPC PROXIES - GAMEPLAY
################################################################################
# Active gameplay RPCs forwarded to specialized managers.

## RPC Proxy: Player Input
## Forwards to InputManager
@rpc("any_peer")
func player_input(input: Dictionary):
	if input_manager:
		input_manager.handle_player_input(input)


## RPC Proxy: Chat Message
## Forwards to ChatManager
@rpc("any_peer")
func send_chat_message(message: String):
	if chat_manager:
		chat_manager.handle_chat_message(message)


## RPC Proxy: Handle NPC Attack Request
## Forwards to CombatManager
@rpc("any_peer")
func handle_npc_attack_request(peer_id: int, npc_id: int):
	print("============================================================")
	print("[SERVER_WORLD] ========== HANDLE_NPC_ATTACK_REQUEST ==========")
	print("[SERVER_WORLD] peer_id: %d, npc_id: %d" % [peer_id, npc_id])
	print("[SERVER_WORLD] combat_manager exists: %s" % (combat_manager != null))
	print("============================================================")

	if combat_manager:
		print("[SERVER_WORLD] Forwarding to combat_manager...")
		combat_manager.handle_npc_attack_request(peer_id, npc_id)
		print("[SERVER_WORLD] combat_manager.handle_npc_attack_request() returned")
	else:
		print("[SERVER_WORLD] ERROR: combat_manager is null!")


## RPC Proxy: Handle Player Action (Primary Battle Action Handler)
## Called by server_connection.gd (NOT directly via RPC)
## CRITICAL: This is the main entry point for battle actions
func handle_player_action(peer_id: int, combat_id: int, action: String, target_id: int):
	print("[SERVER] handle_player_action called: peer_id=%d, combat_id=%d, action=%s, target_id=%d" % [peer_id, combat_id, action, target_id])
	if combat_manager:
		combat_manager.receive_player_battle_action(peer_id, combat_id, action, target_id)
	else:
		print("[SERVER] ERROR: combat_manager is null - cannot process action")


## RPC Proxy: Receive Player Battle Action (Legacy/Backup)
## Forwards to CombatManager
## CRITICAL: This proxy is required for battle system to function
@rpc("any_peer")
func receive_player_battle_action(peer_id: int, combat_id: int, action_type: String, target_id: int):
	if combat_manager:
		combat_manager.receive_player_battle_action(peer_id, combat_id, action_type, target_id)


## RPC Proxy: Handle Battle End
## Called when client reports battle has ended
func handle_battle_end(peer_id: int, combat_id: int, victory: bool):
	print("[COMBAT] Battle end received from peer %d: combat_id=%d, victory=%s" % [peer_id, combat_id, victory])
	if combat_manager:
		# Forward to combat_manager if it has a handler
		if combat_manager.has_method("handle_battle_end"):
			combat_manager.handle_battle_end(peer_id, combat_id, victory)
		else:
			print("[COMBAT] WARNING: combat_manager doesn't have handle_battle_end method - battle cleanup may not occur")
	else:
		print("[COMBAT] ERROR: combat_manager not found - cannot process battle end")


## RPC Proxy: Battle Player Attack
## Forwards to CombatManager
@rpc("any_peer")
func battle_player_attack(combat_id: int, target_index: int):
	if combat_manager:
		combat_manager.battle_player_attack(combat_id, target_index)


## RPC Proxy: Battle Player Defend
## Forwards to CombatManager
@rpc("any_peer")
func battle_player_defend(combat_id: int):
	if combat_manager:
		combat_manager.battle_player_defend(combat_id)


## RPC Proxy: Battle Player Use Skill
## Forwards to CombatManager
@rpc("any_peer")
func battle_player_use_skill(combat_id: int, target_index: int, skill_name: String):
	if combat_manager:
		combat_manager.battle_player_use_skill(combat_id, target_index, skill_name)


## RPC Proxy: Battle Player Use Item
## Forwards to CombatManager
@rpc("any_peer")
func battle_player_use_item(combat_id: int, target_index: int, item_name: String):
	if combat_manager:
		combat_manager.battle_player_use_item(combat_id, target_index, item_name)


################################################################################
# SECTION 10B: RPC PROXIES - REALTIME COMBAT (NEW TACTICAL SYSTEM)
################################################################################
# These RPCs handle the new real-time tactical combat system.
# Separate from turn-based combat for clean separation of concerns.

## RPC Proxy: Request Realtime Battle
## Called when player attacks NPC to start real-time battle
func handle_realtime_battle_request(peer_id: int, npc_id: int):
	if realtime_combat_manager:
		# Get player data
		var player_data = player_manager.get_player_data(peer_id) if player_manager else {}
		var squad_data = []  # TODO: Get from squad manager when implemented

		# Get enemy data from NPC
		var enemy_data = []
		if npc_manager and npc_manager.server_npcs.has(npc_id):
			var npc_info = npc_manager.server_npcs[npc_id]
			enemy_data = [npc_info]  # Single enemy for now

		realtime_combat_manager.create_battle(peer_id, npc_id, player_data, squad_data, enemy_data)

## RPC Proxy: Realtime Player Movement
func handle_realtime_player_move(peer_id: int, velocity: Vector2):
	if realtime_combat_manager:
		realtime_combat_manager.handle_player_movement(peer_id, velocity)

## RPC Proxy: Realtime Player Attack
func handle_realtime_player_attack(peer_id: int, target_id: String):
	if realtime_combat_manager:
		realtime_combat_manager.handle_player_attack(peer_id, target_id)

## RPC Proxy: Realtime Player Defend
func handle_realtime_player_defend(peer_id: int):
	if realtime_combat_manager:
		realtime_combat_manager.handle_player_defend(peer_id)


################################################################################
# SECTION 11: CLIENT-SIDE RPC STUBS
################################################################################
# These are client-side functions. Server declares them so clients can call
# them via RPC, but server never executes this code (placeholders only).

@rpc
func account_creation_response(_success: bool, _message: String):
	"""Client-side function (placeholder)"""
	pass


@rpc
func login_response(_success: bool, _message: String, _data: Dictionary):
	"""Client-side function (placeholder)"""
	pass


@rpc
func character_creation_response(_success: bool, _message: String, _character_id: String):
	"""Client-side function (placeholder)"""
	pass


@rpc
func character_deletion_response(_success: bool, _message: String):
	"""Client-side function (placeholder)"""
	pass


@rpc
func spawn_accepted(_player_data: Dictionary):
	"""Client-side function (placeholder)"""
	pass


@rpc
func spawn_rejected(_reason: String):
	"""Client-side function (placeholder)"""
	pass


@rpc
func player_spawned(_peer_id: int, _player_data: Dictionary):
	"""Client-side function (placeholder)"""
	pass


@rpc
func player_despawned(_peer_id: int):
	"""Client-side function (placeholder)"""
	pass


@rpc
func sync_positions(_positions: Dictionary):
	"""Client-side function (placeholder)"""
	pass


@rpc
func receive_chat_message(_player_name: String, _message: String):
	"""Client-side function (placeholder)"""
	pass


################################################################################
# SECTION 12: UTILITIES & LOGGING
################################################################################
# Helper functions for logging, monitoring, and UI updates.

func update_player_count():
	"""Update player count display"""
	var count = player_manager.connected_players.size() if player_manager else 0
	if ui_manager:
		ui_manager.update_player_count(count)


func _log_server_connection_path(handler: Node, action: String) -> void:
	"""Helper to log ServerConnection path after deferred add"""
	if handler and handler.is_inside_tree():
		print("[RPC_FIX] %s ServerConnection at: %s" % [action, handler.get_path()])
	else:
		print("[RPC_FIX] WARNING: ServerConnection not in tree after deferred add!")


func log_message(message: String):
	"""Add message to server log and debug console"""
	var timestamp = Time.get_time_string_from_system()
	var formatted = "[%s] %s" % [timestamp, message]
	if ui_manager:
		ui_manager.log_to_console(formatted)
	if debug_console:
		debug_console.add_log(message, "white")
	print(message)


func server_print(message: String):
	"""Print to both console window AND server UI - use this instead of print()"""
	if ui_manager:
		ui_manager.log_to_console(message)
	print(message)


func log_activity(message: String):
	"""Add message to activity log panel (recent activity)"""
	if ui_manager:
		var timestamp = Time.get_time_string_from_system()
		ui_manager.log_to_activity("[%s] %s" % [timestamp, message])


################################################################################
# SECTION 13: BINARY PACKET HANDLERS
################################################################################
# Handle binary protocol packets (forwarded to InputManager).

func handle_binary_input(packet: PackedByteArray):
	"""Handle binary input packet from client (forwarded to InputManager)"""
	var peer_id = multiplayer.get_remote_sender_id()
	if input_manager:
		input_manager.handle_binary_input(peer_id, packet)


################################################################################
# SECTION 14: ADMIN BUTTON HANDLERS
################################################################################
# Button click handlers for admin UI (delegated to StatsManager).

func _on_print_stats_pressed():
	"""Admin button handler - print server statistics"""
	if stats_manager:
		stats_manager.print_stats()


func _on_list_players_pressed():
	"""Admin button handler - list all connected players"""
	if stats_manager:
		stats_manager.list_players()


func _on_toggle_console_pressed():
	"""Admin button handler - toggle debug console visibility"""
	if stats_manager:
		stats_manager.toggle_console()


################################################################################
# SECTION 15: CONTENT UPLOAD HANDLERS (LOCALHOST ONLY)
################################################################################
# These handlers allow admin tools to upload content to the server.
# SECURITY: Only accepts uploads from localhost (127.0.0.1) connections.
# Production servers should have these disabled or removed entirely.

func _is_localhost_connection(peer_id: int) -> bool:
	"""Check if the peer is connecting from localhost"""
	# In Godot's ENet, we can check the peer's address
	var peer = multiplayer.multiplayer_peer
	if peer and peer is ENetMultiplayerPeer:
		var enet_peer = peer.get_peer(peer_id)
		if enet_peer:
			var address = enet_peer.get_remote_address()
			return address == "127.0.0.1" or address == "::1" or address == "localhost"
	# Fallback: If we can't determine, reject for safety
	return false


func upload_class(class_name_str: String, class_data: Dictionary):
	"""Handle class upload from admin tool - LOCALHOST ONLY"""
	var peer_id = multiplayer.get_remote_sender_id()

	# SECURITY: Only allow uploads from localhost
	if not _is_localhost_connection(peer_id):
		log_message("[SECURITY] Rejected class upload from non-localhost peer %d" % peer_id)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Upload rejected: Only localhost uploads allowed")
		return

	# Check admin level
	var admin_level = auth_manager.get_admin_level(peer_id) if auth_manager else 0
	if admin_level < 1:
		log_message("[SECURITY] Rejected class upload from non-admin peer %d" % peer_id)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Upload rejected: Admin privileges required")
		return

	# Save class data to file
	var save_dir = "res://characters/classes/"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.open("res://").make_dir_recursive("characters/classes")

	var save_path = save_dir + class_name_str + ".json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(class_data, "\t"))
		file.close()
		log_message("[UPLOAD] Class '%s' saved by admin (peer %d)" % [class_name_str, peer_id])
		if network_handler:
			network_handler.send_upload_response(peer_id, true, "Class '%s' uploaded successfully" % class_name_str)
	else:
		log_message("[UPLOAD] ERROR: Failed to save class '%s'" % class_name_str)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Failed to save class file")


func upload_npc(npc_name: String, npc_data: Dictionary):
	"""Handle NPC upload from admin tool - LOCALHOST ONLY"""
	var peer_id = multiplayer.get_remote_sender_id()

	# SECURITY: Only allow uploads from localhost
	if not _is_localhost_connection(peer_id):
		log_message("[SECURITY] Rejected NPC upload from non-localhost peer %d" % peer_id)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Upload rejected: Only localhost uploads allowed")
		return

	# Check admin level
	var admin_level = auth_manager.get_admin_level(peer_id) if auth_manager else 0
	if admin_level < 1:
		log_message("[SECURITY] Rejected NPC upload from non-admin peer %d" % peer_id)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Upload rejected: Admin privileges required")
		return

	# Save NPC data to file
	var save_dir = "res://characters/npcs/"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.open("res://").make_dir_recursive("characters/npcs")

	var save_path = save_dir + npc_name + ".json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(npc_data, "\t"))
		file.close()
		log_message("[UPLOAD] NPC '%s' saved by admin (peer %d)" % [npc_name, peer_id])
		if network_handler:
			network_handler.send_upload_response(peer_id, true, "NPC '%s' uploaded successfully" % npc_name)
	else:
		log_message("[UPLOAD] ERROR: Failed to save NPC '%s'" % npc_name)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Failed to save NPC file")


func upload_map(map_name: String, map_data: String):
	"""Handle map upload from admin tool - LOCALHOST ONLY"""
	var peer_id = multiplayer.get_remote_sender_id()

	# SECURITY: Only allow uploads from localhost
	if not _is_localhost_connection(peer_id):
		log_message("[SECURITY] Rejected map upload from non-localhost peer %d" % peer_id)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Upload rejected: Only localhost uploads allowed")
		return

	# Check admin level
	var admin_level = auth_manager.get_admin_level(peer_id) if auth_manager else 0
	if admin_level < 1:
		log_message("[SECURITY] Rejected map upload from non-admin peer %d" % peer_id)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Upload rejected: Admin privileges required")
		return

	# Save map data to file
	var save_dir = "res://maps/"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.open("res://").make_dir("maps")

	var save_path = save_dir + map_name + ".tmx"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(map_data)
		file.close()
		log_message("[UPLOAD] Map '%s' saved by admin (peer %d)" % [map_name, peer_id])
		if network_handler:
			network_handler.send_upload_response(peer_id, true, "Map '%s' uploaded successfully" % map_name)
	else:
		log_message("[UPLOAD] ERROR: Failed to save map '%s'" % map_name)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Failed to save map file")
