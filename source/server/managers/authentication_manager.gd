## Golden Sun MMO - Authentication Manager
## Handles player authentication, login, logout, and account management
## Separated from ServerWorld for modularity

extends Node
class_name AuthenticationManager

# ========== DEPENDENCIES ========== 
var server_world: Node = null
var network_handler = null
var game_database = null
var debug_console = null

# ========== AUTHENTICATION STATE ========== 
var authenticated_peers: Dictionary = {}      # peer_id -> username
var login_attempts: Dictionary = {}           # peer_id -> {attempts: int, last_attempt: float}
var account_logout_times: Dictionary = {}     # username -> timestamp (for logout cooldown)
var connected_players: Dictionary = {}        # Reference to server_world's connected_players


func _ready():
	print("!!!! AUTHENTICATION MANAGER READY !!!!")


## Called by ServerWorld to set dependencies
func initialize(server_ref, net_handler, database, debug_console_ref = null):
	server_world = server_ref
	network_handler = net_handler
	game_database = database
	debug_console = debug_console_ref
	if server_world:
		# Get reference to connected_players from server_world's player_manager
		connected_players = server_world.player_manager.connected_players if server_world.player_manager else {}


## ========== ACCOUNT CREATION ========== 

func request_create_account(username: String, password: String):
	var peer_id = multiplayer.get_remote_sender_id()
	print("[SERVER RPC] request_create_account called by peer %d" % peer_id)
	print("[SERVER RPC] Username: %s, Password length: %d" % [username, password.length()])
	log_message("[DEBUG] request_create_account called by peer %d, username: %s" % [peer_id, username])
	if debug_console:
		debug_console.add_log("RPC: Create account from peer %d" % peer_id, "cyan")

	# Validate username
	if username.strip_edges().is_empty():
		if network_handler:
			network_handler.send_account_creation_response(peer_id, false, "Username cannot be empty")
		return

	if username.length() < 3:
		if network_handler:
			network_handler.send_account_creation_response(peer_id, false, "Username must be at least 3 characters")
		return

	# Validate password complexity
	var password_valid = validate_password(password)
	if not password_valid.valid:
		if network_handler:
			network_handler.send_account_creation_response(peer_id, false, password_valid.error)
		return

	# Check if account already exists
	var check_result = game_database.get_account(username)
	if check_result.success:
		if network_handler:
			network_handler.send_account_creation_response(peer_id, false, "Username already taken")
		return

	# Create account
	var result = game_database.create_account(username, password)

	if not result.success:
		log_message("[ACCOUNT] Failed to create account for %s: %s" % [username, result.error])
		if network_handler:
			network_handler.send_account_creation_response(peer_id, false, "Server error creating account")
		return

	log_message("[ACCOUNT] Created account: %s" % username)
	if network_handler:
		network_handler.send_account_creation_response(peer_id, true, "Account created successfully")


## ========== LOGIN ========== 

