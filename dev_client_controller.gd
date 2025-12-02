extends Node2D

# Helper classes
const DraggablePanel = preload("res://source/client/ui/common/draggable_panel.gd")
const WanderingNPC = preload("res://source/client/gameplay/wandering_npc.gd")
const RemotePlayer = preload("res://source/client/gameplay/remote_player.tscn")
const ChatUI = preload("res://source/client/ui/chat_ui.tscn")

# BLACK LINE FIX: Must match odyssey_sprite_maker.gd CROP_EDGE value
# Set to 0 to disable cropping (sprites will be full 32x32)
# Set to 1 to crop 1px from all edges (sprites will be 30x30 from center of 32x32 region)
const CROP_EDGE = 1  # Change to 0 to undo the fix

@export var movement_speed: float = 200.0
@export var attack_duration: float = 0.5
@export var zoom_min: float = 0.5
@export var zoom_max: float = 4.0
@export var zoom_step: float = 0.25

var current_direction: String = "down"
var attack_direction: String = "down"  # Direction when attack started
var is_attacking: bool = false
var attack_timer: float = 0.0
var current_zoom: float = 2.0

# Node references - GameWorld stays in original location for proper scaling
@onready var bottom_layer: TileMapLayer = $GameWorld/BottomLayer
@onready var middle_layer: TileMapLayer = $GameWorld/MiddleLayer
@onready var top_layer: TileMapLayer = $GameWorld/TopLayer
@onready var test_character: CharacterBody2D = $GameWorld/TestCharacter
@onready var animated_sprite: AnimatedSprite2D = $GameWorld/TestCharacter/AnimatedSprite2D
@onready var camera: Camera2D = $GameWorld/TestCharacter/Camera2D
@onready var attack_hitbox: Area2D = $GameWorld/TestCharacter/AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $GameWorld/TestCharacter/AttackHitbox/CollisionShape2D
@onready var game_world: Node2D = $GameWorld
@onready var character_sheet: Panel = $DevUI/CharacterSheet

# Map and collision system now managed by Phase 4 managers
# (map_manager and collision_system_manager)

# Draggable UI system
var draggable_panels: Array[Panel] = []
var ui_layout_file: String = "user://dev_client_layout.json"

# UI references - will be created dynamically in draggable panels
var map_dropdown: OptionButton
var map_info: Label
var class_dropdown: OptionButton
var animation_dropdown: OptionButton
var direction_dropdown: OptionButton
var frame_info: Label

# Available maps directory
var maps_directory: String = "res://maps/"
var available_maps: Array[String] = []

# Character data
var character_classes: Array[String] = []
var current_character_data: Dictionary = {}
var animation_types: Array[String] = ["walk", "attack"]
var directions: Array[String] = ["up", "down", "left", "right"]

# Sprite cache for lazy loading
var sprite_cache: Dictionary = {}
# Atlas textures for sprite loading
var sprite_atlas_textures: Array[Texture2D] = []
# SpriteFrames cache - reuse animation data for same characters
var spriteframes_cache: Dictionary = {}  # character_name → SpriteFrames
# Character JSON cache - avoid re-parsing same files
var character_data_cache: Dictionary = {}  # character_name → JSON data

# Phase 1 Foundation Managers
var tileset_manager: TilesetManager
var animation_control_manager: AnimationControlManager
var ui_layout_manager: UILayoutManager
var character_sprite_manager: CharacterSpriteManager

# Phase 2 Managers
var input_handler_manager: InputHandlerManager

# Phase 3 Managers
var ui_panel_manager: UIPanelManager
var development_tools_manager: DevelopmentToolsManager

# Phase 4 Managers
var map_manager: MapManager
var collision_system_manager: CollisionSystemManager

# Phase 5 Managers
var multiplayer_manager: MultiplayerManager
var npc_manager: NPCManager
var character_setup_manager: CharacterSetupManager

# Realtime Battle
var battle_launcher = null  # RealtimeBattleLauncher

