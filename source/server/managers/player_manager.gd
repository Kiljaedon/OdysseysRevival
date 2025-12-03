## Golden Sun MMO - Player Manager
## Handles player character creation, deletion, spawning, and state tracking
## Separated from ServerWorld for modularity

extends Node
class_name PlayerManager

# ========== DEPENDENCIES ==========
var server_world: Node = null
var network_handler = null
var auth_manager = null
var spatial_manager = null
var npc_manager = null
var map_manager = null  # For collision-free spawn checking
var char_service: CharacterService

# ========== PLAYER STATE ==========
var connected_players: Dictionary = {}    # peer_id -> player data dictionary
var player_positions: Dictionary = {}      # peer_id -> Vector2 position
var player_teams: Dictionary = {}          # peer_id -> team data
var player_maps: Dictionary = {}           # peer_id -> map name (e.g., "sample_map")


func _ready():
	print("[PLAYER_MANAGER] Player Manager ready")
	char_service = CharacterService.new()
	add_child(char_service)


## Called by ServerWorld to set dependencies
func initialize(server_ref, net_handler, auth_mgr, spatial_mgr, npc_mgr = null, map_mgr = null):
	server_world = server_ref
	network_handler = net_handler
	auth_manager = auth_mgr
	spatial_manager = spatial_mgr
	npc_manager = npc_mgr
	map_manager = map_mgr
	print("[PLAYER_MANAGER] Initialized with dependencies")


# ========== CHARACTER CREATION ==========

