class_name SpriteMakerIO extends RefCounted
## Handles save, load, and upload operations for Sprite Maker

signal character_saved(name: String, type: String)
signal character_loaded(data: Dictionary, type: String)
signal status_changed(message: String)
signal error_occurred(message: String)

const ROWS_PER_ATLAS = 512

# Reference to stats panel for reading stat values
var stats_panel: SpriteMakerStats = null
# Reference to grid for getting textures
var sprite_grid: SpriteMakerGrid = null

# Animation names (needed for auto-assign)
var animation_names: Array = [
	"walk_up_1", "walk_up_2", "attack_up",
	"walk_down_1", "walk_down_2", "attack_down",
	"walk_left_1", "walk_left_2", "attack_left",
	"walk_right_1", "walk_right_2", "attack_right"
]


func initialize(stats: SpriteMakerStats, grid: SpriteMakerGrid) -> bool:
	stats_panel = stats
	sprite_grid = grid
	return stats_panel != null and sprite_grid != null


func save_character(char_name: String, current_type: String, character_data: Dictionary) -> bool:
	"""Save character to JSON file"""
	if char_name.is_empty():
		error_occurred.emit("Enter character name first")
		return false

	# Determine save directory based on current type
	var save_dir = "res://characters/classes/" if current_type == "class" else "res://characters/npcs/"

	# Create directories if they don't exist
	if not DirAccess.dir_exists_absolute("res://characters/"):
		DirAccess.open("res://").make_dir("characters")
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.open("res://characters/").make_dir("classes" if current_type == "class" else "npcs")

	# Get all stats from stats panel
	var stats = stats_panel.get_all_stats() if stats_panel else _get_default_stats()

	# Get element text
	var element = "None"
	if stats_panel and stats_panel.element_option:
		element = stats_panel.element_option.get_item_text(stats.element)

	# Get AI archetype text
	var ai_archetype = "AGGRESSIVE"
	if stats_panel and stats_panel.ai_option:
		var text = stats_panel.ai_option.get_item_text(stats.ai_archetype)
		ai_archetype = text.split(" ")[0]

	# Calculate defensive and offensive stats
	var phys_def = int(stats.vit * 0.5) + int(stats.str * 0.2)
	var mag_def = int(stats.wis * 0.8) + int(stats.int * 0.2)
	var phys_dmg = (stats.str * 2) + int(stats.dex * 0.5)
	var mag_dmg = int(stats.int * 2.5) + int(stats.wis * 0.5)

	# Build save data
	var save_data = {
		"character_name": char_name,
		"type": current_type,
		"element": element,
		"combat_role": stats.combat_role if stats.combat_role != "" else "Melee",
		"ai_archetype": ai_archetype,
		"level_range": {
			"min": stats.min_level,
			"max": stats.max_level
		},
		"loot_table": {
			"xp_reward": stats.xp_reward,
			"gold_reward": stats.gold_reward,
			"items": []
		},
		"level": stats.level,
		"xp": 0,
		"base_stats": {
			"str": stats.str,
			"dex": stats.dex,
			"int": stats.int,
			"vit": stats.vit,
			"wis": stats.wis,
			"cha": stats.cha
		},
		"derived_stats": {
			"max_hp": stats.hp,
			"max_mp": stats.mp,
			"max_ep": stats.ep,
			"phys_def": phys_def,
			"mag_def": mag_def,
			"phys_dmg": phys_dmg,
			"mag_dmg": mag_dmg
		},
		"manual_stats": {
			"hp": stats_panel.manual_hp if stats_panel else -1,
			"mp": stats_panel.manual_mp if stats_panel else -1,
			"ep": stats_panel.manual_ep if stats_panel else -1
		},
		"flavor_text": {
			"description": stats.description,
			"backstory": ""
		},
		"created_date": Time.get_datetime_string_from_system(),
		"animations": {}
	}

	# Convert texture references to atlas coordinates for saving
	for anim_name in character_data.get("animations", {}):
		save_data.animations[anim_name] = []
		for frame in character_data.animations[anim_name]:
			save_data.animations[anim_name].append({
				"atlas_index": frame.atlas_index,
				"row": frame.row,
				"col": frame.col
			})

	# Save to JSON
	var json_string = JSON.stringify(save_data, "\t")
	var save_path = save_dir + char_name + ".json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		status_changed.emit("Saved %s: %s" % [current_type, char_name])

		# Print animation summary
		print("Saved %s: %s" % [current_type, char_name])
		for anim in character_data.get("animations", {}):
			var count = character_data.animations[anim].size()
			if count > 0:
				print("  %s: %d frames" % [anim, count])

		character_saved.emit(char_name, current_type)
		return true
	else:
		error_occurred.emit("Could not save " + char_name)
		return false