# Multiplayer variables (maintained for backward compatibility, delegated to managers)
var server_npcs: Dictionary = {}  # Delegated to npc_manager

func _ready():
	# Move ServerConnection to /root so RPCs can find it at the same path as server
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if not server_conn:
		server_conn = get_node_or_null("ServerConnection")
		if server_conn:
			remove_child(server_conn)
			get_tree().root.add_child(server_conn)
			print("[DevClient] Moved ServerConnection to /root")
		else:
			# SAFETY FALLBACK: Create ServerConnection if it doesn't exist
			# (happens when testing dev_client directly without going through login flow)
			print("[DevClient] WARNING: ServerConnection not found - creating new instance")
			var ServerConnectionScript = load("res://source/common/network/server_connection.gd")
			if ServerConnectionScript:
				server_conn = Node.new()
				server_conn.name = "ServerConnection"
				server_conn.set_script(ServerConnectionScript)
				get_tree().root.add_child(server_conn)
				print("[DevClient] ✓ Created ServerConnection at /root")
			else:
				print("[DevClient] ERROR: Could not load ServerConnection script!")

	# Initialize managers
	_initialize_managers()

	# Setup tileset (call manager directly)
	if tileset_manager:
		tileset_manager.setup_tileset_tiles()

	# Disable collision shape visual debugging
	get_tree().debug_collisions_hint = false

	# Add beige/cream background to DevUI to match Kenny theme
	var dev_ui = $DevUI
	if dev_ui:
		var bg_fill = ColorRect.new()
		bg_fill.name = "BackgroundFill"
		bg_fill.color = Color(0.85, 0.75, 0.60, 1.0)  # Beige/cream to match Kenny UI
		bg_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_fill.z_index = -100  # Behind everything
		dev_ui.add_child(bg_fill)
		dev_ui.move_child(bg_fill, 0)  # Move to first position
		print("[DevClient] Beige/cream background added to DevUI")

	# Create draggable UI system
	create_draggable_ui()

	# Wait a frame for UI to be ready
	await get_tree().process_frame

	# Set up the scene connections
	setup_ui_connections()

	# Initialize UI Layout Manager after draggable panels are created
	ui_layout_manager.initialize(draggable_panels)

	# Initialize multiplayer first (loads player sprite)
	setup_multiplayer()

	# Load character classes for UI dropdown (only if not in multiplayer mode)
	if not GameState.get("client"):
		load_character_classes()

	# Restore NPCs if returning from battle
	restore_npcs_from_battle()

	# Populate map dropdown
	populate_map_dropdown()

	# Load first TMX map if available
	if available_maps.size() > 0:
		load_selected_map(available_maps[0])

	# Load saved layout (call manager directly)
	if ui_layout_manager:
		ui_layout_manager.load_ui_layout()

func _exit_tree() -> void:
	"""Clean up resources when leaving this scene."""
	# NOTE: DO NOT clean up ServerConnection or WorldClient here!
	# They must persist across scene transitions (e.g., to battle scene)
	# They will be cleaned up by login_screen when player explicitly logs out

	# Remove debug console from /root if it exists
	var debug_console = get_tree().root.get_node_or_null("DebugConsole")
	if debug_console and is_instance_valid(debug_console):
		debug_console.queue_free()

	# Clear arrays and caches
	draggable_panels.clear()
	sprite_cache.clear()
	spriteframes_cache.clear()
	character_data_cache.clear()
	server_npcs.clear()

	# Manager cleanup happens automatically via queue_free() propagation

## ============================================================================
## MANAGER INITIALIZATION (Phase 1 Foundation)
## ============================================================================

