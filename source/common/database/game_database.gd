class_name GameDatabase
extends Node
## Hybrid database system supporting both JSON and SQLite backends
## Stores accounts, characters, and game data with automatic fallback

# CONFIGURATION
const USE_SQLITE = true  # Set to true to enable SQLite backend (Phase 9)

const ACCOUNTS_DIR = "res://data/accounts/"
const CHARACTERS_DIR = "res://data/characters/"
const SQLITE_DB_PATH = "res://data/game_data.db"

# In-memory caches to reduce file I/O and improve performance
static var account_cache: Dictionary = {}     # {username: {data, timestamp}}
static var character_cache: Dictionary = {}   # {character_id: {data, timestamp}}
const CACHE_TTL_SECONDS: float = 300.0        # 5 minute cache TTL

# SQLite connection state
static var sqlite_available: bool = false
static var sqlite_initialized: bool = false
static var db_path_absolute: String = ""

# INITIALIZATION

static func clear_caches():
	"""Clear all caches (call on server shutdown or for testing)"""
	account_cache.clear()
	character_cache.clear()
	print("[Database] Caches cleared")

static func init_database():
	"""Initialize database (routes to JSON or SQLite based on USE_SQLITE flag)"""
	if USE_SQLITE:
		print("[Database] Initializing SQLite backend...")
		var result = _init_database_sqlite()
		if result:
			print("[Database] SQLite backend active")
			return
		else:
			print("[Database] WARNING: SQLite init failed, falling back to JSON")
			_init_database_json()
	else:
		print("[Database] Using JSON backend (USE_SQLITE=false)")
		_init_database_json()

static func _init_database_json():
	"""Initialize JSON file-based storage"""
	var accounts_path = ProjectSettings.globalize_path(ACCOUNTS_DIR)
	var characters_path = ProjectSettings.globalize_path(CHARACTERS_DIR)

	if not DirAccess.dir_exists_absolute(accounts_path):
		DirAccess.make_dir_recursive_absolute(accounts_path)
	if not DirAccess.dir_exists_absolute(characters_path):
		DirAccess.make_dir_recursive_absolute(characters_path)
	print("[Database] JSON backend initialized at: ", accounts_path)

static func _init_database_sqlite() -> bool:
	"""Initialize SQLite database connection"""
	# Get absolute path to database
	db_path_absolute = ProjectSettings.globalize_path(SQLITE_DB_PATH)

	# Check if sqlite3 CLI is available
	var test_output = []
	var test_result = OS.execute("sqlite3", ["--version"], test_output, true, false)

	if test_result != 0:
		print("[Database] ERROR: sqlite3 not found on system")
		return false

	print("[Database] SQLite version: ", test_output[0] if test_output.size() > 0 else "unknown")

	# Check if database file exists
	if not FileAccess.file_exists(db_path_absolute):
		print("[Database] ERROR: Database file not found: ", db_path_absolute)
		print("[Database] Please run init_database.sql first")
		return false

	# Test database connection
	var output = []
	var result = OS.execute("sqlite3", [db_path_absolute, "SELECT version FROM schema_version LIMIT 1;"], output, true, false)

	if result == 0:
		var schema_version = output[0].strip_edges() if output.size() > 0 else "unknown"
		print("[Database] SQLite connected successfully (schema v", schema_version, ")")
		print("[Database] Database path: ", db_path_absolute)
		sqlite_available = true
		sqlite_initialized = true
		return true
	else:
		print("[Database] ERROR: Failed to connect to SQLite database")
		return false

# ACCOUNT MANAGEMENT (PUBLIC API)

static func create_account(username: String, password: String = "") -> Dictionary:
	"""Create a new account (routes to JSON or SQLite)"""
	if USE_SQLITE and sqlite_available:
		var result = _create_account_sqlite(username, password)
		if result.has("success") and result.success:
			return result
		else:
			print("[Database] SQLite create_account failed, falling back to JSON")
			return _create_account_json(username, password)
	else:
		return _create_account_json(username, password)