func request_login(username: String, password: String):
	"""Client requests to login"""
	var peer_id = multiplayer.get_remote_sender_id()
	print("!!!!! [CRITICAL_DEBUG] request_login ENTERED for peer %d user %s !!!!!" % [peer_id, username])
	
	# Safety Check 1: Database
	if not game_database:
		print("!!!!! [CRITICAL_DEBUG] game_database is NULL !!!!!")
		if network_handler:
			network_handler.send_login_response(peer_id, false, "Server Internal Error: DB Null", {})
		return

	# Rate limiting - max 5 attempts per minute
	var current_time = Time.get_ticks_msec() / 1000.0
	if not login_attempts.has(peer_id):
		login_attempts[peer_id] = {"attempts": 0, "last_attempt": 0}

	var peer_attempts = login_attempts[peer_id]
	if current_time - peer_attempts.last_attempt < 60:  # Within last minute
		if peer_attempts.attempts >= 5:
			log_message("[SECURITY] Rate limit exceeded for peer %d (username: %s)" % [peer_id, username])
			if network_handler:
				network_handler.send_login_response(peer_id, false, "Too many login attempts. Please wait.", {})
			return
		peer_attempts.attempts += 1
	else:
		# Reset after 1 minute
		peer_attempts.attempts = 1

	peer_attempts.last_attempt = current_time

	# Validate input
	if username.strip_edges().is_empty():
		if network_handler:
			network_handler.send_login_response(peer_id, false, "Username cannot be empty", {})
		return

	# Check if account recently logged out (3 second cooldown)
	if account_logout_times.has(username):
		var logout_time = account_logout_times[username]
		var time_since_logout = current_time - logout_time
		if time_since_logout < 3.0:
			var wait_time = ceil(3.0 - time_since_logout)
			log_message("[LOGIN] Rejected login for %s - logout cooldown active (%d seconds remaining)" % [username, wait_time])
			if network_handler:
				network_handler.send_login_response(peer_id, false, "Please wait %d seconds before logging in again" % wait_time, {})
			return

	# Load account
	print("[DEBUG_LOGIN] Querying database for account: %s" % username)
	var result = game_database.get_account(username)
	print("[DEBUG_LOGIN] Database returned: %s" % str(result.success))

	if not result.success:
		log_message("[LOGIN] Failed login attempt for %s: account not found" % username)
		if network_handler:
			network_handler.send_login_response(peer_id, false, "Account not found", {})
		return

	var account = result.account

	# Validate password using hash
	var password_hash = account.get("password_hash", "")
	print("[DEBUG_LOGIN] Verifying password (hash length: %d)" % password_hash.length())
	
	if password_hash.is_empty():
		# Legacy account with no hash - SECURITY RISK
		# We reject this login to enforce security migration (or manual reset)
		log_message("[LOGIN] Failed login attempt for %s: legacy unhashed account" % username)
		if network_handler:
			network_handler.send_login_response(peer_id, false, "Account security update required. Please contact support.", {})
		return
	else:
		# Standard secure login
		if not game_database.verify_password(password, password_hash):
			log_message("[LOGIN] Failed login attempt for %s: incorrect password" % username)
			if network_handler:
				network_handler.send_login_response(peer_id, false, "Incorrect password", {})
			return

	# Success!
	log_message("[LOGIN] Successful login: %s" % username)
	log_activity("[color=cyan]LOGGED IN: %s[/color]" % username)

	# Mark peer as authenticated
	authenticated_peers[peer_id] = username
	log_message("[AUTH] Peer %d authenticated as '%s'" % [peer_id, username])

	# Load and validate character list
	print("\n[AUTH] ========== LOADING CHARACTERS FOR LOGIN ==========")
	print("[AUTH] Username: %s" % username)
	print("[AUTH] Calling GameDatabase.get_account_characters()...")

	var char_result = game_database.get_account_characters(username)

	print("[AUTH] get_account_characters() returned")
	print("[AUTH] Result success: %s" % char_result.success)
	print("[AUTH] Result has 'characters' key: %s" % char_result.has("characters"))

	var characters = char_result.characters if char_result.success else []
	print("[AUTH] Characters array extracted - size: %d" % characters.size())
	print("[AUTH] Characters is null: %s" % (characters == null))
	print("[AUTH] Characters is empty: %s" % (characters.is_empty() if characters else "N/A"))

	if characters.size() > 0:
		print("[AUTH] Characters loaded successfully:")
		for i in range(characters.size()):
			var char = characters[i]
			print("[AUTH]   Character %d: %s (ID: %s, Level: %s)" % [i, char.get("name"), char.get("character_id"), char.get("level", "MISSING")])

	# VALIDATION: Verify all characters are valid before sending to client
	print("\n[AUTH] --- CALLING VALIDATION ---")
	print("[AUTH] player_manager exists: %s" % (server_world.player_manager != null))
	var validation = server_world.player_manager.validate_account_characters(username, characters) if server_world.player_manager else {"valid": false, "reason": "PlayerManager not initialized", "valid_characters": []}

	print("\n[AUTH] --- VALIDATION COMPLETE ---")
	print("[AUTH] Validation result - valid: %s" % validation.valid)
	print("[AUTH] Validation reason: %s" % validation.reason)
	print("[AUTH] Valid characters count: %d" % validation.valid_characters.size())

	if not validation.valid:
		log_message("[AUTH] Account validation failed for %s: %s" % [username, validation.reason])
		# Still allow login but with cleaned character list
		print("[AUTH] Using cleaned character list from validation")
		characters = validation.valid_characters
		print("[AUTH] After validation - characters count: %d" % characters.size())
	else:
		print("[AUTH] VALIDATION PASSED for %s: All %d characters valid" % [username, characters.size()])
		# Use the validated characters which may have level fixes applied
		characters = validation.valid_characters
		print("[AUTH] Using validated characters (may include fixes)")

	print("\n[AUTH] --- SENDING LOGIN RESPONSE ---")
	print("[AUTH] Final characters array size: %d" % characters.size())
	print("[AUTH] Final characters is null: %s" % (characters == null))
	print("[AUTH] Final characters is empty: %s" % (characters.is_empty() if characters else "N/A"))
	if characters and characters.size() > 0:
		print("[AUTH] Final character list:")
		for i in range(characters.size()):
			print("[AUTH]   %d. %s (ID: %s)" % [i, characters[i].get("name"), characters[i].get("character_id")])

	if network_handler:
		print("[AUTH] Calling network_handler.send_login_response()...")
		print("[AUTH] Data being sent: username=%s, characters=%d" % [username, characters.size()])
		network_handler.send_login_response(peer_id, true, "Login successful", {"username": username, "characters": characters})
		print("[AUTH] send_login_response() call completed")
	else:
		print("[AUTH] ERROR: network_handler is null!")

	print("[AUTH] ========== LOGIN CHARACTER LOADING COMPLETE ==========\n")