func _initialize_managers() -> void:
	"""Initialize all managers with dependency injection."""

	# Tileset Manager
	tileset_manager = TilesetManager.new()
	add_child(tileset_manager)
	tileset_manager.initialize(bottom_layer, middle_layer, top_layer)

	# Animation Control Manager
	animation_control_manager = AnimationControlManager.new()
	add_child(animation_control_manager)
	animation_control_manager.initialize(animated_sprite, attack_hitbox, attack_hitbox_shape)
	animation_control_manager.attack_duration = attack_duration

	# Character Sprite Manager
	character_sprite_manager = CharacterSpriteManager.new()
	add_child(character_sprite_manager)
	character_sprite_manager.initialize()

	# Load sprite atlas textures
	character_sprite_manager.load_sprite_atlases()
	sprite_atlas_textures = character_sprite_manager.sprite_atlas_textures

	# UI Layout Manager
	ui_layout_manager = UILayoutManager.new()
	add_child(ui_layout_manager)

	# Input Handler Manager (Phase 2)
	input_handler_manager = InputHandlerManager.new()
	add_child(input_handler_manager)
	input_handler_manager.initialize(test_character, camera, animation_control_manager,
									   animated_sprite, attack_hitbox, character_sheet)
	input_handler_manager.movement_speed = movement_speed
	input_handler_manager.attack_duration = attack_duration
	input_handler_manager.zoom_min = zoom_min
	input_handler_manager.zoom_max = zoom_max
	input_handler_manager.zoom_step = zoom_step

	# Connect combat callback
	input_handler_manager.on_npc_attacked = Callable(self, "initiate_combat")

	# UI Panel Manager (Phase 3)
	ui_panel_manager = UIPanelManager.new()
	add_child(ui_panel_manager)
	ui_panel_manager.initialize(game_world, character_sprite_manager, ui_layout_manager)

	# Development Tools Manager (Phase 3)
	development_tools_manager = DevelopmentToolsManager.new()
	add_child(development_tools_manager)
	development_tools_manager.initialize(character_sprite_manager)

	# Connect UI panel manager signals
	ui_panel_manager.sprite_creator_requested.connect(_on_sprite_creator_pressed)
	ui_panel_manager.map_editor_requested.connect(_on_map_editor_pressed)
	ui_panel_manager.art_studio_requested.connect(_on_art_studio_pressed)
	ui_panel_manager.map_load_requested.connect(_on_load_map_pressed)
	ui_panel_manager.character_selected.connect(_on_class_selected)

	# Map Manager (Phase 4)
	map_manager = MapManager.new()
	add_child(map_manager)
	map_manager.initialize(bottom_layer, middle_layer, top_layer, game_world, test_character)

	# Connect map_manager to input_handler for transition detection
	input_handler_manager.set_map_manager(map_manager)

	# Connect transition signal to handle map changes
	map_manager.transition_triggered.connect(_on_map_transition)

	# Collision System Manager (Phase 4)
	collision_system_manager = CollisionSystemManager.new()
	add_child(collision_system_manager)
	collision_system_manager.initialize(game_world)

	# Multiplayer Manager (Phase 5)
	multiplayer_manager = MultiplayerManager.new()
	add_child(multiplayer_manager)
	multiplayer_manager.initialize(game_world, test_character, character_sprite_manager,
									 spriteframes_cache, character_data_cache)

	# NPC Manager (Phase 5)
	npc_manager = NPCManager.new()
	add_child(npc_manager)
	npc_manager.initialize(game_world, sprite_atlas_textures, CROP_EDGE,
							Callable(self, "load_character_data"))

	# Character Setup Manager (Phase 5)
	character_setup_manager = CharacterSetupManager.new()
	add_child(character_setup_manager)
	character_setup_manager.initialize(animated_sprite, character_sprite_manager, spriteframes_cache)

	# Sync server_npcs reference between managers
	server_npcs = npc_manager.get_server_npcs()
	input_handler_manager.server_npcs = server_npcs

	# Initialize realtime battle launcher
	var BattleLauncherScript = load("res://scripts/realtime_battle/realtime_battle_launcher.gd")
	if BattleLauncherScript:
		battle_launcher = Node.new()
		battle_launcher.set_script(BattleLauncherScript)
		battle_launcher.name = "BattleLauncher"
		add_child(battle_launcher)
		battle_launcher.initialize(game_world)
		# Register with ServerConnection
		var server_conn = get_tree().root.get_node_or_null("ServerConnection")
		if server_conn:
			server_conn.set_meta("realtime_battle_launcher", battle_launcher)
		print("[DevClient] ✓ Realtime battle launcher initialized")