func load_character(load_path: String, char_name: String) -> Dictionary:
	"""Load character data from JSON file path and return parsed data"""
	if not FileAccess.file_exists(load_path):
		error_occurred.emit("Character '%s' not found" % char_name)
		return {}

	var file = FileAccess.open(load_path, FileAccess.READ)
	if not file:
		error_occurred.emit("Could not open " + char_name)
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		error_occurred.emit("Invalid character file: " + char_name)
		return {}

	var save_data = json.data
	var loaded_type = save_data.get("type", "class")

	# Populate stats panel with loaded data
	if stats_panel:
		var stats_to_load = {}

		if save_data.has("element"):
			# Find element index
			if stats_panel.element_option:
				for i in range(stats_panel.element_option.item_count):
					if stats_panel.element_option.get_item_text(i) == save_data.element:
						stats_to_load["element"] = i
						break

		if save_data.has("level"):
			stats_to_load["level"] = save_data.level

		if save_data.has("base_stats"):
			var base = save_data.base_stats
			stats_to_load["str"] = base.get("str", 10)
			stats_to_load["dex"] = base.get("dex", 10)
			stats_to_load["int"] = base.get("int", 10)
			stats_to_load["vit"] = base.get("vit", 10)
			stats_to_load["wis"] = base.get("wis", 10)
			stats_to_load["cha"] = base.get("cha", 10)

		if save_data.has("ai_archetype"):
			# Find AI index
			if stats_panel.ai_option:
				var archetype = save_data.ai_archetype
				for i in range(stats_panel.ai_option.item_count):
					if stats_panel.ai_option.get_item_text(i).begins_with(archetype):
						stats_to_load["ai_archetype"] = i
						break

		if save_data.has("level_range"):
			var range_data = save_data.level_range
			stats_to_load["min_level"] = range_data.get("min", 1)
			stats_to_load["max_level"] = range_data.get("max", 1)

		if save_data.has("loot_table"):
			var loot = save_data.loot_table
			stats_to_load["xp_reward"] = loot.get("xp_reward", 50)
			stats_to_load["gold_reward"] = loot.get("gold_reward", 10)

		if save_data.has("combat_role"):
			stats_to_load["combat_role"] = save_data.combat_role

		if save_data.has("manual_stats"):
			var manual = save_data.manual_stats
			stats_to_load["hp"] = manual.get("hp", -1)
			stats_to_load["mp"] = manual.get("mp", -1)
			stats_to_load["ep"] = manual.get("ep", -1)

		if save_data.has("flavor_text"):
			stats_to_load["description"] = save_data.flavor_text.get("description", "")

		stats_panel.set_type(loaded_type)
		stats_panel.set_stats(stats_to_load)

	# Build character_data structure with reconstructed animations
	var character_data = {
		"name": save_data.get("character_name", char_name),
		"animations": {}
	}

	# Initialize empty animations
	for anim_name in animation_names:
		character_data.animations[anim_name] = []

	# Reconstruct animations with textures
	for anim_name in save_data.get("animations", {}):
		character_data.animations[anim_name] = []
		for frame_data in save_data.animations[anim_name]:
			var atlas_idx = frame_data.get("atlas_index", 0)
			var row = frame_data.get("row", 0)
			var col = frame_data.get("col", 0)

			var sprite_data = {
				"atlas_index": atlas_idx,
				"row": row,
				"col": col,
				"local_row": row if row < ROWS_PER_ATLAS else row - ROWS_PER_ATLAS
			}

			var texture = sprite_grid.get_sprite_texture_from_data(sprite_data) if sprite_grid else null
			if texture:
				character_data.animations[anim_name].append({
					"atlas_index": atlas_idx,
					"row": row,
					"col": col,
					"texture": texture
				})

	status_changed.emit("Loaded %s: %s" % [loaded_type, char_name])
	character_loaded.emit(character_data, loaded_type)
	return character_data


