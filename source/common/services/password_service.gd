class_name PasswordService
extends RefCounted
## Password hashing and verification service
## Uses SHA256 with salt for secure password storage

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
		# Legacy hash without salt
		return _hash_password_legacy(password) == password_hash

	var salt = parts[0]
	var expected_hash = parts[1]
	var computed = hash_password(password, salt)
	var computed_hash = computed.split(":")[1]

	return computed_hash == expected_hash

static func _hash_password_legacy(password: String) -> String:
	"""For backwards compatibility with existing accounts without salt"""
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(password.to_utf8_buffer())
	return ctx.finish().hex_encode()