## ============================================================================
## UI CONNECTIONS AND INITIALIZATION
## ============================================================================

func setup_ui_connections():
	# Skip if UI panels were removed (external tools mode)
	if not direction_dropdown or not animation_dropdown:
		print("Skipping UI connections - using external tools")
		return

	# Setup direction dropdown
	direction_dropdown.add_item("Down")
	direction_dropdown.add_item("Up")
	direction_dropdown.add_item("Left")
	direction_dropdown.add_item("Right")
	direction_dropdown.selected = 0

	# Setup animation dropdown
	animation_dropdown.add_item("Walk")
	animation_dropdown.add_item("Attack")
	animation_dropdown.selected = 0

func populate_map_dropdown():
	"""Delegation wrapper for DevelopmentToolsManager.load_maps()"""
	if development_tools_manager:
		development_tools_manager.load_maps()
		# Sync with local variable for backward compatibility
		available_maps = development_tools_manager.available_maps
		# Populate dropdown if it exists
		if map_dropdown and available_maps.size() > 0:
			map_dropdown.clear()
			for map_name in available_maps:
				map_dropdown.add_item(map_name)
	else:
		print("WARNING: Development tools manager not initialized")

func load_character_classes():
	"""Delegation wrapper for DevelopmentToolsManager.load_character_classes()"""
	if development_tools_manager:
		development_tools_manager.load_character_classes()
		# Sync loaded classes with local variable for backward compatibility
		character_classes = development_tools_manager.character_classes
		# Populate dropdown if it exists
		if class_dropdown and character_classes.size() > 0:
			class_dropdown.clear()
			for cls in character_classes:
				if cls.begins_with("class:"):
					class_dropdown.add_item("[CLASS] " + cls.split(":")[1])
				elif cls.begins_with("npc:"):
					class_dropdown.add_item("[NPC] " + cls.split(":")[1])
	else:
		print("WARNING: Development tools manager not initialized")

## ============================================================================
## CHARACTER SPRITE SETUP (Note: Direct manager calls used throughout)
## ============================================================================

func setup_character_sprite():
	"""Setup character sprite using CharacterSetupManager"""
	if character_setup_manager:
		# Get current character data from multiplayer manager (if in multiplayer mode)
		var char_data = current_character_data
		if multiplayer_manager:
			var mp_data = multiplayer_manager.current_character_data
			if not mp_data.is_empty():
				char_data = mp_data

		character_setup_manager.setup_character_sprite(char_data)
		update_frame_display()
	else:
		print("WARNING: Character setup manager not initialized")

## ============================================================================
## INPUT PROCESSING
## ============================================================================

func _input(event):
	# Handle F5 key to save window layout
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			if ui_layout_manager:
				ui_layout_manager.save_ui_layout()
			get_viewport().set_input_as_handled()
			return  # Don't pass F5 to children

	# CRITICAL: Allow chat input to pass through to chat_ui
	# chat_ui handles ENTER key in its own _input() method
	# If chat is open, let it handle all keyboard input
	if multiplayer_manager and multiplayer_manager.is_chat_open() and event is InputEventKey:
		# Chat is open - let chat_ui handle all keyboard input
		# Don't consume it here, let it propagate to chat_ui
		pass

	# Only delegate non-chat input to InputHandlerManager
	if event is InputEventMouseButton:
		# Delegate mouse input (zoom controls)
		if input_handler_manager:
			input_handler_manager.handle_input(event)
	# ENTER key is handled by chat_ui, not here
	elif event is InputEventKey and event.keycode == KEY_ENTER:
		# ENTER key - let chat_ui handle it via its _input()
		# Don't consume it, allow it to propagate
		pass

## ============================================================================
## PHYSICS AND MOVEMENT
## ============================================================================

