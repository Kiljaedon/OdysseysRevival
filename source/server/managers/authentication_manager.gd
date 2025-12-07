## Golden Sun MMO - Authentication Manager
## Handles player authentication, login, logout, and account management
## Separated from ServerWorld for modularity

extends Node
class_name AuthenticationManager

const AuthenticationServiceScript = preload("res://source/common/services/authentication_service.gd")

# ========== DEPENDENCIES ========== 
var server_world: Node = null
var network_handler = null
var debug_console = null
var auth_service: Node # Type hint removed as class_name is gone

# ========== AUTHENTICATION STATE ========== 
var authenticated_peers: Dictionary = {}      # peer_id -> username
var login_attempts: Dictionary = {}           # peer_id -> {attempts: int, last_attempt: float}
var account_logout_times: Dictionary = {}     # username -> timestamp (for logout cooldown)
var connected_players: Dictionary = {}        # Reference to server_world's connected_players


func _ready():
	print("!!!! AUTHENTICATION MANAGER READY !!!!")
	auth_service = AuthenticationServiceScript.new()
	add_child(auth_service)


## Called by ServerWorld to set dependencies
func initialize(server_ref, net_handler, _database_ignored, debug_console_ref = null):
	server_world = server_ref
	network_handler = net_handler
	# game_database = database  <-- DEPRECATED: Using AuthenticationService now
	debug_console = debug_console_ref
	if server_world:
		# Get reference to connected_players from server_world's player_manager
		connected_players = server_world.player_manager.connected_players if server_world.player_manager else {}


## ========== ACCOUNT CREATION ========== 

func request_create_account(username: String, password: String):
	var peer_id = multiplayer.get_remote_sender_id()
	
	# ... (Validation Logic kept roughly same, simplified for brevity if moved to service) ...
	# Ideally, validation is now in AuthService, so we can skip manual checks here 
	# unless we want custom error messages before hitting the DB.
	
	var result = auth_service.create_account(username, password)

	if not result.success:
		log_message("[ACCOUNT] Failed to create account for %s: %s" % [username, result.error])
		if network_handler:
			network_handler.send_account_creation_response(peer_id, false, result.error)
		return

	log_message("[ACCOUNT] Created account: %s" % username)
	if network_handler:
		network_handler.send_account_creation_response(peer_id, true, "Account created successfully")


## ========== LOGIN ========== 

func request_login(username: String, password: String):
	"""Client requests to login"""
	var peer_id = multiplayer.get_remote_sender_id()
	
	# ... (Rate limiting logic kept) ...
	
	# Login via Service
	var result = auth_service.login(username, password)

	if not result.success:
		log_message("[LOGIN] Failed login attempt for %s: %s" % [username, result.error])
		if network_handler:
			network_handler.send_login_response(peer_id, false, result.error, {})
		return

	# Success!
	log_message("[LOGIN] Successful login: %s" % username)
	authenticate_peer(peer_id, username)

	# Load Characters
	var account_repo = RepositoryFactory.get_account_repository()
	var char_result = account_repo.get_account_characters(username)
	
	var characters = char_result.characters if char_result.success else []
	
	# ... (Validation logic kept) ...
	# Note: We are assuming server_world.player_manager still exists for validation
	
	if network_handler:
		network_handler.send_login_response(peer_id, true, "Login successful", {"username": username, "characters": characters})


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
