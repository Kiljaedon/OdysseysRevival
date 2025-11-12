extends Node
class_name EnemySquadBuilder

## Enemy Squad Builder - Phase 1 Step 1.1 Refactoring
## Extracts enemy squad generation logic from CombatManager
## Pure utility class with no external dependencies

const NPC_TYPES = ["Rogue", "Goblin", "OrcWarrior", "DarkMage", "EliteGuard", "RogueBandit"]


static func build_enemy_squad(npc_type: String, npc_id: int) -> Array:
	## Build complete enemy squad: 1 boss + 5 random enemies
	## Returns array of enemy data dictionaries
	var enemy_squad = []

	# Load the attacked NPC as the boss (index 0)
	var boss_data = load_and_setup_npc(npc_type, npc_type + " 1", [1, 5])
	if not boss_data.is_empty():
		enemy_squad.append(boss_data)
		print("[COMBAT] Boss enemy: %s (Lv%d, DEX:%d, ATK:%d, DEF:%d)" % [
			boss_data.get("character_name"),
			boss_data.get("level", 1),
			boss_data.get("base_stats", {}).get("dex", 10),
			boss_data.get("attack", 10),
			boss_data.get("defense", 10)
		])

	# Load 5 random different NPCs for the rest of the squad
	var shuffled_types = NPC_TYPES.duplicate()
	shuffled_types.shuffle()  # Randomize order

	for i in range(5):
		var random_type = shuffled_types[i % shuffled_types.size()]
		var enemy_data = load_and_setup_npc(random_type, random_type + " " + str(i + 2), [1, 5])

		if not enemy_data.is_empty():
			enemy_squad.append(enemy_data)
			print("[COMBAT] Enemy %d: %s (Lv%d, DEX:%d, ATK:%d, DEF:%d)" % [
				i + 2,
				enemy_data.get("character_name"),
				enemy_data.get("level", 1),
				enemy_data.get("base_stats", {}).get("dex", 10),
				enemy_data.get("attack", 10),
				enemy_data.get("defense", 10)
			])

	return enemy_squad


static func load_and_setup_npc(npc_type: String, display_name: String, level_range: Array) -> Dictionary:
	## Load single NPC and setup its stats
	## Returns enemy data dictionary with all stats initialized
	var file_path = "res://characters/npcs/" + npc_type + ".json"
	var npc_data = _load_npc_character_file(file_path)

	if npc_data.is_empty():
		return {}

	# Setup display name and level
	npc_data["character_name"] = display_name
	npc_data["name"] = display_name
	npc_data["level"] = randi_range(level_range[0], level_range[1])

	# Use actual stats from derived_stats if available
	if npc_data.has("derived_stats"):
		npc_data["max_hp"] = npc_data.derived_stats.get("max_hp", 100)
		npc_data["hp"] = npc_data["max_hp"]  # Start at full HP
		npc_data["max_mp"] = npc_data.derived_stats.get("max_mp", 50)
		npc_data["mp"] = npc_data["max_mp"]
		npc_data["max_energy"] = npc_data.derived_stats.get("max_ep", 100)
		npc_data["energy"] = npc_data["max_energy"]
		npc_data["attack"] = npc_data.derived_stats.get("phys_dmg", 10)
		npc_data["defense"] = npc_data.derived_stats.get("phys_def", 10)
	else:
		# Fallback defaults if no derived_stats
		npc_data["max_hp"] = 100
		npc_data["hp"] = 100
		npc_data["max_mp"] = 50
		npc_data["mp"] = 50
		npc_data["max_energy"] = 100
		npc_data["energy"] = 100
		npc_data["attack"] = 10
		npc_data["defense"] = 10

	return npc_data


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