func _physics_process(delta):
	# ESC to return to main menu - check first to allow graceful exit
	if Input.is_action_just_pressed("main_menu"):
		return_to_main_menu()
		return  # Exit early to prevent further processing

	# Delegate movement and input handling to InputHandlerManager (Phase 2)
	if input_handler_manager:
		input_handler_manager.process_movement(delta)

	# Apply character movement
	if test_character:
		test_character.move_and_slide()

	# Update frame display regularly
	update_frame_display()

	# Send position updates to server (delegated to MultiplayerManager)
	if multiplayer_manager:
		multiplayer_manager.update_multiplayer_position(delta)

# NOTE: Movement and animation functions removed - call input_handler_manager directly

## ============================================================================
## COMBAT SYSTEM
## ============================================================================

func initiate_combat(npc: WanderingNPC):
	"""Send combat request to server"""
	print("⚔️ Player attacked NPC: ", npc.npc_name)

	# Check if battles are enabled
	if not map_manager.is_battle_enabled():
		return

	# Find NPC ID from server_npcs dictionary
	var npc_id = -1
	for id in server_npcs:
		if server_npcs[id] == npc:
			npc_id = id
			break

	if npc_id == -1:
		print("  ERROR: Could not find NPC ID in server_npcs")
		return

	# DEBUG: Check multiplayer connection status
	print("[COMBAT DEBUG] Checking multiplayer status...")
	print("[COMBAT DEBUG] - multiplayer.has_multiplayer_peer(): ", multiplayer.has_multiplayer_peer())
	if multiplayer.has_multiplayer_peer():
		print("[COMBAT DEBUG] - multiplayer.is_server(): ", multiplayer.is_server())
		print("[COMBAT DEBUG] - multiplayer.get_unique_id(): ", multiplayer.get_unique_id())
		print("[COMBAT DEBUG] - multiplayer.get_peers(): ", multiplayer.get_peers())
		var peer = multiplayer.multiplayer_peer
		if peer:
			print("[COMBAT DEBUG] - peer connection status: ", peer.get_connection_status())
			print("[COMBAT DEBUG] - peer is ENetMultiplayerPeer: ", peer is ENetMultiplayerPeer)
	else:
		print("[COMBAT DEBUG] - NO MULTIPLAYER PEER SET!")

	# Send request to server via ServerConnection
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if server_conn:
		print("[COMBAT] ServerConnection found at: ", server_conn.get_path())
		print("[COMBAT] Sending RPC: rt_start_battle(npc_id=%d)" % npc_id)

		# Use new realtime battle system
		server_conn.rt_start_battle.rpc_id(1, npc_id)

		print("[COMBAT] Realtime battle RPC sent to server")
	else:
		print("  ERROR: ServerConnection not found!")

func _on_attack_animation_finished():
	"""Signal handler delegated to InputHandlerManager"""
	if input_handler_manager:
		input_handler_manager._on_attack_animation_finished()

## ============================================================================
## FRAME DISPLAY AND UI UPDATES
## ============================================================================

func update_frame_display():
	# Skip if UI panel was removed (external tools mode)
	if not frame_info:
		return

	if animated_sprite.sprite_frames and animated_sprite.animation:
		var current_anim = animated_sprite.animation
		if animated_sprite.sprite_frames.has_animation(current_anim):
			var frame_count = animated_sprite.sprite_frames.get_frame_count(current_anim)
			var current_frame = animated_sprite.frame
			frame_info.text = "Frame: %d/%d (%s)" % [current_frame + 1, frame_count, current_anim]
		else:
			frame_info.text = "Frame: 0/0"
	else:
		frame_info.text = "Frame: 0/0"

## ============================================================================
## UI SIGNAL HANDLERS
## ============================================================================
func _on_class_selected(index: int):
	if index < character_classes.size() and character_sprite_manager:
		var data = character_sprite_manager.load_character_data(character_classes[index])
		character_data_cache = character_sprite_manager.character_data_cache

