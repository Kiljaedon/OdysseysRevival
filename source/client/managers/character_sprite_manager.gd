class_name CharacterSpriteManager
extends Node

## Manages character sprite loading, caching, and animation setup.
## Handles sprite atlas access, SpriteFrames creation, and character JSON data.
##
## Features:
## - Lazy loading of sprite textures via AtlasTexture
## - Sprite caching with region-based atlas extraction
## - SpriteFrames creation from character JSON data
## - Character JSON data caching
## - Support for tall sprite adjustments (e.g., Cleric row)
## - Backward compatibility with legacy sprite naming formats
##
## Dependencies:
## - Sprite atlases: res://assets-odyssey/sprites_part1.png, sprites_part2.png
## - Character data: res://characters/classes/*.json, res://characters/npcs/*.json
##
## Caching Strategy:
## - sprite_cache: AtlasTexture objects by "atlas_row_col" key
## - spriteframes_cache: SpriteFrames objects by character class name
## - character_data_cache: Parsed JSON data by character name
##
## Usage:
## var sprite_mgr = CharacterSpriteManager.new()
## sprite_mgr.load_sprite_atlases()
## var char_data = sprite_mgr.load_character_data("class:Warrior")
## var sprites = sprite_mgr.setup_character_sprite(char_data, animated_sprite)

# BLACK LINE FIX: Must match odyssey_sprite_maker.gd CROP_EDGE value
# Set to 0 to disable cropping (sprites will be full 32x32)
# Set to 1 to crop 1px from all edges (sprites will be 30x30 from center of 32x32 region)
const CROP_EDGE = 1  # Change to 0 to undo the fix

var sprite_atlas_textures: Array[Texture2D] = []
var sprite_cache: Dictionary = {}  # atlas_row_col -> AtlasTexture
var spriteframes_cache: Dictionary = {}  # character_name -> SpriteFrames
var character_data_cache: Dictionary = {}  # character_name -> JSON data

func initialize() -> void:
	"""Initialize sprite manager."""
	print("[CharacterSpriteManager] Initialized")

func load_sprite_atlases() -> void:
	"""Load sprite atlas textures once on startup."""
	var atlas1 = load("res://assets-odyssey/sprites_part1.png")
	var atlas2 = load("res://assets-odyssey/sprites_part2.png")

	if atlas1 and atlas2:
		sprite_atlas_textures.append(atlas1)
		sprite_atlas_textures.append(atlas2)
		print("✓ Loaded sprite atlases:")
		print("  Atlas 1 size: ", atlas1.get_size())
		print("  Atlas 2 size: ", atlas2.get_size())
	else:
		print("ERROR: Could not load sprite atlases")
		if not atlas1:
			print("  Missing: sprites_part1.png")
		if not atlas2:
			print("  Missing: sprites_part2.png")

func get_sprite_from_atlas(atlas_index: int, row: int, col: int) -> Texture2D:
	"""Create AtlasTexture from coordinates with caching."""
	var cache_key = "%d_%d_%d" % [atlas_index, row, col]

	if not sprite_cache.has(cache_key):
		if atlas_index >= sprite_atlas_textures.size():
			print("ERROR: Invalid atlas_index: ", atlas_index)
			return null

		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = sprite_atlas_textures[atlas_index]

		# Calculate position - account for row offset in part2
		var local_row = row if atlas_index == 0 else row - 512
		var x = col * 32
		var y = local_row * 32

		# Character-specific height adjustments for tall sprites
		# Cleric (row 102) needs extra height to show full head
		var sprite_height = 32
		var y_offset = 0

		if row == 102:  # Cleric row
			sprite_height = 38  # Grab 38 pixels tall (extend downward)
			y_offset = -1  # Start 1 pixel higher to capture top of head

		# Apply edge crop to remove black border artifacts (if enabled)
		atlas_tex.region = Rect2(
			x + CROP_EDGE,              # Crop left edge
			y + y_offset + CROP_EDGE,   # Crop top edge (adjusted for tall sprites)
			32 - (CROP_EDGE * 2),       # Reduce width
			sprite_height - (CROP_EDGE * 2)  # Reduce height (adjusted for tall sprites)
		)
		sprite_cache[cache_key] = atlas_tex
		print("    Created sprite texture: atlas=", atlas_index, " row=", row, " col=", col, " region=", atlas_tex.region)

	return sprite_cache[cache_key]

