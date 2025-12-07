class_name NPCManager
extends Node

## ============================================================================
## NPC MANAGER
## ============================================================================
## Handles all NPC spawning and management including:
## - Server-spawned NPC creation
## - NPC restoration after battle
## - Team assignment visualization
## - NPC sprite and animation setup
## - NPC lifecycle management
## ============================================================================

# Preloaded resources
const WanderingNPC = preload("res://source/client/gameplay/wandering_npc.gd")

# Dependencies (injected during initialization)
var game_world: Node2D
var sprite_atlas_textures: Array[Texture2D] = []

# NPC state
var server_npcs: Dictionary = {}  # npc_id -> WanderingNPC instance (server-controlled)
var team_npc_ids: Array = []  # NPC IDs assigned to player's team
var npc_engagements: Dictionary = {}  # npc_id -> peer_id (who is fighting this NPC)

# Configuration
var CROP_EDGE: int = 1  # Sprite cropping setting

# Character loading function (injected)
var load_character_data_func: Callable

func initialize(
	_game_world: Node2D,
	_sprite_atlas_textures: Array[Texture2D],
	_crop_edge: int,
	_load_character_data: Callable
) -> void:
	"""Initialize manager with dependency injection."""
	game_world = _game_world
	sprite_atlas_textures = _sprite_atlas_textures
	CROP_EDGE = _crop_edge
	load_character_data_func = _load_character_data

	print("[NPCManager] Initialized")

## ============================================================================
## NPC RESTORATION (After Battle)
## ============================================================================

func restore_npcs_from_battle() -> void:
	"""Restore NPCs after returning from battle scene"""
	print("[NPC] ===== RESTORING NPCs FROM BATTLE =====")
	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		print("[NPC] ERROR: GameState not found!")
		return

	if game_state.server_npcs_data.is_empty():
		print("[NPC] No NPCs to restore (server_npcs_data is empty)")
		return

	print("[NPC] Restoring %d NPCs from battle..." % game_state.server_npcs_data.size())

	for npc_data in game_state.server_npcs_data:
		var npc_id = npc_data.npc_id
		var npc_name = npc_data.npc_name

		print("[NPC_RESTORE] Creating NPC #%d: %s" % [npc_id, npc_name])

		# Load NPC character data
		var npc_character_data = {}
		if load_character_data_func.is_valid():
			npc_character_data = load_character_data_func.call(npc_name)

		if npc_character_data == null or npc_character_data.is_empty():
			print("[NPC] ERROR: Could not load character data for ", npc_name)
			continue

		# Create NPC node
		var npc = WanderingNPC.new()
		npc.name = "npc_%d" % npc_id  # Set node name for scene tree
		npc.npc_name = npc_name
		npc.npc_type = npc_data.npc_type
		npc.spawn_position = npc_data.spawn_position
		npc.position = npc_data.position
		npc.z_index = 0
		npc.y_sort_enabled = true

		# Set animation data BEFORE adding to tree
		npc.animation_data = npc_character_data.animations
		npc.atlas_textures = sprite_atlas_textures
		npc.crop_edge = CROP_EDGE

		# Add to game world
		game_world.add_child(npc)
		server_npcs[npc_id] = npc

		# Disable client-side AI - server is authoritative
		npc.set_process(false)

		# Ensure NPC and sprite are visible
		npc.visible = true
		if npc.animated_sprite:
			npc.animated_sprite.visible = true

		# CRITICAL: Verify hurtbox is set up for attack detection
		if npc.hurtbox:
			print("[NPC_RESTORE] Hurtbox verified for NPC #%d" % npc_id)
			print("[NPC_RESTORE]   - Hurtbox monitoring: %s" % npc.hurtbox.monitoring)
			print("[NPC_RESTORE]   - Hurtbox monitorable: %s" % npc.hurtbox.monitorable)
			print("[NPC_RESTORE]   - Hurtbox collision_layer: %d" % npc.hurtbox.collision_layer)
			print("[NPC_RESTORE]   - Hurtbox collision_mask: %d" % npc.hurtbox.collision_mask)
			if npc.hurtbox.area_entered.is_connected(npc._on_attack_hit):
				print("[NPC_RESTORE]   - area_entered signal CONNECTED")
			else:
				print("[NPC_RESTORE]   - WARNING: area_entered signal NOT CONNECTED!")
		else:
			print("[NPC_RESTORE] ERROR: Hurtbox is null for NPC #%d!" % npc_id)

		print("[NPC] Restored NPC #%d: %s at %s" % [npc_id, npc_name, npc.position])

	# Clear the stored data
	game_state.server_npcs_data = []
	print("[NPC] ===== All NPCs restored successfully =====")

## ============================================================================
## SERVER NPC SPAWN HANDLER
## ============================================================================