func _on_animation_selected(index: int):
	var animations = ["walk", "attack"]
	if index < animations.size():
		var base_anim = animations[index]
		var full_anim = base_anim + "_" + current_direction
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(full_anim):
			animated_sprite.play(full_anim)
			update_frame_display()

func _on_direction_selected(index: int):
	var directions_list = ["down", "up", "left", "right"]
	if index < directions_list.size():
		current_direction = directions_list[index]
		var base_anim = "walk"
		if animation_dropdown.selected == 1:
			base_anim = "attack"

		var full_anim = base_anim + "_" + current_direction
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(full_anim):
			animated_sprite.play(full_anim)
			update_frame_display()

func _on_load_map_pressed():
	"""Delegation wrapper for MapManager.load_selected_map()"""
	var selected_index = map_dropdown.selected
	if selected_index < available_maps.size():
		var map_name = available_maps[selected_index]
		load_selected_map(map_name)
	else:
		print("ERROR: Invalid map index ", selected_index)

func load_selected_map(map_name: String):
	"""Delegation wrapper for MapManager.load_selected_map()"""
	if map_manager:
		# Set map_info label reference in manager if available
		if map_info:
			map_manager.set_map_info_label(map_info)

		# Clear collision objects before loading new map
		if collision_system_manager:
			collision_system_manager.clear_collision_objects()

		# Load the map
		map_manager.load_selected_map(map_name)

		# NOTE: Rectangle collision objects DISABLED
		# Collision now comes from tiles in the collision_tileset (firstgid=6980)
		# Place collision tiles on any layer in Tiled using the collision_tileset
		# The tileset has physics collision built into the tiles
		print("[DevClient] Map loaded - collision from tileset physics")
	else:
		print("WARNING: Map manager not initialized")

## ============================================================================
## MAP TRANSITION HANDLING
## ============================================================================

func _on_map_transition(target_map: String, spawn_x: int, spawn_y: int) -> void:
	"""Handle map transition triggered by player walking into transition zone"""
	print("[DevClient] === MAP TRANSITION ===")
	print("  Target map: ", target_map)
	print("  Spawn position: (", spawn_x, ", ", spawn_y, ") tiles")

	# Check if the target map exists
	var tmx_path = "res://maps/" + target_map + ".tmx"
	if not FileAccess.file_exists(tmx_path):
		print("[DevClient] ERROR: Target map not found: ", tmx_path)
		return

	# Calculate spawn position in pixels (tiles * 128px per tile, centered in tile)
	var spawn_pos = Vector2(
		spawn_x * 128 + 64,  # Center of tile
		spawn_y * 128 + 64
	)

	# Store spawn position for after map loads
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		# Use pre_battle_position to store spawn (reusing existing field)
		game_state.pre_battle_position = spawn_pos
		print("  Stored spawn position: ", spawn_pos)

	# Load the new map
	load_selected_map(target_map)

	# Position the player at spawn location
	if test_character:
		test_character.position = spawn_pos
		print("  Player positioned at: ", spawn_pos)

	# Update map dropdown to reflect new map
	_update_map_dropdown_selection(target_map)

	# Notify server of map change (if connected)
	_notify_server_map_change(target_map, spawn_pos)

	print("[DevClient] === TRANSITION COMPLETE ===")

func _update_map_dropdown_selection(map_name: String) -> void:
	"""Update the map dropdown to show the current map"""
	if not map_dropdown:
		return

	for i in range(available_maps.size()):
		if available_maps[i] == map_name:
			map_dropdown.selected = i
			break

func _notify_server_map_change(map_name: String, position: Vector2) -> void:
	"""Notify server that player changed maps"""
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if not server_conn:
		print("[DevClient] No server connection - skipping map change notification")
		return

	# Check if we have a map_change RPC
	if server_conn.has_method("request_map_change"):
		server_conn.request_map_change.rpc_id(1, map_name, position.x, position.y)
		print("[DevClient] Sent map change request to server")
	else:
		print("[DevClient] Server doesn't support map change RPC yet")

