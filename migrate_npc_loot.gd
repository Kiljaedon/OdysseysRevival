extends SceneTree

func _init():
	print("=== MIGRATING NPC LOOT TABLES ===")
	
	var dir = DirAccess.open("res://characters/npcs/")
	if not dir:
		print("ERROR: Could not open characters/npcs/")
		quit()
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			process_npc(file_name)
		file_name = dir.get_next()
		
	print("=== MIGRATION COMPLETE ===")
	quit()

func process_npc(filename):
	var path = "res://characters/npcs/" + filename
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	var data = json.data
	file.close()
	
	var changed = false
	
	# 1. Add Loot Table
	if not data.has("loot_table"):
		var xp = 50
		var gold = 10
		
		# Give bosses more loot
		if data.get("character_name") == "Rogue":
			xp = 200
			gold = 100
			
		data["loot_table"] = {
			"xp_reward": xp,
			"gold_reward": gold,
			"items": []
		}
		print("Added loot table to ", filename)
		changed = true
	
	# 2. Add Level Range (Default) if missing
	if not data.has("level_range"):
		data["level_range"] = {"min": 1, "max": 1}
		print("Added level range to ", filename)
		changed = true
	
	# 3. Add AI Archetype (Default) if missing
	if not data.has("ai_archetype"):
		data["ai_archetype"] = "AGGRESSIVE"
		print("Added AI archetype to ", filename)
		changed = true
	
	if changed:
		var save_file = FileAccess.open(path, FileAccess.WRITE)
		save_file.store_string(JSON.stringify(data, "\t"))
		save_file.close()
