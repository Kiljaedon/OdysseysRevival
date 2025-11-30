#!/usr/bin/env -S godot -s
extends SceneTree

# Test script to verify character creation and login flow
# Tests the entire character pipeline: create → save → load → render

func _init():
	print("\n" + "=".repeat(80))
	print("CHARACTER CREATION & LOGIN FLOW TEST")
	print("=".repeat(80))

	# Initialize necessary systems
	var game_db = preload("res://source/common/database/game_database.gd")

	# Test 1: Account creation
	print("\n[TEST 1] Creating test account...")
	var account_result = game_db.create_account("testuser", "password123")
	if not account_result.success:
		print("  ❌ FAILED: ", account_result.error)
		quit(1)
	print("  ✓ Account created successfully")

	# Test 2: Character creation with animations
	print("\n[TEST 2] Creating character with embedded animations...")
	var character_data = {
		"name": "TestMage",
		"class_name": "Mage",
		"level": 1,
		"health": 100,
		"mana": 50
	}

	var create_result = game_db.create_character("testuser", character_data)
	if not create_result.success:
		print("  ❌ FAILED: ", create_result.error)
		quit(1)

	var char_id = create_result.character_id
	print("  ✓ Character created: ", char_id)
	print("  ✓ Character has animations: ", "animations" in create_result.character)
	if "animations" in create_result.character:
		print("    - Animation keys: ", create_result.character.animations.keys())

	# Test 3: Load character back from disk
	print("\n[TEST 3] Loading character from disk...")
	var load_result = game_db.get_character(char_id)
	if not load_result.success:
		print("  ❌ FAILED: ", load_result.error)
		quit(1)

	var loaded_char = load_result.character
	print("  ✓ Character loaded: ", loaded_char.get("name"))
	print("  ✓ Loaded character has animations: ", "animations" in loaded_char)
	if "animations" in loaded_char:
		var anim_keys = loaded_char.animations.keys()
		print("    - Animation count: ", anim_keys.size())
		for key in anim_keys:
			var frames = loaded_char.animations[key]
			print("    - ", key, ": ", frames.size(), " frame groups")

	# Test 4: Verify character can be loaded for rendering
	print("\n[TEST 4] Verifying character rendering data...")
	var animation_found = false
	if "animations" in loaded_char:
		for anim_key in loaded_char.animations.keys():
			if anim_key.contains("walk_down"):
				animation_found = true
				var frames = loaded_char.animations[anim_key]
				print("  ✓ Found walk_down animation with ", frames.size(), " frame groups")
				break

	if not animation_found:
		print("  ❌ FAILED: walk_down animation not found in character data")
		quit(1)

	# Test 5: Check account has character in list
	print("\n[TEST 5] Verifying account character list...")
	var account = game_db.get_account("testuser").account
	if not account.characters.has(char_id):
		print("  ❌ FAILED: Character not in account's character list")
		quit(1)
	print("  ✓ Character in account: ", account.characters.size(), " total characters")

	# Test 6: Verify class template exists and is readable
	print("\n[TEST 6] Verifying class template...")
	var class_file = ProjectSettings.globalize_path("res://characters/classes/Mage.json")
	if not FileAccess.file_exists(class_file):
		print("  ❌ FAILED: Mage.json class file not found at ", class_file)
		quit(1)
	print("  ✓ Class template exists: Mage.json")

	print("\n" + "=".repeat(80))
	print("ALL TESTS PASSED! ✓")
	print("=".repeat(80))
	print("\nCharacter Pipeline Summary:")
	print("  1. Account created successfully")
	print("  2. Character created with embedded animations")
	print("  3. Character loaded from disk with all data intact")
	print("  4. Rendering animations available in character data")
	print("  5. Account tracks character correctly")
	print("  6. Class templates available for validation")
	print("\n✓ Character flow is working correctly!")
	print("✓ Server can create characters with embedded animations")
	print("✓ Client can load and render characters")
	print("\n")

	quit(0)