## ============================================================================
## ANIMATION CONTROL HANDLERS
## ============================================================================
func _on_play_pressed():
	# Play current direction animation
	if not is_attacking:
		var anim_name = "walk_" + current_direction
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)
	else:
		var anim_name = "attack_" + attack_direction
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)

func _on_pause_pressed():
	animated_sprite.pause()

func _on_stop_pressed():
	animated_sprite.stop()

# Tool handlers
func _on_sprite_creator_pressed():
	"""Delegation wrapper for DevelopmentToolsManager._on_sprite_creator_pressed()"""
	if development_tools_manager:
		development_tools_manager._on_sprite_creator_pressed()
	else:
		print("WARNING: Development tools manager not initialized")

func _on_map_editor_pressed():
	"""Delegation wrapper for DevelopmentToolsManager._on_map_editor_pressed()"""
	if development_tools_manager:
		development_tools_manager._on_map_editor_pressed()
	else:
		print("WARNING: Development tools manager not initialized")

func _on_art_studio_pressed():
	"""Delegation wrapper for DevelopmentToolsManager._on_art_studio_pressed()"""
	if development_tools_manager:
		development_tools_manager._on_art_studio_pressed()
	else:
		print("WARNING: Development tools manager not initialized")

## ============================================================================
## MENU AND SCENE MANAGEMENT
## ============================================================================

func return_to_main_menu():
	"""Delegation wrapper for DevelopmentToolsManager.return_to_main_menu()"""
	if ui_layout_manager:
		ui_layout_manager.save_ui_layout()

	if development_tools_manager:
		development_tools_manager.return_to_main_menu()
	else:
		# Fallback if manager not available
		print("WARNING: Development tools manager not initialized")
		GameState.set("last_logout_time", Time.get_ticks_msec() / 1000.0)
		if GameState.world_client:
			print("[LOGOUT] Closing connection...")
			GameState.world_client.close_connection()
		get_tree().change_scene_to_file("res://source/client/ui/login_screen.tscn")

## ============================================================================
## DRAGGABLE UI PANEL CREATION
## ============================================================================

func create_draggable_ui():
	"""Delegation wrapper for UIPanelManager.create_draggable_ui()"""
	if ui_panel_manager:
		ui_panel_manager.create_draggable_ui()
		draggable_panels = ui_panel_manager.draggable_panels
	else:
		print("WARNING: UI panel manager not initialized")

# NOTE: UI layout functions removed - call ui_layout_manager directly

## ============================================================================
## MULTIPLAYER SETUP
## ============================================================================

func setup_multiplayer():
	"""Delegation wrapper for MultiplayerManager.setup_multiplayer()"""
	if multiplayer_manager:
		multiplayer_manager.setup_multiplayer(Callable(self, "setup_character_sprite"))
	else:
		print("WARNING: Multiplayer manager not initialized")

## ============================================================================
## SERVER RPC HANDLERS (Delegated to Managers)
## ============================================================================

func handle_spawn_accepted(player_data: Dictionary):
	"""Delegation wrapper for MultiplayerManager.handle_spawn_accepted()"""
	if multiplayer_manager:
		multiplayer_manager.handle_spawn_accepted(player_data, Callable(self, "setup_character_sprite"))

		# Update NPC manager with team assignment
		if npc_manager:
			npc_manager.set_team_npc_ids(multiplayer_manager.get_team_npc_ids())
	else:
		print("WARNING: Multiplayer manager not initialized")

func handle_spawn_rejected(reason: String):
	"""Delegation wrapper for MultiplayerManager.handle_spawn_rejected()"""
	if multiplayer_manager:
		multiplayer_manager.handle_spawn_rejected(reason)
	else:
		print("WARNING: Multiplayer manager not initialized")

func handle_player_spawned(peer_id: int, player_data: Dictionary):
	"""Delegation wrapper for MultiplayerManager.handle_player_spawned()"""
	if multiplayer_manager:
		multiplayer_manager.handle_player_spawned(peer_id, player_data)
	else:
		print("WARNING: Multiplayer manager not initialized")

