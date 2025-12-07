class_name InputHandlerManager
extends Node
## Phase 2: Input Handler Manager
## Manages all input processing, movement control, and attack handling
## Dependencies: AnimationControlManager, CharacterBody2D, Camera2D, AnimatedSprite2D, Area2D

# ============================================================================
# EXPORTED PROPERTIES - Tuning parameters
# ============================================================================

@export var movement_speed: float = 200.0
@export var attack_duration: float = 0.5
@export var zoom_min: float = 0.5
@export var zoom_max: float = 4.0
@export var zoom_step: float = 0.25

# ============================================================================
# STATE VARIABLES - Direction and movement
# ============================================================================

var current_direction: String = "down"
var attack_direction: String = "down"  # Direction when attack started
var is_attacking: bool = false
var attack_timer: float = 0.0
var current_zoom: float = 2.0

# Dash/Teleport State
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
const DASH_SPEED: float = 600.0
const DASH_DURATION: float = 0.2
const DASH_COOLDOWN_TIME: float = 1.0

# ============================================================================
# NODE REFERENCES - Injected via initialize()
# ============================================================================

var test_character: CharacterBody2D
var camera: Camera2D
var animation_control_mgr: AnimationControlManager
var animated_sprite: AnimatedSprite2D
var attack_hitbox: Area2D
var attack_hitbox_shape: CollisionShape2D
var character_sheet: Panel = null

# ============================================================================
# REFERENCES TO EXTERNAL SYSTEMS
# ============================================================================

var server_npcs: Dictionary = {}  # Reference to server NPCs for hit detection
var WanderingNPC = preload("res://source/client/gameplay/wandering_npc.gd")  # NPC class for type checking
var on_npc_attacked: Callable = Callable()  # Callback when NPC is hit - set by parent controller

# Weapon state reference (for sheath/unsheath toggle)
var weapon_state = null

# Map transition system
var map_manager: MapManager = null
var transition_cooldown: float = 0.0
const TRANSITION_COOLDOWN_TIME: float = 0.5  # Prevent rapid re-triggers

# Prediction System
var prediction_history: Array = []
var current_sequence: int = 0
var multiplayer_manager: Node

# ============================================================================
# INITIALIZATION
# ============================================================================

func initialize(character: CharacterBody2D, cam: Camera2D, anim_mgr: AnimationControlManager,
				sprite: AnimatedSprite2D, hitbox: Area2D, char_sheet: Panel = null):
	"""Initialize the input handler manager with required node references"""
	test_character = character
	camera = cam
	animation_control_mgr = anim_mgr
	animated_sprite = sprite
	attack_hitbox = hitbox
	character_sheet = char_sheet

	# Find the collision shape child of the attack hitbox
	if attack_hitbox and attack_hitbox.get_child_count() > 0:
		attack_hitbox_shape = attack_hitbox.get_child(0) as CollisionShape2D

	# Initialize zoom to current camera value if available
	if camera:
		current_zoom = camera.zoom.x

	# Find weapon_state on test_character (SIMPLE DIRECT APPROACH)
	if test_character:
		weapon_state = test_character.get_node_or_null("WeaponState")
		if weapon_state:
			print("[InputHandlerManager] Found and connected to WeaponState - attacks enabled")
		else:
			print("[InputHandlerManager] WARNING: WeaponState not found - attacks will not check sheath status")

func set_multiplayer_manager(mgr: Node) -> void:
	multiplayer_manager = mgr

# ============================================================================
# INPUT PROCESSING
# ============================================================================