func request_create_character(peer_id: int, username: String, character_data: Dictionary):
	"""Handle character creation request from client"""
	print("[PLAYER_MANAGER] request_create_character from peer %d, user: %s" % [peer_id, username])
	print("[PLAYER_MANAGER] Character data: %s" % character_data)

	# Verify the peer is authenticated as this username
	if auth_manager:
		var authenticated_username = auth_manager.get_username(peer_id)
		if authenticated_username != username:
			log_message("[PLAYER_MANAGER] SECURITY: Peer %d tried to create character for %s but authenticated as %s" % [peer_id, username, authenticated_username])
			send_character_creation_response(peer_id, false, "Authentication mismatch", "")
			return

	# Validate character data
	var char_name = character_data.get("name", "").strip_edges()
	var char_class = character_data.get("class_name", "Warrior")

	if char_name.is_empty():
		send_character_creation_response(peer_id, false, "Character name cannot be empty", "")
		return

	if char_name.length() < 3:
		send_character_creation_response(peer_id, false, "Character name must be at least 3 characters", "")
		return

	if char_name.length() > 20:
		send_character_creation_response(peer_id, false, "Character name must be 20 characters or less", "")
		return

	# Validate class
	var valid_classes = ["Warrior", "Mage", "Cleric", "Rogue", "Commander"]
	if not char_class in valid_classes:
		send_character_creation_response(peer_id, false, "Invalid character class", "")
		return

	# Validate element
	var char_element = character_data.get("element", "None")
	var valid_elements = ["None", "Fire", "Water", "Earth", "Wind"]
	if not char_element in valid_elements:
		char_element = "None"

	# Class base stats for validation
	var class_base_stats = {
		"Warrior": {"str": 18, "dex": 12, "int": 8, "vit": 15, "wis": 8, "cha": 10},
		"Mage": {"str": 7, "dex": 10, "int": 18, "vit": 8, "wis": 15, "cha": 10},
		"Cleric": {"str": 8, "dex": 10, "int": 14, "vit": 12, "wis": 18, "cha": 11},
		"Rogue": {"str": 13, "dex": 18, "int": 10, "vit": 10, "wis": 8, "cha": 12},
		"Commander": {"str": 14, "dex": 12, "int": 10, "vit": 13, "wis": 10, "cha": 18}
	}
	var base = class_base_stats.get(char_class, class_base_stats["Warrior"])
	var BONUS_POINTS = 20

	# Extract and validate stats - clamp between class base and base+bonus
	var client_stats = character_data.get("stats", {})
	var stats = {
		"str": clamp(int(client_stats.get("STR", base.str)), base.str, base.str + BONUS_POINTS),
		"dex": clamp(int(client_stats.get("DEX", base.dex)), base.dex, base.dex + BONUS_POINTS),
		"int": clamp(int(client_stats.get("INT", base.int)), base.int, base.int + BONUS_POINTS),
		"vit": clamp(int(client_stats.get("VIT", base.vit)), base.vit, base.vit + BONUS_POINTS),
		"wis": clamp(int(client_stats.get("WIS", base.wis)), base.wis, base.wis + BONUS_POINTS),
		"cha": clamp(int(client_stats.get("CHA", base.cha)), base.cha, base.cha + BONUS_POINTS)
	}

	# Calculate bonus points used
	var bonus_used = (stats.str - base.str) + (stats.dex - base.dex) + (stats.int - base.int) + (stats.vit - base.vit) + (stats.wis - base.wis) + (stats.cha - base.cha)
	if bonus_used > BONUS_POINTS:
		log_message("[PLAYER_MANAGER] SECURITY: Peer %d used %d bonus points (max %d)" % [peer_id, bonus_used, BONUS_POINTS])
		send_character_creation_response(peer_id, false, "Invalid stat allocation - too many bonus points", "")
		return

	# Calculate derived stats from base stats
	var hp = 50 + int(stats.vit * 2.5) + stats.str
	var mp = 50 + (stats.int * 5) + (stats.wis * 2)
	var ep = 30 + (stats.dex * 3)

	# Build character data for database
	var new_character_data = {
		"name": char_name,
		"class_name": char_class,
		"element": char_element,
		"level": 1,
		"xp": 0,
		"position_x": 1344,
		"position_y": 960,
		"hp": hp,
		"max_hp": hp,
		"mp": mp,
		"max_mp": mp,
		"current_ep": ep,
		"max_ep": ep,
		"stats": stats
	}

	# Create the character in database
	var result = char_service.create_character(username, new_character_data)

	if not result.success:
		log_message("[PLAYER_MANAGER] Failed to create character for %s: %s" % [username, result.get("error", "Unknown error")])
		send_character_creation_response(peer_id, false, result.get("error", "Failed to create character"), "")
		return

	# Success!
	var character_id = result.get("character_id", "")
	log_message("[PLAYER_MANAGER] Created character '%s' (class: %s, element: %s) for user %s" % [char_name, char_class, char_element, username])
	log_activity("[color=green]CHARACTER CREATED: %s (%s/%s) for %s[/color]" % [char_name, char_class, char_element, username])

	# Send success response with character data
	var response_data = {
		"character_id": character_id,
		"name": char_name,
		"class_name": char_class,
		"element": char_element,
		"level": 1,
		"stats": stats
	}
	send_character_creation_response(peer_id, true, "Character created successfully", response_data)


func send_character_creation_response(peer_id: int, success: bool, message: String, data):
	"""Send character creation response to client"""
	if network_handler:
		# Ensure data is a Dictionary
		var response_data: Dictionary = data if data is Dictionary else {"character_id": str(data)}
		network_handler.send_character_creation_response(peer_id, success, message, response_data)
	else:
		print("[PLAYER_MANAGER] ERROR: network_handler is null, cannot send response")


# ========== CHARACTER DELETION ==========

