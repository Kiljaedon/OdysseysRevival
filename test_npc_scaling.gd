extends SceneTree

func _init():
	print("=== TESTING NPC DATA PIPELINE ===")
	
	# 1. Load existing Goblin
	var file = FileAccess.open("res://characters/npcs/Goblin.json", FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	var goblin = json.data
	file.close()
	
	# SIMULATE NPCManager.load_npc_data initialization
	if not goblin.has("hp"):
		if goblin.has("derived_stats"):
			goblin["hp"] = goblin.derived_stats.get("max_hp", 100)
			goblin["max_hp"] = goblin.derived_stats.get("max_hp", 100)
	
	print("Original HP: ", goblin["hp"])
	print("Original STR: ", goblin["base_stats"]["str"])
	
	# 3. Simulate Server Scaling (Level 3)
	# Growth: HP +10%/lvl, Stat +5%/lvl
	# Level 3 = 2 levels of growth over Level 1 -> +20% HP, +10% Stats
	var level = 3
	_scale_npc_stats(goblin, level)
	
	print("Scaled Level: ", level)
	print("New HP: ", goblin["hp"], " (Expected ~90)")
	print("New STR: ", goblin["base_stats"]["str"], " (Expected ~8.8 -> 8 or 9)")
	
	if goblin["hp"] > 75:
		print("SUCCESS: Stats scaled up!")
	else:
		print("FAILURE: Stats did not scale.")
		
	quit()

func _scale_npc_stats(npc_data: Dictionary, level: int) -> void:
	if level <= 1: return
	var stat_growth = 0.05
	var hp_growth = 0.10
	
	# Scale based on level difference from 1
	# Level 3 means 2 levels of growth
	var levels_gained = level - 1
	
	var multiplier_stats = 1.0 + (levels_gained * stat_growth)
	var multiplier_hp = 1.0 + (levels_gained * hp_growth)
	
	if npc_data.has("hp"):
		npc_data["hp"] = int(npc_data["hp"] * multiplier_hp)
	if npc_data.has("max_hp"):
		npc_data["max_hp"] = int(npc_data["max_hp"] * multiplier_hp)
	
	if npc_data.has("base_stats"):
		for stat in npc_data.base_stats:
			npc_data.base_stats[stat] = int(npc_data.base_stats[stat] * multiplier_stats)