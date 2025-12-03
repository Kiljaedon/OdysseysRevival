class_name CharacterService
extends Node

const GameDatabase = preload("res://source/common/database/game_database.gd") # For static helpers (load_class_data) if needed, or move them here.

func create_character(username: String, character_data: Dictionary) -> Dictionary:
	"""Create a new character with validation and stat generation"""
	var account_repo = RepositoryFactory.get_account_repository()
	var char_repo = RepositoryFactory.get_character_repository()
	
	# check account
	var account_result = account_repo.get_account(username)
	if not account_result.success:
		return {"success": false, "error": "Account not found"}
		
	var account = account_result.account
	if account.characters.size() >= 6:
		return {"success": false, "error": "Maximum 6 characters per account"}
		
	# Generate ID
	var char_id = username.to_lower() + "_char" + str(account.characters.size()) + "_" + str(Time.get_ticks_msec())
	character_data["character_id"] = char_id
	character_data["account"] = username
	character_data["created_at"] = Time.get_datetime_string_from_system()
	
	# Load class data (using legacy helper for now, or move logic here)
	# Ideally we use a ContentRepository, but GameDatabase has the static helper.
	# Let's reuse the logic from GameDatabase._create_character_json but implemented here.
	
	var character_class = character_data.get("class_name", "Adventurer")
	var class_file = "res://characters/classes/" + character_class + ".json"
	
	if FileAccess.file_exists(class_file):
		var file = FileAccess.open(class_file, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var class_data = json.data
				if class_data.has("animations"):
					character_data["animations"] = class_data.animations
	
	# Save character
	if char_repo.save_character(char_id, character_data):
		# Update account
		account.characters.append(char_id)
		account_repo.save_account(username, account)
		return {"success": true, "character_id": char_id, "character": character_data}
		
	return {"success": false, "error": "Failed to save character"}

func delete_character(username: String, character_id: String) -> Dictionary:
	var account_repo = RepositoryFactory.get_account_repository()
	var char_repo = RepositoryFactory.get_character_repository()
	
	var account_result = account_repo.get_account(username)
	if not account_result.success:
		return {"success": false, "error": "Account not found"}
		
	var account = account_result.account
	if not character_id in account.characters:
		return {"success": false, "error": "Character not found in account"}
		
	# Remove from account
	account.characters.erase(character_id)
	account_repo.save_account(username, account)
	
	# Delete file
	if char_repo.delete_character(character_id):
		return {"success": true}
		
	return {"success": false, "error": "Failed to delete character file"}

func get_character(character_id: String) -> Dictionary:
	return RepositoryFactory.get_character_repository().get_character(character_id)

func save_character(character_id: String, data: Dictionary) -> bool:
	return RepositoryFactory.get_character_repository().save_character(character_id, data)
