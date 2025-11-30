class_name BattleDataLoader
extends Node
## Battle Data Loader - Handles loading character data, sprites, and squads
## Extracted from battle_window.gd for modularity

# Sprite atlas constants
const SPRITE_SIZE = 32
const ROWS_PER_ATLAS = 322
const COLS_PER_ROW = 12

# Atlas textures (loaded once, reused everywhere)
static var sprite_atlas_textures: Array = []

## ========== SPRITE ATLAS LOADING ==========

static func load_sprite_atlases() -> bool:
	"""Load sprite atlas textures for character rendering"""
	if sprite_atlas_textures.size() > 0:
		return true  # Already loaded

	var atlas1 = load("res://assets-odyssey/sprites_part1.png")
	var atlas2 = load("res://assets-odyssey/sprites_part2.png")

	if atlas1 and atlas2:
		sprite_atlas_textures.append(atlas1)
		sprite_atlas_textures.append(atlas2)
		print("✓ Loaded sprite atlases")
		return true
	else:
		print("ERROR: Could not load sprite atlases")
		return false

static func get_sprite_texture_from_coords(atlas_index: int, row: int, col: int) -> Texture2D:
	"""Create texture from sprite atlas coordinates"""
	if sprite_atlas_textures.is_empty():
		load_sprite_atlases()

	if atlas_index >= sprite_atlas_textures.size():
		print("ERROR: Invalid atlas index: ", atlas_index)
		return null

	var atlas_texture = sprite_atlas_textures[atlas_index]
	var local_row = row if row < ROWS_PER_ATLAS else row - ROWS_PER_ATLAS

	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = atlas_texture
	atlas_tex.region = Rect2(
		col * SPRITE_SIZE,
		local_row * SPRITE_SIZE,
		SPRITE_SIZE,
		SPRITE_SIZE
	)

	return atlas_tex

## ========== CHARACTER FILE LOADING ==========

static func load_character_file(path: String) -> Dictionary:
	"""Load character data from JSON file"""
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) == OK:
		return json.data
	else:
		print("ERROR: Failed to parse ", path)
		return {}

