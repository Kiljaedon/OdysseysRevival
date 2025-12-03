class_name CharacterJsonRepository
extends RefCounted

const CHARACTERS_DIR = "res://data/characters/"

func get_character(character_id: String) -> Dictionary:
	"""Load character data from JSON"""
	var char_file = ProjectSettings.globalize_path(CHARACTERS_DIR + character_id + ".json")
	
	if not FileAccess.file_exists(char_file):
		return {"success": false, "error": "Character not found"}
		
	var file = FileAccess.open(char_file, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_text) == OK:
			return {"success": true, "character": json.data}
		
	return {"success": false, "error": "Failed to load character file"}

func save_character(character_id: String, character_data: Dictionary) -> bool:
	"""Save character data to JSON"""
	var char_file = ProjectSettings.globalize_path(CHARACTERS_DIR + character_id + ".json")
	
	# Ensure directory exists
	var dir = char_file.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	
	var file = FileAccess.open(char_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(character_data, "\t"))
		file.close()
		return true
	return false

func delete_character(character_id: String) -> bool:
	"""Delete a character file"""
	var char_file = ProjectSettings.globalize_path(CHARACTERS_DIR + character_id + ".json")
	if FileAccess.file_exists(char_file):
		return DirAccess.remove_absolute(char_file) == OK
	return false
