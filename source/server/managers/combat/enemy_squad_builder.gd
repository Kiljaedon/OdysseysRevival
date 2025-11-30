extends Node
class_name EnemySquadBuilder

## Enemy Squad Builder - Phase 1 Step 1.1 Refactoring
## Extracts enemy squad generation logic from CombatManager
## Pure utility class with no external dependencies

const NPC_TYPES = ["Rogue", "Goblin", "OrcWarrior", "DarkMage", "EliteGuard", "RogueBandit"]


static func build_enemy_squad(npc_type: String, npc_id: int) -> Array:
	## Build enemy squad: 1 boss + 0-2 adds (same type)
	var enemy_squad = []

	# Load the attacked NPC as the boss (index 0)
	# Note: We pass [-1, -1] to indicate "Use JSON Range"
	var boss_data = load_and_setup_npc(npc_type, npc_type + " A", [-1, -1])
	
	if boss_data.is_empty():
		return [] # Failed to load boss
		
	enemy_squad.append(boss_data)
	var boss_level = boss_data.get("level", 1)
	
	print("[COMBAT] Boss: %s (Lv%d)" % [boss_data.get("character_name"), boss_level])

	# Determine adds (0-2)
	var roll = randf()
	var adds_count = 0
	
	if roll < 0.5: 
		adds_count = 0 # 50% chance for solo
	elif roll < 0.8:
		adds_count = 1 # 30% chance for +1
	else:
		adds_count = 2 # 20% chance for +2
		
	# Spawn adds
	for i in range(adds_count):
		var add_name = npc_type + " " + String.chr(66 + i) # B, C
		var min_lvl = max(1, boss_level - 1)
		var max_lvl = min(50, boss_level + 1)
		
		var add_data = load_and_setup_npc(npc_type, add_name, [min_lvl, max_lvl])
		if not add_data.is_empty():
			enemy_squad.append(add_data)

	return enemy_squad


static func load_and_setup_npc(npc_type: String, display_name: String, level_range_override: Array) -> Dictionary:
	## Load single NPC and setup its stats
	## Returns enemy data dictionary with all stats initialized
	var file_path = "res://characters/npcs/" + npc_type + ".json"
	var npc_data = _load_npc_character_file(file_path)

	if npc_data.is_empty():
		return {}

	# Setup display name
	npc_data["character_name"] = display_name
	npc_data["name"] = display_name
	
	# Determine Level
	var min_lvl = 1
	var max_lvl = 1
	
	# Use override if valid
	if level_range_override.size() == 2 and level_range_override[0] > 0:
		min_lvl = level_range_override[0]
		max_lvl = level_range_override[1]
	# Use JSON range if available
	elif npc_data.has("level_range"):
		min_lvl = int(npc_data.level_range.get("min", 1))
		max_lvl = int(npc_data.level_range.get("max", 1))
		
	npc_data["level"] = randi_range(min_lvl, max_lvl)
	
	# SCALE STATS (Critical for balance)
	_scale_npc_stats(npc_data, npc_data["level"])

	# Initialize Derived Stats (HP/MP)
	if npc_data.has("derived_stats"):
		npc_data["max_hp"] = npc_data.derived_stats.get("max_hp", 100)
		npc_data["hp"] = npc_data["max_hp"]
		npc_data["max_mp"] = npc_data.derived_stats.get("max_mp", 50)
		npc_data["mp"] = npc_data["max_mp"]
		npc_data["max_energy"] = npc_data.derived_stats.get("max_ep", 100)
		npc_data["energy"] = npc_data["max_energy"]
		npc_data["attack"] = npc_data.derived_stats.get("phys_dmg", 10)
		npc_data["defense"] = npc_data.derived_stats.get("phys_def", 10)
	else:
		# Fallback
		npc_data["max_hp"] = 100
		npc_data["hp"] = 100
		npc_data["max_mp"] = 50
		npc_data["mp"] = 50
		npc_data["max_energy"] = 100
		npc_data["energy"] = 100
		npc_data["attack"] = 10
		npc_data["defense"] = 10

	return npc_data

static func _scale_npc_stats(npc_data: Dictionary, level: int) -> void:
	# Duplicate of NPCManager logic to ensure squads are scaled too
	if level <= 1: return
	var stat_growth = 0.05
	var hp_growth = 0.10
	var multiplier_stats = 1.0 + ((level-1) * stat_growth)
	var multiplier_hp = 1.0 + ((level-1) * hp_growth)
	
	if npc_data.has("derived_stats"):
		for key in npc_data.derived_stats:
			if key == "max_hp":
				npc_data.derived_stats[key] = int(npc_data.derived_stats[key] * multiplier_hp)
			else:
				npc_data.derived_stats[key] = int(npc_data.derived_stats[key] * multiplier_stats)
				
	if npc_data.has("base_stats"):
		for key in npc_data.base_stats:
			npc_data.base_stats[key] = int(npc_data.base_stats[key] * multiplier_stats)


static func _load_npc_character_file(file_path: String) -> Dictionary:
	## Load NPC character data from JSON file
	if not FileAccess.file_exists(file_path):
		print("[COMBAT] ERROR: NPC file not found: %s" % file_path)
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[COMBAT] ERROR: Could not open NPC file: %s" % file_path)
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		print("[COMBAT] ERROR: Failed to parse NPC JSON: %s" % file_path)
		return {}

	return json.data