func handle_player_despawned(peer_id: int):
	"""Delegation wrapper for MultiplayerManager.handle_player_despawned()"""
	if multiplayer_manager:
		multiplayer_manager.handle_player_despawned(peer_id)
	else:
		print("WARNING: Multiplayer manager not initialized")

@rpc
func sync_positions(positions: Dictionary):
	"""Delegation wrapper for MultiplayerManager.sync_positions()"""
	if multiplayer_manager:
		multiplayer_manager.sync_positions(positions)
	else:
		print("WARNING: Multiplayer manager not initialized")


func handle_binary_positions(packet: PackedByteArray):
	"""Delegation wrapper for MultiplayerManager.handle_binary_positions()"""
	if multiplayer_manager and npc_manager:
		multiplayer_manager.handle_binary_positions(packet, npc_manager.get_server_npcs())
	else:
		print("WARNING: Multiplayer or NPC manager not initialized")

func receive_chat_message(player_name: String, message: String):
	"""Delegation wrapper for MultiplayerManager.receive_chat_message()"""
	if multiplayer_manager:
		multiplayer_manager.receive_chat_message(player_name, message)
	else:
		print("WARNING: Multiplayer manager not initialized")

## ============================================================================
## NPC RPC HANDLERS (Delegated to NPCManager)
## ============================================================================

func restore_npcs_from_battle():
	"""Delegation wrapper for NPCManager.restore_npcs_from_battle()"""
	if npc_manager:
		npc_manager.restore_npcs_from_battle()
		# Sync the reference after restoration
		server_npcs = npc_manager.get_server_npcs()
		if input_handler_manager:
			input_handler_manager.server_npcs = server_npcs
	else:
		print("WARNING: NPC manager not initialized")

func handle_npc_spawned(npc_id: int, npc_data: Dictionary):
	"""Delegation wrapper for NPCManager.handle_npc_spawned()"""
	if npc_manager:
		npc_manager.handle_npc_spawned(npc_id, npc_data)
		# Sync the reference after spawning
		server_npcs = npc_manager.get_server_npcs()
		if input_handler_manager:
			input_handler_manager.server_npcs = server_npcs
	else:
		print("[DevClient] ERROR: NPC manager not initialized")

@rpc
func handle_sync_npc_positions(npc_positions: Dictionary):
	"""Delegation wrapper for NPCManager.handle_sync_npc_positions()"""
	if npc_manager:
		npc_manager.handle_sync_npc_positions(npc_positions)
	else:
		print("WARNING: NPC manager not initialized")


func handle_binary_combat_start(packet: PackedByteArray):
	"""Delegation wrapper for MultiplayerManager.handle_binary_combat_start()"""
	print("[DEV_CONTROLLER] handle_binary_combat_start called! Packet size: %d" % packet.size())
	print("[DEV_CONTROLLER] multiplayer_manager: %s, npc_manager: %s" % [multiplayer_manager != null, npc_manager != null])

	if multiplayer_manager and npc_manager:
		print("[DEV_CONTROLLER] ✓ Forwarding to multiplayer_manager...")
		multiplayer_manager.handle_binary_combat_start(packet, npc_manager.get_server_npcs())
		print("[DEV_CONTROLLER] ✓ multiplayer_manager.handle_binary_combat_start() completed")
	else:
		print("[DEV_CONTROLLER] ✗ ERROR: Multiplayer or NPC manager not initialized!")
		print("[DEV_CONTROLLER] multiplayer_manager=%s, npc_manager=%s" % [multiplayer_manager, npc_manager])

func handle_combat_round_results(combat_id: int, results: Dictionary):
	"""Delegation wrapper for MultiplayerManager.handle_combat_round_results()"""
	if multiplayer_manager:
		multiplayer_manager.handle_combat_round_results(combat_id, results)
	else:
		print("WARNING: Multiplayer manager not initialized")
