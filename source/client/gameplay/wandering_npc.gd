extends CharacterBody2D
class_name WanderingNPC

# Static texture cache - shared by ALL NPCs for memory efficiency
static var texture_cache: Dictionary = {}

# NPC properties
var npc_name: String = ""
var spawn_position: Vector2 = Vector2.ZERO
var wander_radius: int = 3  # Tiles
var map_width: float = 0.0  # Map boundary (pixels)
var map_height: float = 0.0  # Map boundary (pixels)
var battle_enabled: bool = true  # Whether this NPC can trigger combat

# Animation data
var animation_data: Dictionary = {}
var atlas_textures: Array[Texture2D] = []
var crop_edge: int = 1

# Movement state
var is_moving: bool = false
var current_target: Vector2 = Vector2.ZERO
var current_direction: String = "down"
var move_speed: float = 100.0

# Stuck detection
var stuck_timer: float = 0.0
var stuck_threshold: float = 0.15  # If no movement for 0.15 seconds, consider stuck (1 animation cycle)

# Timers
var idle_timer: float = 0.0
var idle_duration: float = 2.0  # Seconds to wait before next move

# Animation
var animated_sprite: AnimatedSprite2D = null

# Combat
var hurtbox: Area2D = null
var npc_type: String = "Rogue"  # NPC type for combat (Rogue, Goblin, etc.)

func _ready():
	print("WanderingNPC ready: ", npc_name)

	# Setup collision - NPCs are solid but don't push players
	collision_layer = 2  # NPCs on layer 2
	collision_mask = 1   # NPCs only collide with walls, not players (server controls NPC movement)

	# Create collision shape (rectangle to match player)
	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(50, 85)  # Match player collision box
	collision_shape.shape = rect_shape
	add_child(collision_shape)

	# Create hurtbox for attack detection
	hurtbox = Area2D.new()
	hurtbox.collision_layer = 8  # Layer 8 for NPC hurtboxes
	hurtbox.collision_mask = 4  # Detect player attack hitbox on layer 4
	hurtbox.monitorable = true
	hurtbox.monitoring = true
	hurtbox.area_entered.connect(_on_attack_hit)  # Trigger when player's attack hitbox enters
	add_child(hurtbox)

	var hurtbox_shape = CollisionShape2D.new()
	var hurtbox_rect = RectangleShape2D.new()
	hurtbox_rect.size = Vector2(60, 95)  # Slightly larger than collision for attack detection
	hurtbox_shape.shape = hurtbox_rect
	hurtbox.add_child(hurtbox_shape)

	create_animated_sprite()
	load_animations()
	play_idle_animation()

func create_animated_sprite():
	"""Create the animated sprite for this NPC"""
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.sprite_frames = SpriteFrames.new()
	animated_sprite.scale = Vector2(3.0, 3.0)  # Match character scale
	animated_sprite.visible = true  # Ensure sprite is visible
	add_child(animated_sprite)

func load_animations():
	"""Load all animations from the NPC data"""
	if not animated_sprite:
		print("[WanderingNPC] ERROR: animated_sprite is null for ", npc_name)
		return
	if animation_data.is_empty():
		print("[WanderingNPC] WARNING: animation_data is empty for ", npc_name)
		return

	print("[WanderingNPC] Loading animations for ", npc_name)

	# Create walk animations for each direction (combining walk_1 and walk_2)
	for direction in ["up", "down", "left", "right"]:
		var walk_1_key = "walk_" + direction + "_1"
		var walk_2_key = "walk_" + direction + "_2"

		if not animation_data.has(walk_1_key) or not animation_data.has(walk_2_key):
			continue

		var walk_1_frames = animation_data[walk_1_key]
		var walk_2_frames = animation_data[walk_2_key]

		if walk_1_frames.is_empty() or walk_2_frames.is_empty():
			continue

		# Create single walk animation with both frames
		var anim_name = "walk_" + direction

		# Remove animation if it already exists (from previous load)
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.sprite_frames.remove_animation(anim_name)

		animated_sprite.sprite_frames.add_animation(anim_name)
		animated_sprite.sprite_frames.set_animation_loop(anim_name, true)
		animated_sprite.sprite_frames.set_animation_speed(anim_name, 6.0)

		# Add walk_1 frame
		for frame_data in walk_1_frames:
			var texture = get_sprite_from_atlas(
				int(frame_data.atlas_index),
				int(frame_data.row),
				int(frame_data.col)
			)
			if texture:
				animated_sprite.sprite_frames.add_frame(anim_name, texture)

		# Add walk_2 frame
		for frame_data in walk_2_frames:
			var texture = get_sprite_from_atlas(
				int(frame_data.atlas_index),
				int(frame_data.row),
				int(frame_data.col)
			)
			if texture:
				animated_sprite.sprite_frames.add_frame(anim_name, texture)

	print("NPC animations loaded: ", animated_sprite.sprite_frames.get_animation_names())

func get_sprite_from_atlas(atlas_index: int, row: int, col: int) -> Texture2D:
	"""Create AtlasTexture from coordinates with caching for memory efficiency"""
	# Create cache key
	var cache_key = "%d_%d_%d" % [atlas_index, row, col]

	# Return cached texture if it exists
	if texture_cache.has(cache_key):
		return texture_cache[cache_key]

	# Not in cache - create new texture
	if atlas_index >= atlas_textures.size():
		return null

	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = atlas_textures[atlas_index]

	# Calculate position - account for row offset in part2
	var local_row = row if atlas_index == 0 else row - 512
	var x = col * 32
	var y = local_row * 32

	# Apply edge crop
	atlas_tex.region = Rect2(
		x + crop_edge,
		y + crop_edge,
		32 - (crop_edge * 2),
		32 - (crop_edge * 2)
	)

	# Store in cache for reuse
	texture_cache[cache_key] = atlas_tex
	return atlas_tex

