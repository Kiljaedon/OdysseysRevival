# Quick script to generate admin password hash
extends Node

func _ready():
	var password = "!Lld0926ld0926"
	var salt = str(randi() % 999999999)
	
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((password + salt).to_utf8_buffer())
	var hash = ctx.finish().hex_encode()
	
	var password_hash = salt + ":" + hash
	
	print("Generated password hash for Admin: " + password_hash)
	print("Salt: " + salt)
	print("Hash: " + hash)
	print("Combined: " + password_hash)
	
	get_tree().quit()