static func get_account(username: String) -> Dictionary:
	"""Load account data (routes to JSON or SQLite)"""
	if USE_SQLITE and sqlite_available:
		var result = _get_account_sqlite(username)
		if result.has("success") and result.success:
			return result
		else:
			print("[Database] SQLite get_account failed, falling back to JSON")
			return _get_account_json(username)
	else:
		return _get_account_json(username)

static func save_account(username: String, account_data: Dictionary) -> bool:
	"""Save account data (routes to JSON or SQLite)"""
	if USE_SQLITE and sqlite_available:
		var result = _save_account_sqlite(username, account_data)
		if result:
			return true
		else:
			print("[Database] SQLite save_account failed, falling back to JSON")
			return _save_account_json(username, account_data)
	else:
		return _save_account_json(username, account_data)

# CHARACTER MANAGEMENT (PUBLIC API)

static func create_character(username: String, character_data: Dictionary) -> Dictionary:
	"""Create a new character (routes to JSON or SQLite)"""
	if USE_SQLITE and sqlite_available:
		var result = _create_character_sqlite(username, character_data)
		if result.has("success") and result.success:
			return result
		else:
			print("[Database] SQLite create_character failed, falling back to JSON")
			return _create_character_json(username, character_data)
	else:
		return _create_character_json(username, character_data)

static func get_character(character_id: String) -> Dictionary:
	"""Load character data (routes to JSON or SQLite)"""
	if USE_SQLITE and sqlite_available:
		var result = _get_character_sqlite(character_id)
		if result.has("success") and result.success:
			return result
		else:
			print("[Database] SQLite get_character failed, falling back to JSON")
			return _get_character_json(character_id)
	else:
		return _get_character_json(character_id)

static func save_character(character_id: String, character_data: Dictionary) -> bool:
	"""Save character data (routes to JSON or SQLite)"""
	if USE_SQLITE and sqlite_available:
		var result = _save_character_sqlite(character_id, character_data)
		if result:
			return true
		else:
			print("[Database] SQLite save_character failed, falling back to JSON")
			return _save_character_json(character_id, character_data)
	else:
		return _save_character_json(character_id, character_data)

static func delete_character(username: String, character_id: String) -> Dictionary:
	"""Delete a character (routes to JSON or SQLite)"""
	if USE_SQLITE and sqlite_available:
		var result = _delete_character_sqlite(username, character_id)
		if result.has("success") and result.success:
			return result
		else:
			print("[Database] SQLite delete_character failed, falling back to JSON")
			return _delete_character_json(username, character_id)
	else:
		return _delete_character_json(username, character_id)

static func get_account_characters(username: String) -> Dictionary:
	"""Get all characters for an account (routes to JSON or SQLite)"""
	if USE_SQLITE and sqlite_available:
		var result = _get_account_characters_sqlite(username)
		if result.has("success") and result.success:
			return result
		else:
			print("[Database] SQLite get_account_characters failed, falling back to JSON")
			return _get_account_characters_json(username)
	else:
		return _get_account_characters_json(username)

# JSON BACKEND IMPLEMENTATION

static func _create_account_json(username: String, password: String = "") -> Dictionary:
	"""Create a new account using JSON storage"""
	var account_file = ProjectSettings.globalize_path(ACCOUNTS_DIR + username.to_lower() + ".json")

	if FileAccess.file_exists(account_file):
		return {"success": false, "error": "Account already exists"}

	var password_hash = hash_password(password)

	var account_data = {
		"username": username,
		"password_hash": password_hash,
		"created_at": Time.get_datetime_string_from_system(),
		"characters": []
	}

	var file = FileAccess.open(account_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(account_data, "\t"))
		file.close()
		print("[Database] Created account: ", username)
		return {"success": true, "account": account_data}

	return {"success": false, "error": "Failed to create account file"}