func request_delete_character(username: String, character_id: String):
	"""Handle character deletion request from client"""
	var peer_id = multiplayer.get_remote_sender_id()
	print("[PLAYER_MANAGER] request_delete_character from peer %d, user: %s, char_id: %s" % [peer_id, username, character_id])

	# Verify the peer is authenticated as this username
	if auth_manager:
		var authenticated_username = auth_manager.get_username(peer_id)
		if authenticated_username != username:
			log_message("[PLAYER_MANAGER] SECURITY: Peer %d tried to delete character for %s but authenticated as %s" % [peer_id, username, authenticated_username])
			send_character_deletion_response(peer_id, false, "Authentication mismatch")
			return

	# Verify the character belongs to this account
	var char_result = char_service.get_character(character_id)
	if not char_result.success:
		send_character_deletion_response(peer_id, false, "Character not found")
		return

	var character = char_result.character
	if character.get("account", "") != username:
		log_message("[PLAYER_MANAGER] SECURITY: User %s tried to delete character %s that belongs to %s" % [username, character_id, character.get("account")])
		send_character_deletion_response(peer_id, false, "Character does not belong to your account")
		return

	# Delete the character
	var result = char_service.delete_character(username, character_id)

	if not result.success:
		log_message("[PLAYER_MANAGER] Failed to delete character %s: %s" % [character_id, result.get("error", "Unknown error")])
		send_character_deletion_response(peer_id, false, result.get("error", "Failed to delete character"))
		return

	log_message("[PLAYER_MANAGER] Deleted character '%s' for user %s" % [character.get("name", character_id), username])
	log_activity("[color=orange]CHARACTER DELETED: %s for %s[/color]" % [character.get("name", character_id), username])
	send_character_deletion_response(peer_id, true, "Character deleted successfully")


func send_character_deletion_response(peer_id: int, success: bool, message: String):
	"""Send character deletion response to client"""
	if network_handler:
		network_handler.send_character_deletion_response(peer_id, success, message)


# ========== CHARACTER SPAWNING ==========

func request_spawn_character(username: String, character_id: String):
	"""Handle character spawn request from client"""
	var peer_id = multiplayer.get_remote_sender_id()
	print("[PLAYER_MANAGER] request_spawn_character from peer %d, user: %s, char_id: %s" % [peer_id, username, character_id])

	# Verify the peer is authenticated as this username
	if auth_manager:
		var authenticated_username = auth_manager.get_username(peer_id)
		if authenticated_username != username:
			log_message("[PLAYER_MANAGER] SECURITY: Peer %d tried to spawn character for %s but authenticated as %s" % [peer_id, username, authenticated_username])
			if network_handler:
				network_handler.send_spawn_rejected(peer_id, "Authentication mismatch")
			return

	# Load character data from database
	var char_result = char_service.get_character(character_id)
	if not char_result.success:
		log_message("[PLAYER_MANAGER] Character %s not found for spawn" % character_id)
		if network_handler:
			network_handler.send_spawn_rejected(peer_id, "Character not found")
		return

	var character = char_result.character

	# Verify the character belongs to this account
	if character.get("account", "") != username:
		log_message("[PLAYER_MANAGER] SECURITY: User %s tried to spawn character %s belonging to %s" % [username, character_id, character.get("account")])
		if network_handler:
			network_handler.send_spawn_rejected(peer_id, "Character does not belong to your account")
		return

	# Build player data for spawning
	# Default spawn at tile (10, 7) which is center of the open area
	# Pixel position: 10 * 128 + 64 = 1344, 7 * 128 + 64 = 960
	var default_spawn_x = 1344
	var default_spawn_y = 960
	var spawn_position = Vector2(character.get("position_x", default_spawn_x), character.get("position_y", default_spawn_y))

	# COLLISION-FREE SPAWN: Find nearest free tile if spawn position is blocked
	if map_manager:
		spawn_position = map_manager.find_nearest_free_spawn("sample_map", spawn_position)

	var player_data = {
		"peer_id": peer_id,
		"username": username,
		"character_id": character_id,
		"character_name": character.get("name", "Unknown"),
		"class_name": character.get("class_name", "Warrior"),
		"level": character.get("level", 1),
		"position": spawn_position,
		"hp": character.get("hp", 100),
		"max_hp": character.get("max_hp", 100),
		"mp": character.get("mp", 50),
		"max_mp": character.get("max_mp", 50),
		"base_stats": character.get("stats", {}),
		"derived_stats": character.get("derived_stats", {})
	}

	# Log the class for debugging combat role issues
	print("[PLAYER_MANAGER] Spawning %s with class: %s" % [player_data.character_name, player_data.class_name])

	# Add to connected players
	connected_players[peer_id] = player_data
	player_positions[peer_id] = spawn_position

	# Register with spatial manager for interest management
	if spatial_manager:
		spatial_manager.register_entity(peer_id, spawn_position, "player")

	log_message("[PLAYER_MANAGER] Spawned character '%s' for user %s at %s" % [player_data.character_name, username, spawn_position])
	log_activity("[color=cyan]SPAWNED: %s (%s)[/color]" % [player_data.character_name, username])

	# Send spawn accepted to the requesting client
	if network_handler:
		network_handler.send_spawn_accepted(peer_id, player_data)

	# Notify other players about the new player
	for other_peer_id in connected_players:
		if other_peer_id != peer_id:
			if network_handler:
				network_handler.send_player_spawned(other_peer_id, peer_id, player_data)

	# Send existing players to the new player
	for other_peer_id in connected_players:
		if other_peer_id != peer_id:
			var other_data = connected_players[other_peer_id]
			if network_handler:
				network_handler.send_player_spawned(peer_id, other_peer_id, other_data)

	# Send all NPCs to the new player
	if npc_manager:
		npc_manager.send_npcs_to_player(peer_id)


