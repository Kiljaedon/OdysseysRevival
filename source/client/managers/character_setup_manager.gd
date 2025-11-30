class_name CharacterSetupManager
extends Node

## ============================================================================
## CHARACTER SETUP MANAGER
## ============================================================================
## Handles character sprite initialization and animation configuration including:
## - Character sprite setup from animation data
## - SpriteFrames creation and caching
## - Animation loading (walk and attack cycles)
## - Character visual customization
## ============================================================================

# Dependencies (injected during initialization)
var animated_sprite: AnimatedSprite2D
var character_sprite_manager: Node

# Sprite caches (shared references)
var spriteframes_cache: Dictionary = {}  # character_name → SpriteFrames
var current_character_data: Dictionary = {}

func initialize(
	_animated_sprite: AnimatedSprite2D,
	_character_sprite_manager: Node,
	_spriteframes_cache: Dictionary
) -> void:
	"""Initialize manager with dependency injection."""
	animated_sprite = _animated_sprite
	character_sprite_manager = _character_sprite_manager
	spriteframes_cache = _spriteframes_cache

	print("[CharacterSetupManager] Initialized")

## ============================================================================
## CHARACTER SPRITE SETUP
## ============================================================================

func setup_character_sprite(_current_character_data: Dictionary) -> void:
	"""Setup character sprite from character data with animation frames"""
	current_character_data = _current_character_data

	print("=== SETUP CHARACTER SPRITE ===")

	if current_character_data == null or current_character_data.is_empty():
		print("  ERROR: current_character_data is null or empty!")
		return

	print("  DEBUG: All character data keys: ", current_character_data.keys())
	print("  DEBUG: character_id = ", current_character_data.get("character_id", "MISSING"))
	print("  DEBUG: class_name = ", current_character_data.get("class_name", "MISSING"))
	print("  DEBUG: name = ", current_character_data.get("name", "MISSING"))

	# FALLBACK: If server didn't send animations, load them from JSON ourselves
	if not current_character_data.has("animations"):
		print("  [FALLBACK] Server didn't send animations - loading from JSON")
		var char_class = current_character_data.get("class_name", "")
		var char_name = current_character_data.get("character_name", "")
		var json_file = ""

		if not char_class.is_empty():
			# Player character - load from classes/
			json_file = "res://characters/classes/%s.json" % char_class
		elif not char_name.is_empty():
			# NPC - load from npcs/
			json_file = "res://characters/npcs/%s.json" % char_name

		if not json_file.is_empty() and FileAccess.file_exists(json_file):
			var file = FileAccess.open(json_file, FileAccess.READ)
			if file:
				var json_text = file.get_as_text()
				file.close()
				var json = JSON.new()
				if json.parse(json_text) == OK:
					var data = json.data
					if data.has("animations"):
						current_character_data["animations"] = data["animations"]
						print("  [FALLBACK] Loaded animations from: ", json_file)
					else:
						print("  [FALLBACK ERROR] No animations in JSON: ", json_file)
				else:
					print("  [FALLBACK ERROR] Failed to parse JSON: ", json_file)
			else:
				print("  [FALLBACK ERROR] Could not open file: ", json_file)
		else:
			print("  [FALLBACK ERROR] JSON file not found: ", json_file)

	if current_character_data.has("animations"):
		# Use class_name for players, character_name for NPCs
		var char_name = current_character_data.get("class_name", "")
		if char_name.is_empty():
			char_name = current_character_data.get("character_name", "unknown_class")

		print("  Cache key: ", char_name)
		print("  Animations in JSON: ", current_character_data.animations.keys())

		# Check if SpriteFrames already cached
		var sprite_frames: SpriteFrames
		if spriteframes_cache.has(char_name):
			print("  Using cached SpriteFrames for: ", char_name)
			sprite_frames = spriteframes_cache[char_name]
		else:
			print("  Creating new SpriteFrames for: ", char_name)
			sprite_frames = SpriteFrames.new()

			# Create all direction animations with proper walking cycles
			var anim_directions = ["up", "down", "left", "right"]

			for direction in anim_directions:
				# Create walking animation (walk_X_1 and walk_X_2)
				var walk_anim_name = "walk_" + direction
				if not sprite_frames.has_animation(walk_anim_name):
					sprite_frames.add_animation(walk_anim_name)
					sprite_frames.set_animation_loop(walk_anim_name, true)
					sprite_frames.set_animation_speed(walk_anim_name, 6.0)  # 6 FPS for smooth walking

				# Add walk frame 1
				var walk1_key = "walk_" + direction + "_1"
				if current_character_data.animations.has(walk1_key):
					var walk1_frames = current_character_data.animations[walk1_key]
					print("  Processing ", walk1_key, ": ", walk1_frames.size(), " frames")
					for frame_data in walk1_frames:
						var texture = get_sprite_from_frame_data(frame_data)
						if texture:
							sprite_frames.add_frame(walk_anim_name, texture)
						else:
							print("    WARNING: Failed to load texture for ", walk1_key)

				# Add walk frame 2
				var walk2_key = "walk_" + direction + "_2"
				if current_character_data.animations.has(walk2_key):
					var walk2_frames = current_character_data.animations[walk2_key]
					print("  Processing ", walk2_key, ": ", walk2_frames.size(), " frames")
					for frame_data in walk2_frames:
						var texture = get_sprite_from_frame_data(frame_data)
						if texture:
							sprite_frames.add_frame(walk_anim_name, texture)
						else:
							print("    WARNING: Failed to load texture for ", walk2_key)

				# Report walk animation frame count
				var walk_frame_count = sprite_frames.get_frame_count(walk_anim_name)
				print("  → ", walk_anim_name, " has ", walk_frame_count, " frames")

				# Create attack animation
				var attack_anim_name = "attack_" + direction
				var attack_key = "attack_" + direction
				if current_character_data.animations.has(attack_key):
					if not sprite_frames.has_animation(attack_anim_name):
						sprite_frames.add_animation(attack_anim_name)
						sprite_frames.set_animation_loop(attack_anim_name, false)  # Don't loop attacks
						sprite_frames.set_animation_speed(attack_anim_name, 1.0)  # 1 second duration

					var attack_frames = current_character_data.animations[attack_key]
					print("  Processing ", attack_key, ": ", attack_frames.size(), " frames")
					for frame_data in attack_frames:
						var texture = get_sprite_from_frame_data(frame_data)
						if texture:
							sprite_frames.add_frame(attack_anim_name, texture)
						else:
							print("    WARNING: Failed to load texture for ", attack_key)

					var attack_frame_count = sprite_frames.get_frame_count(attack_anim_name)
					print("  → ", attack_anim_name, " has ", attack_frame_count, " frames")

			# Cache the SpriteFrames for reuse
			spriteframes_cache[char_name] = sprite_frames
			print("  Cached SpriteFrames for: ", char_name)

		# Set default animation to walk_down
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.visible = true
		print("  Setting AnimatedSprite2D.sprite_frames")
		print("  AnimatedSprite2D visible: ", animated_sprite.visible)
		print("  AnimatedSprite2D scale: ", animated_sprite.scale)

		if sprite_frames.has_animation("walk_down"):
			animated_sprite.play("walk_down")
			animated_sprite.pause()  # Start paused (idle)
			print("  Started animation: walk_down (paused)")
		else:
			print("  WARNING: walk_down animation not found!")

		print("=== CHARACTER SPRITE SETUP COMPLETE ===")

func get_sprite_from_frame_data(frame_data: Dictionary) -> Texture2D:
	"""Delegate to character sprite manager to get sprite texture"""
	if character_sprite_manager:
		return character_sprite_manager.get_sprite_from_frame_data(frame_data)
	else:
		print("WARNING: Character sprite manager not initialized")
		return null

## ============================================================================
## ACCESSORS
## ============================================================================

func get_current_character_data() -> Dictionary:
	"""Get current character data"""
	return current_character_data

func get_spriteframes_cache() -> Dictionary:
	"""Get SpriteFrames cache"""
	return spriteframes_cache