static func _get_account_json(username: String) -> Dictionary:
	"""Load account data from JSON (with caching)"""
	var cache_key = username.to_lower()
	var now = Time.get_ticks_msec() / 1000.0

	if account_cache.has(cache_key):
		var cached = account_cache[cache_key]
		if now - cached.timestamp < CACHE_TTL_SECONDS:
			return {"success": true, "account": cached.data.duplicate()}

	var account_file = ProjectSettings.globalize_path(ACCOUNTS_DIR + cache_key + ".json")

	if not FileAccess.file_exists(account_file):
		return {"success": false, "error": "Account not found"}

	var file = FileAccess.open(account_file, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_text) == OK:
			account_cache[cache_key] = {
				"data": json.data,
				"timestamp": now
			}
			return {"success": true, "account": json.data}

	return {"success": false, "error": "Failed to load account"}

static func _save_account_json(username: String, account_data: Dictionary) -> bool:
	"""Save account data to JSON"""
	var account_file = ProjectSettings.globalize_path(ACCOUNTS_DIR + username.to_lower() + ".json")

	var file = FileAccess.open(account_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(account_data, "\t"))
		file.close()
		return true
	return false

static func _create_character_json(username: String, character_data: Dictionary) -> Dictionary:
	"""Create a new character using JSON storage"""
	var account_result = get_account(username)
	if not account_result.success:
		return {"success": false, "error": "Account not found"}

	var account = account_result.account

	if account.characters.size() >= 6:
		return {"success": false, "error": "Maximum 6 characters per account"}

	var char_id = generate_character_id(username, account.characters.size())
	character_data["character_id"] = char_id
	character_data["account"] = username
	character_data["created_at"] = Time.get_datetime_string_from_system()

	var character_class = character_data.get("class_name", "Adventurer")
	print("[Database] Creating character with class_name: ", character_class)
	var class_file = ProjectSettings.globalize_path("res://characters/classes/" + character_class + ".json")
	print("[Database] Looking for class file: ", class_file)

	if FileAccess.file_exists(class_file):
		var file = FileAccess.open(class_file, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			if json.parse(json_text) == OK:
				var class_data = json.data
				if class_data.has("animations"):
					character_data["animations"] = class_data.animations
					var first_row = class_data.animations.get("walk_down_1", [{}])[0].get("row", "?")
					print("[Database] Embedded animations for class: ", character_class, " (row ", first_row, ")")

	var char_file = ProjectSettings.globalize_path(CHARACTERS_DIR + char_id + ".json")
	var file = FileAccess.open(char_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(character_data, "\t"))
		file.close()

		account.characters.append(char_id)
		save_account(username, account)

		print("[Database] Created character: ", character_data.get("name", "Unknown"), " (", char_id, ")")
		return {"success": true, "character_id": char_id, "character": character_data}

	return {"success": false, "error": "Failed to create character file"}

static func _get_character_json(character_id: String) -> Dictionary:
	"""Load character data from JSON (with caching)"""
	var now = Time.get_ticks_msec() / 1000.0

	if character_cache.has(character_id):
		var cached = character_cache[character_id]
		if now - cached.timestamp < CACHE_TTL_SECONDS:
			return {"success": true, "character": cached.data.duplicate()}

	var char_file = ProjectSettings.globalize_path(CHARACTERS_DIR + character_id + ".json")

	if not FileAccess.file_exists(char_file):
		return {"success": false, "error": "Character not found"}

	var file = FileAccess.open(char_file, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_text) == OK:
			character_cache[character_id] = {
				"data": json.data,
				"timestamp": now
			}
			return {"success": true, "character": json.data}

	return {"success": false, "error": "Failed to load character"}

static func _save_character_json(character_id: String, character_data: Dictionary) -> bool:
	"""Save character data to JSON"""
	var char_file = ProjectSettings.globalize_path(CHARACTERS_DIR + character_id + ".json")

	var file = FileAccess.open(char_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(character_data, "\t"))
		file.close()

		if character_cache.has(character_id):
			character_cache.erase(character_id)

		return true
	return false

static func _delete_character_json(username: String, character_id: String) -> Dictionary:
	"""Delete a character using JSON storage"""
	var account_result = get_account(username)
	if not account_result.success:
		return {"success": false, "error": "Account not found"}

	var account = account_result.account

	var idx = account.characters.find(character_id)
	if idx == -1:
		return {"success": false, "error": "Character not found in account"}

	account.characters.remove_at(idx)
	save_account(username, account)

	var char_file = ProjectSettings.globalize_path(CHARACTERS_DIR + character_id + ".json")
	if FileAccess.file_exists(char_file):
		DirAccess.remove_absolute(char_file)
		print("[Database] Deleted character: ", character_id)
		return {"success": true}

	return {"success": false, "error": "Character file not found"}

static func _get_account_characters_json(username: String) -> Dictionary:
	"""Get all characters for an account using JSON storage"""
	print("\n[DB] ========== GET_ACCOUNT_CHARACTERS START ==========")
	print("[DB] get_account_characters called for username: %s" % username)

	var account_result = get_account(username)
	if not account_result.success:
		print("[DB] ERROR: Account not found: %s" % username)
		print("[DB] ========== GET_ACCOUNT_CHARACTERS END (FAILED) ==========\n")
		return {"success": false, "error": "Account not found"}

	var account = account_result.account
	print("[DB] Account loaded successfully")
	print("[DB] Account username: %s" % account.get("username", "MISSING"))
	print("[DB] Character IDs in account: %s" % str(account.characters))
	print("[DB] Character count: %d" % account.characters.size())

	var characters = []

	for char_id in account.characters:
		print("\n[DB] --- Loading character: %s ---" % char_id)
		var char_file_path = ProjectSettings.globalize_path(CHARACTERS_DIR + char_id + ".json")
		print("[DB] Character file path: %s" % char_file_path)
		print("[DB] File exists: %s" % FileAccess.file_exists(char_file_path))

		var char_result = get_character(char_id)
		if char_result.success:
			var char_data = char_result.character
			print("[DB] SUCCESS: Character loaded from file")
			print("[DB] Character name: %s" % char_data.get("name", "MISSING"))
			print("[DB] Character class: %s" % char_data.get("class_name", "MISSING"))
			print("[DB] Character level: %s" % char_data.get("level", "MISSING"))
			print("[DB] Character ID: %s" % char_data.get("character_id", "MISSING"))
			print("[DB] Character account: %s" % char_data.get("account", "MISSING"))
			print("[DB] Character has stats: %s" % char_data.has("stats"))
			print("[DB] Character data keys: %s" % str(char_data.keys()))
			characters.append(char_data)
			print("[DB] Character added to array (array size now: %d)" % characters.size())
		else:
			print("[DB] ERROR: Failed to load character: %s - %s" % [char_id, char_result.error])

	print("\n[DB] ========== GET_ACCOUNT_CHARACTERS SUMMARY ==========")
	print("[DB] Total characters loaded: %d" % characters.size())
	print("[DB] Returning success: true")
	for i in range(characters.size()):
		print("[DB] Character %d: %s (ID: %s)" % [i, characters[i].get("name"), characters[i].get("character_id")])
	print("[DB] ========== GET_ACCOUNT_CHARACTERS END ==========\n")

	return {"success": true, "characters": characters}

# SQLITE BACKEND IMPLEMENTATION

static func _create_account_sqlite(username: String, password: String = "") -> Dictionary:
	"""Create account in SQLite database"""
	if not sqlite_available:
		return {"success": false, "error": "SQLite not available"}

	var password_hash = hash_password(password)
	var timestamp = Time.get_datetime_string_from_system()

	# Build INSERT query
	var query = "INSERT INTO accounts (username, password_hash, created_at, is_active) VALUES ('%s', '%s', '%s', 1);" % [
		_sql_escape(username),
		_sql_escape(password_hash),
		timestamp
	]

	var output = []
	var result = OS.execute("sqlite3", [db_path_absolute, query], output, true, false)

	if result == 0:
		print("[Database] Created account in SQLite: ", username)
		var account_data = {
			"username": username,
			"password_hash": password_hash,
			"created_at": timestamp,
			"characters": []
		}
		return {"success": true, "account": account_data}
	else:
		var error_msg = output[0] if output.size() > 0 else "Unknown error"
		print("[Database] SQLite create_account failed: ", error_msg)
		return {"success": false, "error": error_msg}

static func _get_account_sqlite(username: String) -> Dictionary:
	"""Get account from SQLite database"""
	if not sqlite_available:
		return {"success": false, "error": "SQLite not available"}

	# Check cache first
	var cache_key = username.to_lower()
	var now = Time.get_ticks_msec() / 1000.0

	if account_cache.has(cache_key):
		var cached = account_cache[cache_key]
		if now - cached.timestamp < CACHE_TTL_SECONDS:
			return {"success": true, "account": cached.data.duplicate()}

	# Query SQLite
	var query = "SELECT username, password_hash, created_at, last_login FROM accounts WHERE username='%s' LIMIT 1;" % _sql_escape(username)

	var output = []
	var result = OS.execute("sqlite3", [db_path_absolute, "-json", query], output, true, false)

	if result == 0 and output.size() > 0:
		var json_str = output[0].strip_edges()
		if json_str.length() > 0:
			var json = JSON.new()
			if json.parse(json_str) == OK:
				var rows = json.data
				if rows is Array and rows.size() > 0:
					var row = rows[0]

					# Get character IDs for this account
					var char_query = "SELECT character_id FROM characters WHERE account='%s' AND is_deleted=0;" % _sql_escape(username)
					var char_output = []
					var char_result = OS.execute("sqlite3", [db_path_absolute, "-json", char_query], char_output, true, false)

					var character_ids = []
					if char_result == 0 and char_output.size() > 0:
						var char_json = JSON.new()
						if char_json.parse(char_output[0].strip_edges()) == OK:
							var char_rows = char_json.data
							if char_rows is Array:
								for char_row in char_rows:
									character_ids.append(char_row["character_id"])

					var account_data = {
						"username": row.get("username", username),
						"password_hash": row.get("password_hash", ""),
						"created_at": row.get("created_at", ""),
						"last_login": row.get("last_login", null),
						"characters": character_ids
					}

					# Cache the result
					account_cache[cache_key] = {
						"data": account_data,
						"timestamp": now
					}

					return {"success": true, "account": account_data}

	return {"success": false, "error": "Account not found"}

static func _save_account_sqlite(username: String, account_data: Dictionary) -> bool:
	"""Save account to SQLite database"""
	if not sqlite_available:
		return false

	# Update last_login timestamp
	var query = "UPDATE accounts SET last_login='%s' WHERE username='%s';" % [
		Time.get_datetime_string_from_system(),
		_sql_escape(username)
	]

	var output = []
	var result = OS.execute("sqlite3", [db_path_absolute, query], output, true, false)

	# Invalidate cache
	var cache_key = username.to_lower()
	if account_cache.has(cache_key):
		account_cache.erase(cache_key)

	return result == 0

static func _create_character_sqlite(username: String, character_data: Dictionary) -> Dictionary:
	"""Create character in SQLite database"""
	if not sqlite_available:
		return {"success": false, "error": "SQLite not available"}

	# Check account exists
	var account_result = _get_account_sqlite(username)
	if not account_result.success:
		return {"success": false, "error": "Account not found"}

	var account = account_result.account
	if account.characters.size() >= 6:
		return {"success": false, "error": "Maximum 6 characters per account"}

	# Generate character ID
	var char_id = generate_character_id(username, account.characters.size())
	var timestamp = Time.get_datetime_string_from_system()

	# Extract character data with defaults
	var char_name = character_data.get("name", "Unknown")
	var char_class = character_data.get("class_name", "Warrior")
	var element = character_data.get("element", "Fire")
	var level = character_data.get("level", 1.0)
	var xp = character_data.get("xp", 0.0)
	var current_ep = character_data.get("current_ep", 60.0)
	var max_ep = character_data.get("max_ep", 60.0)
	var pos_x = character_data.get("position_x", 400.0)
	var pos_y = character_data.get("position_y", 300.0)
	var sprite_row = character_data.get("sprite_row", 0.0)
	var sprite_col = character_data.get("sprite_col", 0.0)

	# Get stats
	var stats = character_data.get("stats", {})
	var stat_str = stats.get("str", 10.0)
	var stat_dex = stats.get("dex", 10.0)
	var stat_int = stats.get("int", 10.0)
	var stat_wis = stats.get("wis", 10.0)
	var stat_vit = stats.get("vit", 10.0)
	var stat_cha = stats.get("cha", 10.0)

	# Get team NPCs
	var team_npcs = character_data.get("team_npc_ids", [])
	var team_npcs_json = JSON.stringify(team_npcs)

	# Build INSERT query
	var query = """INSERT INTO characters (
		character_id, account, name, class_name, element,
		level, xp, current_ep, max_ep, position_x, position_y,
		sprite_row, sprite_col, stat_str, stat_dex, stat_int,
		stat_wis, stat_vit, stat_cha, team_npc_ids, created_at
	) VALUES (
		'%s', '%s', '%s', '%s', '%s',
		%f, %f, %f, %f, %f, %f,
		%f, %f, %f, %f, %f,
		%f, %f, %f, '%s', '%s'
	);""" % [
		_sql_escape(char_id), _sql_escape(username), _sql_escape(char_name),
		_sql_escape(char_class), _sql_escape(element),
		level, xp, current_ep, max_ep, pos_x, pos_y,
		sprite_row, sprite_col, stat_str, stat_dex, stat_int,
		stat_wis, stat_vit, stat_cha, _sql_escape(team_npcs_json), timestamp
	]

	var output = []
	var result = OS.execute("sqlite3", [db_path_absolute, query], output, true, false)

	if result == 0:
		character_data["character_id"] = char_id
		character_data["account"] = username
		character_data["created_at"] = timestamp
		print("[Database] Created character in SQLite: ", char_name, " (", char_id, ")")
		return {"success": true, "character_id": char_id, "character": character_data}
	else:
		var error_msg = output[0] if output.size() > 0 else "Unknown error"
		print("[Database] SQLite create_character failed: ", error_msg)
		return {"success": false, "error": error_msg}

static func _get_character_sqlite(character_id: String) -> Dictionary:
	"""Get character from SQLite database"""
	if not sqlite_available:
		return {"success": false, "error": "SQLite not available"}

	# Check cache first
	var now = Time.get_ticks_msec() / 1000.0

	if character_cache.has(character_id):
		var cached = character_cache[character_id]
		if now - cached.timestamp < CACHE_TTL_SECONDS:
			return {"success": true, "character": cached.data.duplicate()}

	# Query SQLite
	var query = "SELECT * FROM characters WHERE character_id='%s' AND is_deleted=0 LIMIT 1;" % _sql_escape(character_id)

	var output = []
	var result = OS.execute("sqlite3", [db_path_absolute, "-json", query], output, true, false)

	if result == 0 and output.size() > 0:
		var json_str = output[0].strip_edges()
		if json_str.length() > 0:
			var json = JSON.new()
			if json.parse(json_str) == OK:
				var rows = json.data
				if rows is Array and rows.size() > 0:
					var row = rows[0]

					# Convert SQLite row to character data format
					var character_data = _sqlite_row_to_character(row)

					# Cache the result
					character_cache[character_id] = {
						"data": character_data,
						"timestamp": now
					}

					return {"success": true, "character": character_data}

	return {"success": false, "error": "Character not found"}

static func _save_character_sqlite(character_id: String, character_data: Dictionary) -> bool:
	"""Save character to SQLite database"""
	if not sqlite_available:
		return false

	# Extract updated data
	var level = character_data.get("level", 1.0)
	var xp = character_data.get("xp", 0.0)
	var current_ep = character_data.get("current_ep", 60.0)
	var max_ep = character_data.get("max_ep", 60.0)
	var pos_x = character_data.get("position_x", 400.0)
	var pos_y = character_data.get("position_y", 300.0)

	# Get stats
	var stats = character_data.get("stats", {})
	var stat_str = stats.get("str", 10.0)
	var stat_dex = stats.get("dex", 10.0)
	var stat_int = stats.get("int", 10.0)
	var stat_wis = stats.get("wis", 10.0)
	var stat_vit = stats.get("vit", 10.0)
	var stat_cha = stats.get("cha", 10.0)

	# Get team NPCs
	var team_npcs = character_data.get("team_npc_ids", [])
	var team_npcs_json = JSON.stringify(team_npcs)

	var timestamp = Time.get_datetime_string_from_system()

	# Build UPDATE query
	var query = """UPDATE characters SET
		level=%f, xp=%f, current_ep=%f, max_ep=%f,
		position_x=%f, position_y=%f,
		stat_str=%f, stat_dex=%f, stat_int=%f,
		stat_wis=%f, stat_vit=%f, stat_cha=%f,
		team_npc_ids='%s', last_played='%s'
	WHERE character_id='%s';""" % [
		level, xp, current_ep, max_ep,
		pos_x, pos_y,
		stat_str, stat_dex, stat_int,
		stat_wis, stat_vit, stat_cha,
		_sql_escape(team_npcs_json), timestamp,
		_sql_escape(character_id)
	]

	var output = []
	var result = OS.execute("sqlite3", [db_path_absolute, query], output, true, false)

	# Invalidate cache
	if character_cache.has(character_id):
		character_cache.erase(character_id)

	return result == 0

static func _delete_character_sqlite(username: String, character_id: String) -> Dictionary:
	"""Soft delete character in SQLite database"""
	if not sqlite_available:
		return {"success": false, "error": "SQLite not available"}

	var timestamp = Time.get_datetime_string_from_system()

	# Soft delete by setting is_deleted flag
	var query = "UPDATE characters SET is_deleted=1, deleted_at='%s' WHERE character_id='%s' AND account='%s';" % [
		timestamp,
		_sql_escape(character_id),
		_sql_escape(username)
	]

	var output = []
	var result = OS.execute("sqlite3", [db_path_absolute, query], output, true, false)

	if result == 0:
		# Invalidate cache
		if character_cache.has(character_id):
			character_cache.erase(character_id)
		print("[Database] Soft deleted character: ", character_id)
		return {"success": true}
	else:
		var error_msg = output[0] if output.size() > 0 else "Unknown error"
		return {"success": false, "error": error_msg}

static func _get_account_characters_sqlite(username: String) -> Dictionary:
	"""Get all characters for account from SQLite database"""
	if not sqlite_available:
		return {"success": false, "error": "SQLite not available"}

	print("\n[DB] ========== GET_ACCOUNT_CHARACTERS_SQLITE START ==========")
	print("[DB] Getting characters for account: %s" % username)

	# Query all active characters for this account - SQL-level validation to bypass broken binary validation
	var query = """SELECT * FROM characters
		WHERE account='%s'
		AND is_deleted=0
		AND class_name IS NOT NULL
		AND class_name != ''
		AND stat_str IS NOT NULL
		AND stat_dex IS NOT NULL
		AND stat_int IS NOT NULL
		AND stat_wis IS NOT NULL
		AND stat_vit IS NOT NULL
		AND stat_cha IS NOT NULL
		ORDER BY created_at;""" % _sql_escape(username)

	var output = []
	var result = OS.execute("sqlite3", [db_path_absolute, "-json", query], output, true, false)

	if result == 0 and output.size() > 0:
		var json_str = output[0].strip_edges()
		if json_str.length() > 0:
			var json = JSON.new()
			if json.parse(json_str) == OK:
				var rows = json.data
				if rows is Array:
					var characters = []
					for row in rows:
						var character_data = _sqlite_row_to_character(row)
						characters.append(character_data)
						print("[DB] Loaded character: %s (ID: %s)" % [character_data.get("name"), character_data.get("character_id")])

					print("[DB] Total characters loaded: %d" % characters.size())
					print("[DB] ========== GET_ACCOUNT_CHARACTERS_SQLITE END ==========\n")
					return {"success": true, "characters": characters}

	print("[DB] No characters found or query failed")
	print("[DB] ========== GET_ACCOUNT_CHARACTERS_SQLITE END ==========\n")
	return {"success": true, "characters": []}

# SQLITE HELPER FUNCTIONS

static func _sqlite_row_to_character(row: Dictionary) -> Dictionary:
	"""Convert SQLite row to character data dictionary"""
	# Parse team_npc_ids JSON
	var team_npcs = []
	var team_npcs_str = row.get("team_npc_ids", "[]")
	var json = JSON.new()
	if json.parse(team_npcs_str) == OK:
		team_npcs = json.data

	# Build character data structure
	var character_data = {
		"character_id": row.get("character_id", ""),
		"account": row.get("account", ""),
		"name": row.get("name", "Unknown"),
		"class_name": row.get("class_name", "Warrior"),
		"element": row.get("element", "Fire"),
		"level": row.get("level", 1.0),
		"xp": row.get("xp", 0.0),
		"current_ep": row.get("current_ep", 60.0),
		"max_ep": row.get("max_ep", 60.0),
		"position_x": row.get("position_x", 400.0),
		"position_y": row.get("position_y", 300.0),
		"sprite_row": row.get("sprite_row", 0.0),
		"sprite_col": row.get("sprite_col", 0.0),
		"stats": {
			"str": row.get("stat_str", 10.0),
			"dex": row.get("stat_dex", 10.0),
			"int": row.get("stat_int", 10.0),
			"wis": row.get("stat_wis", 10.0),
			"vit": row.get("stat_vit", 10.0),
			"cha": row.get("stat_cha", 10.0)
		},
		"team_npc_ids": team_npcs,
		"created_at": row.get("created_at", ""),
		"last_played": row.get("last_played", null),
		"data_version": row.get("data_version", "2.0")
	}

	return character_data

static func _sql_escape(value: String) -> String:
	"""Escape single quotes for SQL injection prevention"""
	return value.replace("'", "''")

# SHARED HELPER FUNCTIONS

static func generate_character_id(username: String, index: int) -> String:
	"""Generate unique character ID"""
	return username.to_lower() + "_char" + str(index) + "_" + str(Time.get_ticks_msec())

static func hash_password(password: String, salt: String = "") -> String:
	"""Hash password using SHA256 with salt"""
	if salt.is_empty():
		salt = str(randi() % 999999999)

	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((password + salt).to_utf8_buffer())
	var hash = ctx.finish().hex_encode()

	return salt + ":" + hash

static func verify_password(password: String, password_hash: String) -> bool:
	"""Verify password against stored hash"""
	var parts = password_hash.split(":", false, 1)
	if parts.size() != 2:
		return hash_password_legacy(password) == password_hash

	var salt = parts[0]
	var expected_hash = parts[1]
	var computed = hash_password(password, salt)
	var computed_hash = computed.split(":")[1]

	return computed_hash == expected_hash

static func hash_password_legacy(password: String) -> String:
	"""For backwards compatibility with existing accounts"""
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(password.to_utf8_buffer())
	return ctx.finish().hex_encode()

static func load_class_data(character_class: String) -> Dictionary:
	"""Load class template from res://characters/classes/"""
	var class_file = "res://characters/classes/" + character_class + ".json"

	if not FileAccess.file_exists(class_file):
		return {}

	var file = FileAccess.open(class_file, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_text) == OK:
			return json.data

	return {}

static func load_npc_data(npc_name: String) -> Dictionary:
	"""Load NPC template from res://characters/npcs/"""
	var npc_file = "res://characters/npcs/" + npc_name + ".json"

	if not FileAccess.file_exists(npc_file):
		return {}

	var file = FileAccess.open(npc_file, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_text) == OK:
			return json.data

	return {}