# ========== CHARACTER VALIDATION ==========

func validate_account_characters(username: String, characters: Array) -> Dictionary:
	"""Validate character list for an account, fixing any issues"""
	var result = {
		"valid": true,
		"reason": "All characters valid",
		"valid_characters": []
	}

	if characters == null:
		result.valid = false
		result.reason = "Character list is null"
		return result

	for character in characters:
		if character == null:
			continue

		# Validate required fields
		var char_id = character.get("character_id", "")
		var char_name = character.get("name", "")

		if char_id.is_empty() or char_name.is_empty():
			print("[PLAYER_MANAGER] Skipping invalid character (missing id or name): %s" % character)
			continue

		# Ensure level exists and is valid
		var level = character.get("level", 0)
		if level <= 0:
			print("[PLAYER_MANAGER] Fixing character %s level from %s to 1" % [char_name, level])
			character["level"] = 1

		# Ensure class exists
		if not character.has("class_name") or character.class_name.is_empty():
			print("[PLAYER_MANAGER] Fixing character %s missing class to Warrior" % char_name)
			character["class_name"] = "Warrior"

		result.valid_characters.append(character)

	if result.valid_characters.is_empty() and characters.size() > 0:
		result.valid = false
		result.reason = "No valid characters found"

	return result


# ========== PLAYER DATA ACCESS ==========

func get_player_data(peer_id: int) -> Dictionary:
	"""Get player data for a specific peer"""
	return connected_players.get(peer_id, {})


func remove_player(peer_id: int):
	"""Remove a player when they disconnect or despawn"""
	if connected_players.has(peer_id):
		var player_data = connected_players[peer_id]
		log_message("[PLAYER_MANAGER] Removing player %s (peer %d)" % [player_data.get("character_name", "Unknown"), peer_id])

		# Save character position to database before removing
		var character_id = player_data.get("character_id", "")
		var position = player_positions.get(peer_id, Vector2.ZERO)
		if not character_id.is_empty():
			# Get current character data and update position
			var char_result = char_service.get_character(character_id)
			if char_result.success:
				var char_data = char_result.character
				char_data["position_x"] = position.x
				char_data["position_y"] = position.y
				char_service.save_character(character_id, char_data)

		# Remove from tracking
		connected_players.erase(peer_id)
		player_positions.erase(peer_id)
		player_teams.erase(peer_id)

		# Remove from spatial manager
		if spatial_manager:
			spatial_manager.unregister_entity(peer_id)

		# Notify other players
		for other_peer_id in connected_players:
			if network_handler:
				network_handler.send_player_despawned(other_peer_id, peer_id)


func update_player_position(peer_id: int, position: Vector2):
	"""Update a player's position"""
	if connected_players.has(peer_id):
		player_positions[peer_id] = position
		connected_players[peer_id]["position"] = position

		# Update spatial manager
		if spatial_manager:
			spatial_manager.update_entity_position(peer_id, position)


# ========== REWARD DISTRIBUTION ==========

