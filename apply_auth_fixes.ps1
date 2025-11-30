# Apply authentication fixes to server_world.gd and game_database.gd

$serverWorldPath = "C:\Users\dougd\GoldenSunMMO\GoldenSunMMO-Dev\source\server\server_world.gd"
$gameDbPath = "C:\Users\dougd\GoldenSunMMO\GoldenSunMMO-Dev\source\common\database\game_database.gd"

# Read the current file
$content = Get-Content $serverWorldPath -Raw

# Task 1: Add authentication to request_spawn_character
$oldSpawn = @"
@rpc("any_peer")
func request_spawn_character(username: String, character_id: String):
	"""Client wants to spawn their character into the world"""
	var peer_id = multiplayer.get_remote_sender_id()

	# Load character data
	var result = GameDatabase.get_character(character_id)
"@

$newSpawn = @"
@rpc("any_peer")
func request_spawn_character(username: String, character_id: String):
	"""Client wants to spawn their character into the world"""
	var peer_id = multiplayer.get_remote_sender_id()

	# NEW: Verify peer is authenticated
	if not authenticated_peers.has(peer_id):
		log_message("[SPAWN] Rejected: Peer %d not authenticated" % peer_id)
		if network_handler:
			network_handler.send_spawn_rejected(peer_id, "Not authenticated")
		return

	# NEW: Verify authenticated username matches request
	if authenticated_peers[peer_id] != username:
		log_message("[SPAWN] Rejected: Peer %d username mismatch (auth=%s, req=%s)" % [peer_id, authenticated_peers[peer_id], username])
		if network_handler:
			network_handler.send_spawn_rejected(peer_id, "Username mismatch")
		return

	# Load character data
	var result = GameDatabase.get_character(character_id)
"@

$content = $content -replace [regex]::Escape($oldSpawn), $newSpawn

# Task 2: Add authentication to request_create_character
$oldCreate = @"
@rpc("any_peer")
func request_create_character(username: String, character_data: Dictionary):
	"""Client requests to create a new character"""
	var peer_id = multiplayer.get_remote_sender_id()

	# Validate character name
"@

$newCreate = @"
@rpc("any_peer")
func request_create_character(username: String, character_data: Dictionary):
	"""Client requests to create a new character"""
	var peer_id = multiplayer.get_remote_sender_id()

	# NEW: Verify peer is authenticated
	if not authenticated_peers.has(peer_id):
		log_message("[CREATE] Rejected: Peer %d not authenticated" % peer_id)
		return

	# NEW: Verify authenticated username matches request
	if authenticated_peers[peer_id] != username:
		log_message("[CREATE] Rejected: Peer %d username mismatch" % peer_id)
		return

	# Validate character name
"@

$content = $content -replace [regex]::Escape($oldCreate), $newCreate

# Task 4: Add authentication to request_delete_character
$oldDelete = @"
@rpc("any_peer")
func request_delete_character(username: String, character_id: String):
	"""Client requests to delete a character"""
	var peer_id = multiplayer.get_remote_sender_id()

	# Delete character
"@

$newDelete = @"
@rpc("any_peer")
func request_delete_character(username: String, character_id: String):
	"""Client requests to delete a character"""
	var peer_id = multiplayer.get_remote_sender_id()

	# NEW: Verify peer is authenticated
	if not authenticated_peers.has(peer_id):
		log_message("[DELETE] Rejected: Peer %d not authenticated" % peer_id)
		return

	# NEW: Verify authenticated username matches request
	if authenticated_peers[peer_id] != username:
		log_message("[DELETE] Rejected: Peer %d username mismatch" % peer_id)
		return

	# Delete character
"@

$content = $content -replace [regex]::Escape($oldDelete), $newDelete

# Write back the modified content
Set-Content -Path $serverWorldPath -Value $content
Write-Host "Applied authentication fixes to server_world.gd"

# Task 5: Update password hashing in game_database.gd
$dbContent = Get-Content $gameDbPath -Raw

$oldHash = @"
static func hash_password(password: String) -> String:
	"""Hash password using SHA256"""
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(password.to_utf8_buffer())
	return ctx.finish().hex_encode()


static func verify_password(password: String, password_hash: String) -> bool:
	"""Verify password against stored hash"""
	return hash_password(password) == password_hash
"@

$newHash = @"
static func hash_password(password: String, salt: String = "") -> String:
	"""Hash password using SHA256 with salt"""
	# Generate random salt if not provided
	if salt.is_empty():
		salt = str(randi() % 999999999)

	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((password + salt).to_utf8_buffer())
	var hash = ctx.finish().hex_encode()

	# Return format: "salt:hash"
	return salt + ":" + hash


static func verify_password(password: String, password_hash: String) -> bool:
	"""Verify password against stored hash"""
	# Extract salt from stored hash
	var parts = password_hash.split(":", false, 1)
	if parts.size() != 2:
		# Old format without salt - verify directly
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
"@

$dbContent = $dbContent -replace [regex]::Escape($oldHash), $newHash

# Write back the modified database content
Set-Content -Path $gameDbPath -Value $dbContent
Write-Host "Applied password hashing improvements to game_database.gd"

Write-Host "All authentication fixes applied successfully!"