func start_wandering():
	"""Start the NPC wandering behavior"""
	print("NPC starting to wander: ", npc_name)
	set_process(true)
	pick_new_target()

func _process(delta):
	if is_moving:
		move_towards_target(delta)
	else:
		# Idle - wait before picking new target
		idle_timer += delta
		if idle_timer >= idle_duration:
			pick_new_target()
			idle_timer = 0.0

func pick_new_target():
	"""Pick a random position within wander radius or idle"""
	# 30% chance to just idle instead of moving
	if randf() < 0.3:
		print("NPC choosing to idle")
		is_moving = false
		play_idle_animation()
		idle_duration = randf_range(3.0, 6.0)  # Longer idle when choosing to rest
		return

	var tile_size = 128  # 4x scale (32 * 4)
	var max_distance = wander_radius * tile_size

	# Random offset from spawn position
	var random_offset = Vector2(
		randf_range(-max_distance, max_distance),
		randf_range(-max_distance, max_distance)
	)

	current_target = spawn_position + random_offset

	# Clamp target within map boundaries (with padding for sprite size)
	var padding = 64.0  # Half sprite width at 3x scale (32 * 3 / 2 = 48, rounded up)
	if map_width > 0 and map_height > 0:
		current_target.x = clamp(current_target.x, padding, map_width - padding)
		current_target.y = clamp(current_target.y, padding, map_height - padding)

	is_moving = true
	stuck_timer = 0.0  # Reset stuck detection

	# Determine direction for animation
	var direction = (current_target - position).normalized()
	if abs(direction.x) > abs(direction.y):
		current_direction = "right" if direction.x > 0 else "left"
	else:
		current_direction = "down" if direction.y > 0 else "up"

	play_walk_animation()
	print("NPC picking new target: ", current_target, " direction: ", current_direction)

func move_towards_target(delta):
	"""Move towards current target with stuck detection"""
	var direction = (current_target - position).normalized()
	var distance_to_target = position.distance_to(current_target)

	if distance_to_target < 5.0:  # Close enough
		position = current_target
		is_moving = false
		play_idle_animation()
		# Random idle duration between 2-5 seconds
		idle_duration = randf_range(2.0, 5.0)
		stuck_timer = 0.0
		print("NPC reached target, idling for ", idle_duration, " seconds")
		return

	# Store position before moving
	var position_before = position

	# Move towards target
	velocity = direction * move_speed
	move_and_slide()

	# Check if stuck against wall (compare movement THIS frame)
	var moved_distance = position.distance_to(position_before)
	var expected_movement = move_speed * delta

	# If moved less than 10% of expected distance, we're hitting something
	if moved_distance < expected_movement * 0.1:
		stuck_timer += delta
		if stuck_timer >= stuck_threshold:
			# Stuck! Pick new target immediately
			print("NPC stuck against obstacle, picking new target")
			is_moving = false
			play_idle_animation()
			idle_duration = randf_range(0.3, 0.8)  # Very short idle before new target
			stuck_timer = 0.0
			return
	else:
		# Moving successfully, reset stuck timer
		stuck_timer = 0.0

func play_walk_animation():
	"""Play walking animation for current direction"""
	if not animated_sprite:
		return

	var anim_name = "walk_" + current_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func play_idle_animation():
	"""Play idle animation (just show first frame of walk animation)"""
	if not animated_sprite:
		return

	var anim_name = "walk_" + current_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		animated_sprite.pause()
		animated_sprite.frame = 0  # Show first frame

func _on_attack_hit(area: Area2D):
	"""Triggered when player's attack hitbox hits this NPC - send attack request to server"""
	print("[NPC_HURTBOX] ===== ATTACK HIT RECEIVED =====")
	print("[NPC_HURTBOX] NPC: %s, Hurtbox: %s, Area hit: %s" % [npc_name, hurtbox.name, area.name])
	print("[NPC_HURTBOX] Battle enabled: %s" % battle_enabled)

	# CHECK WEAPON STATE FIRST - prevent attacks when weapon is sheathed
	var player = area.get_parent()  # Get the player character
	if player:
		var weapon_state = player.get_node_or_null("WeaponState")
		if weapon_state:
			if not weapon_state.can_attack():
				print("[NPC_HURTBOX] Attack blocked - weapon is SHEATHED!")
				return
		else:
			print("[NPC_HURTBOX] WARNING: No WeaponState found - allowing attack")

	# Check if battles are enabled on this map
	if not battle_enabled:
		print("[NPC_HURTBOX] Combat disabled on this map - ignoring attack on ", npc_name)
		return

	# This is client-side NPC, but we need the server NPC ID
	# Find the NPC ID from the name (format: "npc_<id>")
	var npc_id_str = name
	if npc_id_str.begins_with("npc_"):
		var npc_id = int(npc_id_str.substr(4))
		print("[NPC_HURTBOX] Player attacked NPC #%d (%s) - requesting combat from server" % [npc_id, npc_name])

		# Send attack request to server via ServerConnection
		var server_conn = get_tree().root.get_node_or_null("ServerConnection")
		if server_conn:
			print("[NPC_HURTBOX] ServerConnection found - sending RPC request_npc_attack")
			# CRITICAL FIX: Use rpc_id(1) to send to server (peer ID 1 is always the server)
			server_conn.request_npc_attack.rpc_id(1, npc_id)
			print("[NPC_HURTBOX] RPC sent to server (peer ID 1)")
		else:
			print("[NPC_HURTBOX] ERROR: Could not find ServerConnection node!")
	else:
		print("[NPC_HURTBOX] ERROR: NPC name doesn't match expected format: %s" % name)