func grant_rewards(peer_id: int, rewards: Dictionary):
	"""Grant XP/Gold rewards to a player character and save to DB"""
	if not connected_players.has(peer_id):
		print("[PLAYER_MANAGER] ERROR: Cannot grant rewards - peer %d not connected" % peer_id)
		return

	var player_data = connected_players[peer_id]
	var character_id = player_data.get("character_id", "")
	
	# Load authoritative data from DB to ensure no sync issues
	var char_result = char_service.get_character(character_id)
	if not char_result.success:
		print("[PLAYER_MANAGER] ERROR: Character %s not found in DB" % character_id)
		return
		
	var character = char_result.character
	var xp_gain = rewards.get("xp", 0)
	var gold_gain = rewards.get("gold", 0)
	
	# Apply rewards
	character["xp"] = character.get("xp", 0) + xp_gain
	
	# Handle Gold (stored in character or separate inventory table?)
	# For now assuming simple field in character data
	character["gold"] = character.get("gold", 0) + gold_gain
	
	# Level Up Logic
	var current_level = character.get("level", 1)
	var xp_needed = _calculate_xp_for_next_level(current_level)
	
	var leveled_up = false
	while character["xp"] >= xp_needed:
		character["level"] += 1
		character["xp"] -= xp_needed
		current_level += 1
		xp_needed = _calculate_xp_for_next_level(current_level)
		leveled_up = true
		
		# Stat Growth (Simple +5% for now, or fixed gains)
		# Real stat growth should probably read from Class tables
		_apply_stat_growth(character)
		
	if leveled_up:
		log_message("[PLAYER_MANAGER] Player %s leveled up to %d!" % [character.get("name"), character["level"]])
		# Full Heal on Level Up
		character["hp"] = character.get("max_hp", 100)
		character["mp"] = character.get("max_mp", 50)
	
	# Save back to DB
	char_service.save_character(character_id, character)
	
	# Update cached session data
	connected_players[peer_id]["level"] = character["level"]
	
	# Send update to client (optional - BattleEnd packet handles the UI, but this ensures sync)
	# We rely on receive_battle_end containing the rewards for now.

func _calculate_xp_for_next_level(level: int) -> int:
	# Simple curve: 100 * Level
	return 100 * level

func _apply_stat_growth(character: Dictionary):
	# Basic stat growth (+2 to all stats, +10 HP/MP)
	# In future, read growth rates from Class JSON
	if character.has("stats"):
		for stat in character.stats:
			character.stats[stat] += 2
	
	character["max_hp"] = character.get("max_hp", 100) + 20
	character["max_mp"] = character.get("max_mp", 50) + 10


# ========== MAP TRANSITIONS ==========

func update_player_map(peer_id: int, map_name: String, position: Vector2) -> void:
	"""Update player's current map and position after a map transition"""
	var old_map = player_maps.get(peer_id, "sample_map")

	# Update map and position
	player_maps[peer_id] = map_name
	player_positions[peer_id] = position

	# Update spatial manager
	if spatial_manager:
		spatial_manager.update_entity_position(peer_id, position)

	# Update connected_players data
	if connected_players.has(peer_id):
		connected_players[peer_id]["current_map"] = map_name
		connected_players[peer_id]["position"] = position

	log_message("[PLAYER_MANAGER] Player %d moved from %s to %s at %s" % [peer_id, old_map, map_name, position])

	# TODO: Future - notify other players on the old map that this player left
	# TODO: Future - notify players on the new map that this player joined


func get_player_map(peer_id: int) -> String:
	"""Get the map name a player is currently on"""
	return player_maps.get(peer_id, "sample_map")


func get_players_on_map(map_name: String) -> Array:
	"""Get all peer IDs of players on a specific map"""
	var players = []
	for peer_id in player_maps:
		if player_maps[peer_id] == map_name:
			players.append(peer_id)
	return players


# ========== UTILITY ==========

func log_message(msg: String):
	if server_world and server_world.has_method("log_message"):
		server_world.log_message(msg)
	else:
		print(msg)


func log_activity(msg: String):
	if server_world and server_world.has_method("log_activity"):
		server_world.log_activity(msg)
	else:
		print(msg)
