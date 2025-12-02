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

	handle_movement()

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
		print("[INPUT] SPACEBAR DETECTED! Checking attack conditions...")
		print("[INPUT] - is_attacking: ", is_attacking)
		print("[INPUT] - weapon_state exists: ", weapon_state != null)
		if weapon_state:
			print("[INPUT] - weapon_state.has_method('can_attack'): ", weapon_state.has_method("can_attack"))
			if weapon_state.has_method("can_attack"):
				print("[INPUT] - weapon_state.can_attack(): ", weapon_state.can_attack())

		# Check weapon state - can only attack if weapon is unsheathed
		if not is_attacking and weapon_state and weapon_state.has_method("can_attack") and weapon_state.can_attack():
			print("[INPUT] ✓ ALL CONDITIONS MET - Calling test_attack_animation()")
			test_attack_animation()
		elif weapon_state and weapon_state.has_method("can_attack") and not weapon_state.can_attack():
			print("[ATTACK BLOCKED] Weapon is SHEATHED! Press TAB to unsheath and enable combat.")
		else:
			print("[INPUT] ✗ ATTACK FAILED - Conditions not met")

	# Only allow movement if not attacking
	if not is_attacking:
		# Handle input
		if Input.is_action_pressed("up"):
			velocity.y -= movement_speed
			current_direction = "up"
			moving = true
		elif Input.is_action_pressed("down"):
			velocity.y += movement_speed
			current_direction = "down"
			moving = true

		if Input.is_action_pressed("left"):
			velocity.x -= movement_speed
			current_direction = "left"
			moving = true
		elif Input.is_action_pressed("right"):
			velocity.x += movement_speed
			current_direction = "right"
			moving = true

		# Update animation based on movement (only if not attacking)
		if moving:
			play_walk_animation()
		else:
			play_idle_animation()
	else:
		# During attack, stop all movement
		velocity = Vector2.ZERO

	# Apply velocity to character
	if test_character:
		test_character.velocity = velocity

	# Check for map transitions when moving
	if moving and map_manager and transition_cooldown <= 0:
		check_map_transition()

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