func upload_character(char_name: String, current_type: String, character_data: Dictionary) -> bool:
	"""Upload character to LOCAL server only"""
	# SECURITY: Only allow uploads to local development server
	if not ConfigManager.is_local_server():
		print("[SpriteMakerIO] Upload blocked: Not connected to local server")
		error_occurred.emit("Uploads only allowed to local server (127.0.0.1)")
		return false

	# Check if admin
	if GameState.admin_level < 1:
		print("[SpriteMakerIO] Upload failed: Not an admin")
		error_occurred.emit("Upload requires admin privileges")
		return false

	if char_name.is_empty():
		error_occurred.emit("Character must have a name before uploading")
		return false

	# Prepare upload data (same format as save)
	var upload_data = _prepare_upload_data(char_name, current_type, character_data)
	if upload_data.is_empty():
		error_occurred.emit("Failed to prepare character data for upload")
		return false

	# Call appropriate RPC on server (local only)
	if current_type == "class":
		ServerConnection.upload_class.rpc(char_name, upload_data)
		print("[SpriteMakerIO] Uploading class to LOCAL server: %s" % char_name)
		status_changed.emit("Uploading class '%s' to local server..." % char_name)
	else:
		ServerConnection.upload_npc.rpc(char_name, upload_data)
		print("[SpriteMakerIO] Uploading NPC to LOCAL server: %s" % char_name)
		status_changed.emit("Uploading NPC '%s' to local server..." % char_name)

	return true


func _prepare_upload_data(char_name: String, current_type: String, character_data: Dictionary) -> Dictionary:
	"""Prepare character data for server upload"""
	var stats = stats_panel.get_all_stats() if stats_panel else _get_default_stats()

	var element = "None"
	if stats_panel and stats_panel.element_option:
		element = stats_panel.element_option.get_item_text(stats.element)

	var ai_archetype = "AGGRESSIVE"
	if stats_panel and stats_panel.ai_option:
		var text = stats_panel.ai_option.get_item_text(stats.ai_archetype)
		ai_archetype = text.split(" ")[0]

	var phys_def = int(stats.vit * 0.5) + int(stats.str * 0.2)
	var mag_def = int(stats.wis * 0.8) + int(stats.int * 0.2)
	var phys_dmg = (stats.str * 2) + int(stats.dex * 0.5)
	var mag_dmg = int(stats.int * 2.5) + int(stats.wis * 0.5)

	var upload_data = {
		"character_name": char_name,
		"type": current_type,
		"element": element,
		"combat_role": stats.combat_role if stats.combat_role != "" else "Melee",
		"ai_archetype": ai_archetype,
		"level_range": {
			"min": stats.min_level,
			"max": stats.max_level
		},
		"loot_table": {
			"xp_reward": stats.xp_reward,
			"gold_reward": stats.gold_reward,
			"items": []
		},
		"level": stats.level,
		"xp": 0,
		"base_stats": {
			"str": stats.str,
			"dex": stats.dex,
			"int": stats.int,
			"vit": stats.vit,
			"wis": stats.wis,
			"cha": stats.cha
		},
		"derived_stats": {
			"max_hp": stats.hp,
			"max_mp": stats.mp,
			"max_ep": stats.ep,
			"phys_def": phys_def,
			"mag_def": mag_def,
			"phys_dmg": phys_dmg,
			"mag_dmg": mag_dmg
		},
		"manual_stats": {
			"hp": stats_panel.manual_hp if stats_panel else -1,
			"mp": stats_panel.manual_mp if stats_panel else -1,
			"ep": stats_panel.manual_ep if stats_panel else -1
		},
		"flavor_text": {
			"description": stats.description,
			"backstory": ""
		},
		"created_date": Time.get_datetime_string_from_system(),
		"animations": {}
	}

	# Convert animations to atlas coordinates
	for anim_name in character_data.get("animations", {}):
		upload_data.animations[anim_name] = []
		for frame in character_data.animations[anim_name]:
			upload_data.animations[anim_name].append({
				"atlas_index": frame.atlas_index,
				"row": frame.row,
				"col": frame.col
			})

	return upload_data


func _get_default_stats() -> Dictionary:
	"""Return default stats when stats panel is not available"""
	return {
		"element": 0,
		"level": 1,
		"str": 10, "dex": 10, "int": 10, "vit": 10, "wis": 10, "cha": 10,
		"hp": 50, "mp": 50, "ep": 30,
		"ai_archetype": 0,
		"min_level": 1, "max_level": 1,
		"xp_reward": 50, "gold_reward": 10,
		"combat_role": "Melee",
		"description": ""
	}


func delete_character(char_name: String, char_type: String) -> bool:
	"""Delete character file"""
	var dir = "classes" if char_type == "class" else "npcs"
	var file_path = "res://characters/%s/%s.json" % [dir, char_name]

	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		status_changed.emit("Deleted %s: %s" % [char_type, char_name])
		return true
	else:
		error_occurred.emit("%s file not found: %s" % [char_type.capitalize(), char_name])
		return false