func handle_npc_spawned(npc_id: int, npc_data: Dictionary) -> void:
	"""Server notified us of an NPC spawn"""
	# Load NPC character data - ALWAYS use fallback for NPCs since server doesn't send animations
	var npc_name = npc_data.npc_name
	var npc_type = npc_data.get("npc_type", npc_name.replace("npc:", ""))  # Strip "npc:" prefix

	# Load animations directly from JSON file
	var npc_character_data = {}
	var json_file = "res://characters/npcs/%s.json" % npc_type

	if FileAccess.file_exists(json_file):
		var file = FileAccess.open(json_file, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_text) == OK:
				npc_character_data = json.data
			else:
				print("[NPCManager] ERROR: Failed to parse JSON: %s" % json_file)
		else:
			print("[NPCManager] ERROR: Could not open file: %s" % json_file)
	else:
		print("[NPCManager] ERROR: JSON file not found: %s" % json_file)

	# Final check - if no animations, abort
	if not npc_character_data.has("animations"):
		print("[NPCManager] ERROR: No animations found in JSON for NPC %s - cannot spawn" % npc_type)
		return

	# Create NPC node
	var npc = WanderingNPC.new()
	npc.name = "npc_%d" % npc_id  # Set node name for scene tree and attack detection
	npc.npc_name = npc_name
	npc.npc_type = npc_data.get("npc_type", "Rogue")  # Default to Rogue if not specified
	npc.spawn_position = npc_data.position
	npc.position = npc_data.position
	npc.z_index = 0  # Use y-sort instead of fixed z-index
	npc.y_sort_enabled = true

	# Set animation data BEFORE adding to tree
	npc.animation_data = npc_character_data.animations
	npc.atlas_textures = sprite_atlas_textures
	npc.crop_edge = CROP_EDGE

	# Add to game world (this triggers _ready())
	game_world.add_child(npc)
	server_npcs[npc_id] = npc

	# Disable client-side AI - server is authoritative (prevents client manipulation)
	npc.set_process(false)  # Server controls all NPC movement

	# Reload animations after _ready() has created the sprite
	await get_tree().process_frame  # Wait one frame for _ready() to complete
	npc.load_animations()  # Reload now that animation_data is set
	npc.play_idle_animation()

	# Ensure NPC and sprite are visible
	npc.visible = true
	if npc.animated_sprite:
		npc.animated_sprite.visible = true
	else:
		print("[NPCManager] WARNING: NPC #%d animated_sprite is null!" % npc_id)

	if not npc.animated_sprite or not npc.animated_sprite.sprite_frames:
		print("[NPCManager] ERROR: NPC #%d (%s) has no animations loaded!" % [npc_id, npc_name])

	# Apply visual distinction if this NPC is part of player's team
	if team_npc_ids.has(npc_id):
		npc.modulate = Color(0.8, 1.0, 0.8)  # Greenish tint
	else:
		npc.modulate = Color.WHITE

@rpc
func handle_sync_npc_positions(npc_positions: Dictionary) -> void:
	"""Server sent position updates for all NPCs (legacy - not currently used)"""
	# Note: NPC positions are now sent via binary packets in MultiplayerManager
	pass

## ============================================================================
## TEAM MANAGEMENT
## ============================================================================

func set_team_npc_ids(npc_ids: Array) -> void:
	"""Set the list of NPC IDs assigned to player's team"""
	team_npc_ids = npc_ids
	print("[NPCManager] Team NPCs set: ", team_npc_ids)

	# Update visual distinction for already-spawned NPCs
	for npc_id in server_npcs:
		var npc = server_npcs[npc_id]
		if is_instance_valid(npc):
			if team_npc_ids.has(npc_id):
				npc.modulate = Color(0.8, 1.0, 0.8)  # Greenish tint for team
			else:
				npc.modulate = Color.WHITE  # Normal for enemies

## ============================================================================
## ACCESSORS
## ============================================================================

func get_server_npcs() -> Dictionary:
	"""Get dictionary of all server-controlled NPCs"""
	return server_npcs

func get_npc_by_id(npc_id: int):
	"""Get specific NPC by ID"""
	return server_npcs.get(npc_id, null)

func has_npc(npc_id: int) -> bool:
	"""Check if NPC exists"""
	return server_npcs.has(npc_id)


## ============================================================================
## COMBAT ENGAGEMENT SYSTEM
## ============================================================================

func handle_npc_engagement_changed(npc_id: int, engaged_peer_id: int) -> void:
	"""Server notified us of NPC engagement status change"""
	print("[NPCManager] Engagement changed: NPC %d -> peer %d" % [npc_id, engaged_peer_id])

	# Update local tracking
	if engaged_peer_id >= 0:
		npc_engagements[npc_id] = engaged_peer_id
	else:
		npc_engagements.erase(npc_id)

	# Update NPC visual indicator
	var npc = server_npcs.get(npc_id)
	if npc and is_instance_valid(npc):
		npc.set_engaged(engaged_peer_id >= 0, engaged_peer_id)


func is_npc_engaged(npc_id: int) -> bool:
	"""Check if NPC is currently engaged in combat"""
	return npc_engagements.has(npc_id) and npc_engagements[npc_id] >= 0


func get_engaged_peer(npc_id: int) -> int:
	"""Get peer ID of player engaging this NPC, or -1 if not engaged"""
	return npc_engagements.get(npc_id, -1)