## ========== LOGOUT ========== 

func request_logout():
	"""Client requests to logout - clean up their session"""
	var peer_id = multiplayer.get_remote_sender_id()
	var username = authenticated_peers.get(peer_id, "Unknown")

	log_message("[LOGOUT] User %s (peer %d) requesting logout" % [username, peer_id])
	log_activity("[color=orange]LOGGED OUT: %s[/color]" % username)

	# Store logout timestamp for this account (for reconnection cooldown)
	if username != "Unknown":
		var current_time = Time.get_ticks_msec() / 1000.0
		account_logout_times[username] = current_time
		log_message("[LOGOUT] Set logout cooldown for account: %s" % username)

	# Remove from authenticated peers
	authenticated_peers.erase(peer_id)

	# If they have a spawned character, despawn it
	if connected_players.has(peer_id):
		var player_data = connected_players[peer_id]
		var char_name = player_data.get("character_name", "Unknown")
		log_message("[LOGOUT] Despawning character '%s' for peer %d" % [char_name, peer_id])

		# Notify other players this player is leaving
		for other_peer_id in connected_players:
			if other_peer_id != peer_id:
				network_handler.call_client_rpc(other_peer_id, "handle_player_despawned", [peer_id])

		# Remove from connected players
		connected_players.erase(peer_id)

	# Clear any login attempt tracking for this peer
	if login_attempts.has(peer_id):
		login_attempts.erase(peer_id)

	log_message("[LOGOUT] Session cleaned for peer %d" % peer_id)


## ========== HELPER METHODS ========== 

## Check if peer is authenticated
func is_authenticated(peer_id: int) -> bool:
	return authenticated_peers.has(peer_id)


## Get authenticated username for peer
func get_username(peer_id: int) -> String:
	return authenticated_peers.get(peer_id, "")


## Mark peer as authenticated
func authenticate_peer(peer_id: int, username: String):
	authenticated_peers[peer_id] = username


## Remove authentication for peer
func deauthenticate_peer(peer_id: int):
	authenticated_peers.erase(peer_id)


## Log message (delegates to server_world)
func log_message(msg: String):
	if server_world and server_world.has_method("log_message"):
		server_world.log_message(msg)
	else:
		print(msg)


## Log activity (delegates to server_world)
func log_activity(msg: String):
	if server_world and server_world.has_method("log_activity"):
		server_world.log_activity(msg)
	else:
		print(msg)


func validate_password(password: String) -> Dictionary:
	"""
	Validate password complexity.
	Returns { "valid": bool, "error": String }
	"""
	if password.length() < 8:
		return {"valid": false, "error": "Password must be at least 8 characters long"}
		
	# Check for uppercase
	var has_upper = false
	for i in range(password.length()):
		if password[i] >= "A" and password[i] <= "Z":
			has_upper = true
			break
	if not has_upper:
		return {"valid": false, "error": "Password must contain at least one uppercase letter"}
		
	# Check for number
	var has_number = false
	for i in range(password.length()):
		if password[i] >= "0" and password[i] <= "9":
			has_number = true
			break
	if not has_number:
		return {"valid": false, "error": "Password must contain at least one number"}
		
	# Check for special character (not alphanumeric)
	var has_special = false
	var special_chars = "!@#$%^&*()_+-=[]{}|;:,.<>?/"
	for i in range(password.length()):
		if special_chars.find(password[i]) != -1:
			has_special = true
			break
	if not has_special:
		return {"valid": false, "error": "Password must contain at least one special character (!@#$ etc.)"}
		
	return {"valid": true, "error": ""}