static func load_player_character() -> Dictionary:
	"""Load player character from GameState, fallback to file if needed"""

	# CRITICAL: Check GameState FIRST for newly created/selected character
	# GameState.current_character is set by character_select_screen.gd when user enters world
	var gamestate_character = GameState.current_character
	if not gamestate_character.is_empty():
		print("✓ Loaded player character from GameState: ", gamestate_character.get("name", gamestate_character.get("character_name", "Unknown")))

		# Ensure current HP/MP/Energy are initialized
		var player_character = gamestate_character.duplicate()

		# Add character_name field for consistency with NPC data (player data uses "name", NPCs use "character_name")
		if player_character.has("name") and not player_character.has("character_name"):
			player_character["character_name"] = player_character["name"]

		# Initialize HP
		if not player_character.has("hp"):
			if player_character.has("max_hp"):
				player_character["hp"] = player_character.max_hp
			elif player_character.has("derived_stats"):
				player_character["hp"] = player_character.derived_stats.get("max_hp", 100)
			else:
				player_character["hp"] = 100

		# Ensure max_hp is set
		if not player_character.has("max_hp"):
			if player_character.has("derived_stats"):
				player_character["max_hp"] = player_character.derived_stats.get("max_hp", 100)
			else:
				player_character["max_hp"] = 100

		# Initialize MP
		if not player_character.has("mp"):
			if player_character.has("max_mp"):
				player_character["mp"] = player_character.max_mp
			elif player_character.has("derived_stats"):
				player_character["mp"] = player_character.derived_stats.get("max_mp", 50)
			else:
				player_character["mp"] = 50

		# Ensure max_mp is set
		if not player_character.has("max_mp"):
			if player_character.has("derived_stats"):
				player_character["max_mp"] = player_character.derived_stats.get("max_mp", 50)
			else:
				player_character["max_mp"] = 50

		# Initialize Energy
		if not player_character.has("energy"):
			if player_character.has("derived_stats"):
				player_character["energy"] = player_character.derived_stats.get("max_ep", 100)
			else:
				player_character["energy"] = 100

		# Ensure max_energy is set
		if not player_character.has("max_energy"):
			if player_character.has("derived_stats"):
				player_character["max_energy"] = player_character.derived_stats.get("max_ep", 100)
			else:
				player_character["max_energy"] = 100

		return player_character

	# Fallback: Try to load from file (legacy support)
	var temp_file_path = "user://selected_character.json"

	if FileAccess.file_exists(temp_file_path):
		var file = FileAccess.open(temp_file_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			if json.parse(json_text) == OK:
				var player_character = json.data

				# Initialize HP
				if not player_character.has("hp"):
					if player_character.has("derived_stats"):
						player_character["hp"] = player_character.derived_stats.get("max_hp", 100)
					else:
						player_character["hp"] = 100
				if not player_character.has("max_hp"):
					if player_character.has("derived_stats"):
						player_character["max_hp"] = player_character.derived_stats.get("max_hp", 100)
					else:
						player_character["max_hp"] = 100

				# Initialize MP
				if not player_character.has("mp"):
					if player_character.has("derived_stats"):
						player_character["mp"] = player_character.derived_stats.get("max_mp", 50)
					else:
						player_character["mp"] = 50
				if not player_character.has("max_mp"):
					if player_character.has("derived_stats"):
						player_character["max_mp"] = player_character.derived_stats.get("max_mp", 50)
					else:
						player_character["max_mp"] = 50

				# Initialize Energy
				if not player_character.has("energy"):
					if player_character.has("derived_stats"):
						player_character["energy"] = player_character.derived_stats.get("max_ep", 100)
					else:
						player_character["energy"] = 100
				if not player_character.has("max_energy"):
					if player_character.has("derived_stats"):
						player_character["max_energy"] = player_character.derived_stats.get("max_ep", 100)
					else:
						player_character["max_energy"] = 100

				print("✓ Loaded player character from file: ", player_character.get("character_name", "Unknown"))
				return player_character
			else:
				print("ERROR: Failed to parse player character JSON")
				return create_default_player()
		else:
			print("ERROR: Failed to open player character file")
			return create_default_player()
	else:
		print("WARN: No selected character found in GameState or file, using default")
		return create_default_player()

static func create_default_player() -> Dictionary:
	"""Create a default player for testing"""
	var player_character = {
		"character_name": "Test Hero",
		"class_template": "Warrior",
		"type": "player",
		"element": "Fire",
		"level": 1,
		"base_stats": {
			"str": 15,
			"dex": 12,
			"int": 8,
			"vit": 14,
			"wis": 8,
			"cha": 10
		},
		"derived_stats": {
			"max_hp": 178,
			"max_mp": 108,
			"max_ep": 66
		},
		"animations": {}
	}
	# Set current HP/MP/Energy to max
	player_character["hp"] = player_character.derived_stats.get("max_hp", 178)
	player_character["max_hp"] = player_character.derived_stats.get("max_hp", 178)
	player_character["mp"] = player_character.derived_stats.get("max_mp", 108)
	player_character["max_mp"] = player_character.derived_stats.get("max_mp", 108)
	player_character["energy"] = player_character.derived_stats.get("max_ep", 66)
	player_character["max_energy"] = player_character.derived_stats.get("max_ep", 66)
	return player_character

## ========== SQUAD LOADING ==========

static func load_enemy_squad() -> Array:
	"""Load 6 random NPCs from characters/npcs/ directory"""
	var enemy_squad = []
	var npcs_dir = "res://characters/npcs/"
	var dir = DirAccess.open(npcs_dir)

	if not dir:
		print("ERROR: Could not open NPCs directory")
		return enemy_squad

	# Collect all NPC files
	var npc_files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			npc_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("Found ", npc_files.size(), " NPC files")

	# Select 6 random NPCs
	npc_files.shuffle()
	for i in range(min(6, npc_files.size())):
		var npc_path = npcs_dir + npc_files[i]
		var npc_data = load_character_file(npc_path)
		if npc_data:
			# Set current HP/MP/Energy and their max values
			if npc_data.has("derived_stats"):
				var max_hp_val = npc_data.derived_stats.get("max_hp", 100)
				var max_mp_val = npc_data.derived_stats.get("max_mp", 50)
				var max_energy_val = npc_data.derived_stats.get("max_ep", 100)

				npc_data["hp"] = max_hp_val
				npc_data["max_hp"] = max_hp_val
				npc_data["mp"] = max_mp_val
				npc_data["max_mp"] = max_mp_val
				npc_data["energy"] = max_energy_val
				npc_data["max_energy"] = max_energy_val
			else:
				npc_data["hp"] = 100
				npc_data["max_hp"] = 100
				npc_data["mp"] = 50
				npc_data["max_mp"] = 50
				npc_data["energy"] = 100
				npc_data["max_energy"] = 100
			enemy_squad.append(npc_data)
			print("  Loaded enemy: ", npc_data.get("character_name", "Unknown"))

	return enemy_squad

static func load_server_enemy_squad(enemies: Array) -> Array:
	"""Load enemy squad from server combat data"""
	var enemy_squad = []

	if enemies.is_empty():
		print("WARNING: Server sent empty enemy squad, using default enemies")
		return load_enemy_squad()

	for enemy_data in enemies:
		if enemy_data is Dictionary:
			# Server only sends stats, not sprite data
			# Load full character data from NPC file
			var enemy_class = enemy_data.get("class", "Rogue")
			var npc_file_path = "res://characters/npcs/" + enemy_class + ".json"
			var full_character = {}

			if FileAccess.file_exists(npc_file_path):
				var file = FileAccess.open(npc_file_path, FileAccess.READ)
				if file:
					var json_text = file.get_as_text()
					file.close()
					var json = JSON.new()
					if json.parse(json_text) == OK:
						full_character = json.data

			# Merge server stats into full character data
			full_character["character_name"] = enemy_data.get("name", enemy_class)
			full_character["name"] = enemy_data.get("name", enemy_class)
			full_character["level"] = enemy_data.get("level", 1)
			full_character["hp"] = enemy_data.get("hp", 100)
			full_character["max_hp"] = enemy_data.get("max_hp", 100)
			full_character["attack"] = enemy_data.get("attack", 10)
			full_character["defense"] = enemy_data.get("defense", 10)

			# Set MP and Energy from character file's derived_stats if not sent by server
			if full_character.has("derived_stats"):
				if not enemy_data.has("mp"):
					full_character["mp"] = full_character.derived_stats.get("max_mp", 50)
					full_character["max_mp"] = full_character.derived_stats.get("max_mp", 50)
				else:
					full_character["mp"] = enemy_data.get("mp", 50)
					full_character["max_mp"] = enemy_data.get("max_mp", 50)

				if not enemy_data.has("energy"):
					full_character["energy"] = full_character.derived_stats.get("max_ep", 100)
					full_character["max_energy"] = full_character.derived_stats.get("max_ep", 100)
				else:
					full_character["energy"] = enemy_data.get("energy", 100)
					full_character["max_energy"] = enemy_data.get("max_energy", 100)

			enemy_squad.append(full_character)

	print("Loaded %d enemies from server" % enemy_squad.size())
	return enemy_squad

static func load_ally_squad() -> Array:
	"""Load 6 allies: player character + 5 random NPCs"""
	var ally_squad = []

	# First, load the player character
	var player_character = load_player_character()
	if player_character:
		ally_squad.append(player_character)
		print("  Loaded ally (player): ", player_character.get("character_name", "Unknown"))

	# Then load 5 random NPCs
	var npcs_dir = "res://characters/npcs/"
	var dir = DirAccess.open(npcs_dir)

	if not dir:
		print("ERROR: Could not open NPCs directory for allies")
		return ally_squad

	# Collect all NPC files
	var npc_files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			npc_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("Found ", npc_files.size(), " NPC files for allies")

	# Select 5 random NPCs for remaining allies
	npc_files.shuffle()
	for i in range(min(5, npc_files.size())):
		var npc_path = npcs_dir + npc_files[i]
		var npc_data = load_character_file(npc_path)
		if npc_data:
			# Set current HP/MP/Energy and their max values
			if npc_data.has("derived_stats"):
				var max_hp_val = npc_data.derived_stats.get("max_hp", 100)
				var max_mp_val = npc_data.derived_stats.get("max_mp", 50)
				var max_energy_val = npc_data.derived_stats.get("max_ep", 100)

				npc_data["hp"] = max_hp_val
				npc_data["max_hp"] = max_hp_val
				npc_data["mp"] = max_mp_val
				npc_data["max_mp"] = max_mp_val
				npc_data["energy"] = max_energy_val
				npc_data["max_energy"] = max_energy_val
			else:
				npc_data["hp"] = 100
				npc_data["max_hp"] = 100
				npc_data["mp"] = 50
				npc_data["max_mp"] = 50
				npc_data["energy"] = 100
				npc_data["max_energy"] = 100
			ally_squad.append(npc_data)
			print("  Loaded ally (NPC): ", npc_data.get("character_name", "Unknown"))

	return ally_squad

static func load_server_ally_squad() -> Array:
	"""Load ally squad from player's team_npc_ids in GameState"""
	var ally_squad = []

	# First, load the player character
	var player_character = load_player_character()
	if player_character:
		ally_squad.append(player_character)
		print("  Loaded ally (player): ", player_character.get("character_name", "Unknown"))

	# Get team_npc_ids from GameState/current character
	var team_npc_ids = []
	if GameState.current_character and GameState.current_character.has("team_npc_ids"):
		team_npc_ids = GameState.current_character.get("team_npc_ids", [])

	if team_npc_ids.is_empty():
		print("WARNING: No team_npc_ids found in GameState, falling back to random NPCs")
		# Fallback to random NPCs if no team data
		var random_allies = load_ally_squad()
		# Return only the random NPCs (skip player since we already added it)
		for i in range(1, random_allies.size()):
			ally_squad.append(random_allies[i])
		return ally_squad

	print("Loading %d team NPCs from team_npc_ids: %s" % [team_npc_ids.size(), team_npc_ids])

	# Load each team NPC by ID
	for npc_id in team_npc_ids:
		# Map NPC ID to class name
		var npc_class = get_npc_class_by_id(int(npc_id))
		var npc_path = "res://characters/npcs/" + npc_class + ".json"
		var npc_data = load_character_file(npc_path)

		if npc_data:
			# Set current HP/MP/Energy
			if npc_data.has("derived_stats"):
				var max_hp_val = npc_data.derived_stats.get("max_hp", 100)
				var max_mp_val = npc_data.derived_stats.get("max_mp", 50)
				var max_energy_val = npc_data.derived_stats.get("max_ep", 100)

				npc_data["hp"] = max_hp_val
				npc_data["max_hp"] = max_hp_val
				npc_data["mp"] = max_mp_val
				npc_data["max_mp"] = max_mp_val
				npc_data["energy"] = max_energy_val
				npc_data["max_energy"] = max_energy_val
			else:
				npc_data["hp"] = 100
				npc_data["max_hp"] = 100
				npc_data["mp"] = 50
				npc_data["max_mp"] = 50
				npc_data["energy"] = 100
				npc_data["max_energy"] = 100

			ally_squad.append(npc_data)
			print("  Loaded ally (Team NPC #%d): %s" % [npc_id, npc_data.get("character_name", "Unknown")])
		else:
			print("ERROR: Could not load NPC #%d (class: %s)" % [npc_id, npc_class])

	return ally_squad

static func get_npc_class_by_id(npc_id: int) -> String:
	"""Map NPC ID to class name based on server's NPC spawn order"""
	# Based on server logs: NPC #1=Rogue, #2=Goblin, #3=OrcWarrior, #4=DarkMage, #5=EliteGuard, #6=RogueBandit
	match npc_id:
		1: return "Rogue"
		2: return "Goblin"
		3: return "OrcWarrior"
		4: return "DarkMage"
		5: return "EliteGuard"
		6: return "RogueBandit"
		_:
			print("WARNING: Unknown NPC ID %d, defaulting to Rogue" % npc_id)
			return "Rogue"  # Default fallback

## ========== SPRITE LOADING ==========

static func load_character_sprite(character: Dictionary, sprite_node: TextureRect):
	"""Load character sprite from animation data (walk_down_1 for idle)"""
	if not character.has("animations"):
		print("WARN: Character has no animations")
		return

	if not character.animations.has("walk_down_1"):
		print("WARN: Character missing walk_down_1 animation")
		return

	var walk_down_frames = character.animations["walk_down_1"]
	if walk_down_frames.size() == 0:
		print("WARN: walk_down_1 animation is empty")
		return

	# Get first frame of walk_down_1
	var frame_data = walk_down_frames[0]
	var atlas_index = frame_data.get("atlas_index", 0)
	var row = frame_data.get("row", 0)
	var col = frame_data.get("col", 0)

	# Create texture from atlas
	var texture = get_sprite_texture_from_coords(atlas_index, row, col)
	if texture:
		sprite_node.texture = texture
		print("✓ Loaded sprite for ", character.get("character_name", "Unknown"))
	else:
		print("ERROR: Failed to create sprite texture")
