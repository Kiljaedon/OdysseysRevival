extends Node

const CredentialsUtils = preload("res://source/common/utils/credentials_utils.gd")

func login(username: String, password: String) -> Dictionary:
	"""Attempt to log in a user"""
	var repo = RepositoryFactory.get_account_repository()
	var result = repo.get_account(username)
	
	if not result.success:
		return {"success": false, "error": "Invalid username or password"}
		
	var account = result.account
	if _verify_password(password, account.password_hash):
		# Update last login
		account.last_login = Time.get_datetime_string_from_system()
		repo.save_account(username, account)
		return {"success": true, "account": account}
	else:
		return {"success": false, "error": "Invalid username or password"}

func create_account(username: String, password: String) -> Dictionary:
	"""Register a new account"""
	# Validate input
	var user_validation = CredentialsUtils.validate_username(username)
	if user_validation.code != CredentialsUtils.UsernameError.OK:
		return {"success": false, "error": user_validation.message}
		
	var pass_validation = CredentialsUtils.validate_password(password)
	if pass_validation.code != CredentialsUtils.UsernameError.OK:
		return {"success": false, "error": pass_validation.message}
		
	var repo = RepositoryFactory.get_account_repository()
	var password_hash = _hash_password(password)
	
	return repo.create_account(username, password_hash)

# --- Crypto Helpers (Moved from GameDatabase) ---

func _hash_password(password: String, salt: String = "") -> String:
	"""Hash password using SHA256 with salt"""
	if salt.is_empty():
		salt = str(randi() % 999999999)

	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((password + salt).to_utf8_buffer())
	var hash = ctx.finish().hex_encode()

	return salt + ":" + hash

func _verify_password(password: String, password_hash: String) -> bool:
	"""Verify password against stored hash"""
	var parts = password_hash.split(":", false, 1)
	if parts.size() != 2:
		return _hash_password_legacy(password) == password_hash

	var salt = parts[0]
	var expected_hash = parts[1]
	var computed = _hash_password(password, salt)
	var computed_hash = computed.split(":")[1]

	return computed_hash == expected_hash

func _hash_password_legacy(password: String) -> String:
	"""For backwards compatibility with existing accounts"""
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(password.to_utf8_buffer())
	return ctx.finish().hex_encode()