func get_sprite_from_frame_data(frame_data: Dictionary) -> Texture2D:
	"""Load sprite from frame data - handles both old and new formats."""
	# New format: atlas_index, row, col
	if frame_data.has("atlas_index"):
		var atlas_idx = frame_data.get("atlas_index", 0)
		var row = frame_data.get("row", 0)
		var col = frame_data.get("col", 0)
		return get_sprite_from_atlas(atlas_idx, row, col)

	# Old format: sprite_file (backward compatibility)
	elif frame_data.has("sprite_file"):
		var sprite_file = frame_data.get("sprite_file", "")
		# Parse filename: "char_0005_r00_c05.png" or "sprite_0005_r000_c05.png"
		var parts = sprite_file.replace(".png", "").split("_")
		if parts.size() >= 4:
			var row_str = parts[2].substr(1)  # "r00" -> "00"
			var col_str = parts[3].substr(1)  # "c05" -> "05"
			var row = row_str.to_int()
			var col = col_str.to_int()
			var atlas_idx = 0 if row < 512 else 1
			return get_sprite_from_atlas(atlas_idx, row, col)

	print("WARNING: Invalid frame data format: ", frame_data)
	return null

func load_character_data(character_name: String) -> Dictionary:
	"""Load character data from JSON file with caching."""
	print("Loading character: ", character_name)

	# Check cache first
	if character_data_cache.has(character_name):
		print("  Cached character data for: ", character_name)
		return character_data_cache[character_name]

	# Parse type prefix (class: or npc:)
	var file_path = ""
	if character_name.begins_with("class:"):
		var name = character_name.replace("class:", "")
		file_path = "res://characters/classes/" + name + ".json"
	elif character_name.begins_with("npc:"):
		var name = character_name.replace("npc:", "")
		file_path = "res://characters/npcs/" + name + ".json"
	else:
		# Fallback for old format
		file_path = "res://characters/" + character_name + ".json"

	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_text)

		if parse_result == OK:
			# Cache the parsed data
			character_data_cache[character_name] = json.data
			print("  Cached character data for: ", character_name)
			return json.data
		else:
			print("Error parsing character JSON: ", character_name)
			return {}
	else:
		print("Character file not found: ", file_path)
		return {}

func setup_character_sprite(char_data: Dictionary, animated_sprite: AnimatedSprite2D) -> SpriteFrames:
	"""Setup character sprite animations from character data."""
	print("=== SETUP CHARACTER SPRITE ===")

	if char_data == null or char_data.is_empty():
		print("  ERROR: character data is null or empty!")
		return null

	print("  DEBUG: All character data keys: ", char_data.keys())
	print("  DEBUG: character_id = ", char_data.get("character_id", "MISSING"))
	print("  DEBUG: class_name = ", char_data.get("class_name", "MISSING"))
	print("  DEBUG: name = ", char_data.get("name", "MISSING"))

	if char_data.has("animations"):
		# Use class_name for players, character_name for NPCs
		var char_name = char_data.get("class_name", "")
		if char_name.is_empty():
			char_name = char_data.get("character_name", "unknown_class")

		print("  Cache key: ", char_name)
		print("  Animations in JSON: ", char_data.animations.keys())

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
				if char_data.animations.has(walk1_key):
					var walk1_frames = char_data.animations[walk1_key]
					print("  Processing ", walk1_key, ": ", walk1_frames.size(), " frames")
					for frame_data in walk1_frames:
						var texture = get_sprite_from_frame_data(frame_data)
						if texture:
							sprite_frames.add_frame(walk_anim_name, texture)
						else:
							print("    WARNING: Failed to load texture for ", walk1_key)

				# Add walk frame 2
				var walk2_key = "walk_" + direction + "_2"
				if char_data.animations.has(walk2_key):
					var walk2_frames = char_data.animations[walk2_key]
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
				if char_data.animations.has(attack_key):
					if not sprite_frames.has_animation(attack_anim_name):
						sprite_frames.add_animation(attack_anim_name)
						sprite_frames.set_animation_loop(attack_anim_name, false)  # Don't loop attacks
						sprite_frames.set_animation_speed(attack_anim_name, 1.0)  # 1 second duration

					var attack_frames = char_data.animations[attack_key]
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
		return sprite_frames

	return null