func handle_input(event: InputEvent) -> void:
	"""Handle input events (zoom controls via mouse wheel)"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			# Zoom in
			current_zoom = min(current_zoom + zoom_step, zoom_max)
			if camera:
				camera.zoom = Vector2(current_zoom, current_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			# Zoom out
			current_zoom = max(current_zoom - zoom_step, zoom_min)
			if camera:
				camera.zoom = Vector2(current_zoom, current_zoom)

# ============================================================================
# MOVEMENT HANDLING
# ============================================================================

func process_movement(delta: float) -> void:
	"""Handle attack timer and delegate to handle_movement()"""
	# Handle attack timer
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			# Restore direction to what it was when attack started
			current_direction = attack_direction
			# Return to appropriate animation
			if test_character and test_character.velocity.length() > 0:
				play_walk_animation()
			else:
				play_idle_animation()

	# Handle transition cooldown
	if transition_cooldown > 0:
		transition_cooldown -= delta

	# Handle Dash Cooldown
	if dash_cooldown > 0:
		dash_cooldown -= delta

	# Handle Dash Movement
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			# End Dash
			is_dashing = false
			dash_cooldown = DASH_COOLDOWN_TIME
			test_character.velocity = Vector2.ZERO
			# Restore collision mask (Map + NPCs)
			test_character.collision_mask = 3
			print("[DASH] Ended - Mask restored to 3")
		else:
			# Apply Dash Velocity using move_and_collide to stop on walls
			test_character.velocity = dash_direction * DASH_SPEED
			var collision = test_character.move_and_collide(test_character.velocity * delta)
			if collision:
				# Hit a wall - stop immediately
				is_dashing = false
				dash_cooldown = DASH_COOLDOWN_TIME
				test_character.velocity = Vector2.ZERO
				test_character.collision_mask = 3
				print("[DASH] Hit wall - Stopped")
			return # Skip normal movement while dashing

	handle_movement()
	
	# Apply physics movement (Prediction)
	if test_character:
		test_character.move_and_slide()
		
		# Store prediction state AFTER movement
		if not is_attacking and multiplayer_manager:
			# Record the position we ended up at for this sequence
			# The input for this sequence produced this position
			if prediction_history.size() > 0:
				var last_entry = prediction_history.back()
				if last_entry.sequence == current_sequence:
					last_entry.position = test_character.position

func handle_movement() -> void:
	"""Process WASD movement, zoom, and attack input"""
	var velocity = Vector2.ZERO
	var moving = false

	# Handle zoom controls (= or +)
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
		current_zoom = min(current_zoom + zoom_step, zoom_max)
		if camera:
			camera.zoom = Vector2(current_zoom, current_zoom)
	elif Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		# Zoom out (-)
		current_zoom = max(current_zoom - zoom_step, zoom_min)
		if camera:
			camera.zoom = Vector2(current_zoom, current_zoom)

	# Handle Character Sheet Toggle (C) - Moved to _unhandled_input
	
	# Handle weapon toggle (Tab key)
	if Input.is_action_just_pressed("toggle_weapon"):
		if weapon_state and weapon_state.has_method("toggle"):
			weapon_state.toggle()
			var state_msg = "UNSHEATHED - Combat Mode Active!" if weapon_state.can_attack() else "SHEATHED - Combat Mode Disabled"
			print("[WEAPON] ", state_msg)

	# Handle attack test first (before direction changes)
	if Input.is_action_just_pressed("action"):
		# Check weapon state - can only attack if weapon is unsheathed
		if not is_attacking and weapon_state and weapon_state.has_method("can_attack") and weapon_state.can_attack():
			test_attack_animation()
		elif weapon_state and weapon_state.has_method("can_attack") and not weapon_state.can_attack():
			pass # Silently ignore or show hint
		else:
			pass

	# Check if in battle - if so, skip ALL main world movement
	var game_state = get_node_or_null("/root/GameState")
	var in_battle = game_state and game_state.has_meta("in_server_battle") and game_state.get_meta("in_server_battle")

	if in_battle:
		# Freeze main world character during battle
		velocity = Vector2.ZERO
		if test_character:
			test_character.velocity = Vector2.ZERO
		return  # Skip all main world input processing

	# Only allow movement if not attacking
	if not is_attacking:
		# Handle Dash Input (Shift / Run)
		if (Input.is_action_just_pressed("run") or Input.is_key_pressed(KEY_SHIFT)):
			if dash_cooldown > 0:
				print("[DASH] Failed: Cooldown active (%.2f)" % dash_cooldown)
			elif is_dashing:
				print("[DASH] Failed: Already dashing")
			else:
				start_dash()
				return # Don't process normal movement on the frame we start dashing

		# Capture Input
		var up = Input.is_action_pressed("up")
		var down = Input.is_action_pressed("down")
		var left = Input.is_action_pressed("left")
		var right = Input.is_action_pressed("right")

		# Calculate Velocity
		if up:
			velocity.y -= movement_speed
			current_direction = "up"
			moving = true
		elif down:
			velocity.y += movement_speed
			current_direction = "down"
			moving = true

		if left:
			velocity.x -= movement_speed
			current_direction = "left"
			moving = true
		elif right:
			velocity.x += movement_speed
			current_direction = "right"
			moving = true

		# Update animation based on movement
		if moving:
			play_walk_animation()
		else:
			play_idle_animation()

	else:
		# During attack, stop all movement
		velocity = Vector2.ZERO

	# CLIENT-SIDE PREDICTION - ALWAYS send input to server (even if attacking/stopped)
	# This prevents "ghost movement" where server keeps moving player because it didn't get a stop packet
	if multiplayer_manager and multiplayer_manager.has_method("send_player_input"):
		# Increment sequence
		current_sequence = (current_sequence + 1) % 65536
		var timestamp = Time.get_ticks_msec()

		# If attacking, inputs are effectively forced to false for the server
		# (Since we aren't processing WASD variables in the else block above, we rely on them being initialized to false/0 if we move them out, 
		#  but wait, 'up', 'down' etc are local variables inside the 'if' block. We need to scope them properly.)
		
		# Re-capture raw input state or assume false if attacking?
		# Better to send 'false' if attacking to enforce the stop on server.
		var send_up = Input.is_action_pressed("up") if not is_attacking else false
		var send_down = Input.is_action_pressed("down") if not is_attacking else false
		var send_left = Input.is_action_pressed("left") if not is_attacking else false
		var send_right = Input.is_action_pressed("right") if not is_attacking else false

		# Send input to server
		var packet = PacketEncoder.build_player_input_packet(send_up, send_down, send_left, send_right, current_sequence, timestamp)
		multiplayer_manager.send_player_input(packet)

		# Record prediction history
		prediction_history.append({
			"sequence": current_sequence,
			"timestamp": timestamp,
			"velocity": velocity,
			"position": Vector2.ZERO # Placeholder, updated in process_movement
		})

		# Limit history size
		if prediction_history.size() > 120:
			prediction_history.pop_front()

	# Apply velocity to character
	if test_character:
		test_character.velocity = velocity

	# Check for map transitions when moving
	if moving and map_manager and transition_cooldown <= 0:
		check_map_transition()

func start_dash() -> void:
	"""Initiate a dash/teleport action"""
	print("[DASH] STARTING DASH! Direction: ", current_direction)
	is_dashing = true
	dash_timer = DASH_DURATION
	
	# Determine dash direction from current input or facing
	dash_direction = Vector2.ZERO
	if Input.is_action_pressed("up"): dash_direction.y -= 1
	if Input.is_action_pressed("down"): dash_direction.y += 1
	if Input.is_action_pressed("left"): dash_direction.x -= 1
	if Input.is_action_pressed("right"): dash_direction.x += 1
	
	if dash_direction == Vector2.ZERO:
		# If no input, use current facing
		match current_direction:
			"up": dash_direction.y = -1
			"down": dash_direction.y = 1
			"left": dash_direction.x = -1
			"right": dash_direction.x = 1
	
	dash_direction = dash_direction.normalized()
	
	# Change collision mask to 1 (Map only) - Ignore NPCs (Layer 2)
	if test_character:
		test_character.collision_mask = 1
		print("[DASH] Started - Mask set to 1 (Ghost Mode)")

# ============================================================================
# MAP TRANSITION CHECKING
# ============================================================================

func set_map_manager(mgr: MapManager) -> void:
	"""Set the map manager reference for transition checking"""
	map_manager = mgr
	print("[InputHandlerManager] Map manager connected for transitions")

func check_map_transition() -> void:
	"""Check if player is in a transition zone and moving in the required direction"""
	if not test_character or not map_manager:
		return

	# Convert current_direction to match TMX format (north/south/east/west)
	var direction_map = {
		"up": "north",
		"down": "south",
		"left": "west",
		"right": "east"
	}
	var move_dir = direction_map.get(current_direction, "")

	# Check if position + direction triggers a transition
	var transition = map_manager.check_transition(test_character.position, move_dir)

	if transition.size() > 0:
		print("[InputHandlerManager] Transition triggered!")
		print("  Target: ", transition.target_map)
		print("  Spawn: ", transition.spawn_x, ", ", transition.spawn_y)
		print("  Direction: ", transition.direction)

		# Set cooldown to prevent rapid re-triggers
		transition_cooldown = TRANSITION_COOLDOWN_TIME

		# Emit the transition signal from map_manager
		map_manager.transition_triggered.emit(
			transition.target_map,
			transition.spawn_x,
			transition.spawn_y
		)

# ============================================================================
# ANIMATION CONTROL
# ============================================================================

func play_walk_animation() -> void:
	"""Play walking animation for current direction"""
	if not animated_sprite:
		return

	var anim_name = "walk_" + current_direction
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		# Only start animation if not already playing this animation
		if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
			animated_sprite.play(anim_name)

func play_idle_animation() -> void:
	"""Play idle animation (paused walk animation on first frame)"""
	if not animated_sprite:
		return

	# For idle, pause the walk animation on first frame
	var anim_name = "walk_" + current_direction
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
		animated_sprite.pause()  # Pause on current frame for idle
		animated_sprite.frame = 0  # Reset to first frame

# ============================================================================
# ATTACK HANDLING
# ============================================================================

func test_attack_animation() -> void:
	"""Play attack animation and handle combat initiation"""
	if not animated_sprite:
		print("[ATTACK] ERROR: No animated_sprite!")
		return

	# Store the direction when attack starts
	attack_direction = current_direction
	var anim_name = "attack_" + attack_direction

	# Safety checks
	if not animated_sprite.sprite_frames:
		print("[ATTACK] ERROR: No sprite_frames loaded!")
		return

	if not animated_sprite.sprite_frames.has_animation(anim_name):
		print("[ATTACK] ERROR: Animation not found: ", anim_name)
		return

	var frame_count = animated_sprite.sprite_frames.get_frame_count(anim_name)
	if frame_count == 0:
		print("[ATTACK] ERROR: Animation has no frames: ", anim_name)
		return

	# Play animation
	animated_sprite.play(anim_name)

	# Set attack state
	is_attacking = true
	attack_timer = attack_duration

	# Enable attack hitbox
	enable_attack_hitbox()

	# Connect to animation finished signal if not already connected
	if not animated_sprite.animation_finished.is_connected(_on_attack_animation_finished):
		animated_sprite.animation_finished.connect(_on_attack_animation_finished)

func enable_attack_hitbox() -> void:
	"""Enable attack hitbox in the direction player is facing"""
	if not attack_hitbox:
		print("[HITBOX] ERROR: No attack_hitbox reference!")
		return

	# Position hitbox based on attack direction
	var hitbox_offset = 40.0
	match current_direction:
		"up":
			attack_hitbox.position = Vector2(0, -hitbox_offset)
		"down":
			attack_hitbox.position = Vector2(0, hitbox_offset)
		"left":
			attack_hitbox.position = Vector2(-hitbox_offset, 0)
		"right":
			attack_hitbox.position = Vector2(hitbox_offset, 0)

	# Enable the hitbox
	if attack_hitbox_shape:
		attack_hitbox_shape.disabled = false
	else:
		print("[HITBOX] ERROR: attack_hitbox_shape is null!")

	# Wait for physics frames
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Check for hits
	check_attack_hits()

	# Disable hitbox after brief delay
	if is_inside_tree():
		await get_tree().create_timer(0.2).timeout
		if is_inside_tree() and attack_hitbox_shape:
			attack_hitbox_shape.disabled = true

func check_attack_hits() -> void:
	"""Check if attack hit any NPCs and initiate combat if needed"""
	if not attack_hitbox:
		print("[CHECK_HIT] ERROR: No attack_hitbox!")
		return

	var overlapping_areas = attack_hitbox.get_overlapping_areas()

	for area in overlapping_areas:
		# Safety check: verify area and parent are valid
		if not is_instance_valid(area):
			continue

		var parent = area.get_parent()
		if not is_instance_valid(parent):
			continue

		# Check if this is an NPC hurtbox
		if parent is WanderingNPC:
			var npc = parent as WanderingNPC
			print("  NPC hit: ", npc.npc_name)
			initiate_combat(npc)
			break  # Only hit one NPC per attack

func initiate_combat(npc: Node) -> void:
	"""Send combat request to server (delegates to parent controller)"""
	# Call parent controller's combat initiation via callback
	if on_npc_attacked.is_valid():
		on_npc_attacked.call(npc)
	else:
		print("[ATTACK] ERROR: Combat callback not set!")

func _on_attack_animation_finished() -> void:
	"""Signal handler for when attack animation completes"""
	# Return to appropriate animation when attack finishes
	if is_attacking:
		is_attacking = false
		# Restore direction to what it was when attack started
		current_direction = attack_direction
		if test_character and test_character.velocity.length() > 0:
			play_walk_animation()
		else:
			play_idle_animation()

func _unhandled_input(event: InputEvent) -> void:
	"""Handle single-press input events"""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			if character_sheet and character_sheet.has_method("toggle"):
				character_sheet.toggle()
				print("[INPUT] Toggled Character Sheet")
				get_viewport().set_input_as_handled()

# ============================================================================
# PREDICTION RECONCILIATION
# ============================================================================

func reconcile(server_sequence: int, server_position: Vector2) -> void:
	"""Reconcile client prediction with server authority"""
	if prediction_history.is_empty():
		return

	# 1. Find matching history entry
	var match_index = -1
	for i in range(prediction_history.size()):
		if prediction_history[i].sequence == server_sequence:
			match_index = i
			break

	if match_index == -1:
		# Sequence not found (too old or future?)
		# If server sequence is newer than our oldest, we probably dropped it.
		# If older, we already processed it.
		return

	# 2. Compare positions
	var predicted_pos = prediction_history[match_index].position
	var error_distance = predicted_pos.distance_to(server_position)

	# FIX: Bouncy Collision
	# If we are rubbing against a wall, client and server might disagree slightly on how deep we are.
	# Increase tolerance to prevent "bouncing" (snapping back and forth).
	var threshold = 2.0
	if test_character.is_on_wall():
		threshold = 20.0 # Higher tolerance when pushing walls

	if error_distance > threshold:
		print("[PREDICTION] Reconciling! Error: %.2f (Seq: %d)" % [error_distance, server_sequence])
		
		# 3. Snap to authoritative position
		test_character.position = server_position
		
		# 4. Replay remaining history
		# Remove processed entries (including the matched one, as we just corrected it)
		# Actually, we need to keep the entries AFTER the matched one to replay them.
		
		# Slice history to keep only future inputs
		# Note: slice is exclusive on end, so we want from match_index + 1 to end
		var replay_history = prediction_history.slice(match_index + 1)
		prediction_history = replay_history
		
		# Replay
		for state in prediction_history:
			test_character.velocity = state.velocity
			test_character.move_and_slide()
			state.position = test_character.position
			
	else:
		# 5. Prediction was correct - discard history up to this point
		# Keep only entries AFTER the matched one
		if match_index < prediction_history.size() - 1:
			prediction_history = prediction_history.slice(match_index + 1)
		else:
			prediction_history.clear()
