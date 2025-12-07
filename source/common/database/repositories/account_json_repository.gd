class_name AccountJsonRepository
extends RefCounted

const ACCOUNTS_DIR = "res://data/accounts/"

func get_account(username: String) -> Dictionary:
	"""Load account data from JSON"""
	var account_file = ProjectSettings.globalize_path(ACCOUNTS_DIR + username.to_lower() + ".json")
	
	if not FileAccess.file_exists(account_file):
		return {"success": false, "error": "Account not found"}
		
	var file = FileAccess.open(account_file, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_text) == OK:
			return {"success": true, "account": json.data}
		
	return {"success": false, "error": "Failed to load account file"}

func save_account(username: String, account_data: Dictionary) -> bool:
	"""Save account data to JSON"""
	var account_file = ProjectSettings.globalize_path(ACCOUNTS_DIR + username.to_lower() + ".json")
	
	# Ensure directory exists
	var dir = account_file.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	
	var file = FileAccess.open(account_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(account_data, "\t"))
		file.close()
		return true
	return false

func create_account(username: String, password_hash: String) -> Dictionary:
	"""Create a new account"""
	var account_file = ProjectSettings.globalize_path(ACCOUNTS_DIR + username.to_lower() + ".json")

	if FileAccess.file_exists(account_file):
		return {"success": false, "error": "Account already exists"}

	# Ensure directory exists
	var dir = account_file.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var account_data = {
		"username": username,
		"password_hash": password_hash,
		"created_at": Time.get_datetime_string_from_system(),
		"last_login": "",
		"admin_level": 0,
		"characters": []
	}

	var file = FileAccess.open(account_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(account_data, "\t"))
		file.close()
		print("[AccountRepo] Created account: ", username)
		return {"success": true, "account": account_data}

	return {"success": false, "error": "Failed to write account file"}

func get_account_characters(username: String) -> Dictionary:
	"""Get all characters for an account"""
	var result = get_account(username)
	if not result.success:
		return {"success": false, "error": "Account not found"}

	var account = result.account
	var characters = []
	var char_repo = RepositoryFactory.get_character_repository()

	for char_id in account.characters:
		var char_result = char_repo.get_character(char_id)
		if char_result.success:
			characters.append(char_result.character)

	return {"success": true, "characters": characters}
