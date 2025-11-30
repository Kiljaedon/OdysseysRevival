class_name AnimationControlManager
extends Node

## Manages character animation playback and attack system.
## Responsible for controlling walk/idle/attack animation states and hitbox management.
##
## Features:
## - Walk and idle animation control with direction support
## - Attack animation with timing and hitbox coordination
## - Frame display tracking for UI feedback
## - Attack hitbox positioning based on facing direction
##
## Dependencies:
## - AnimatedSprite2D node for sprite animation
## - Area2D attack_hitbox with CollisionShape2D for melee detection
## - Character animation data in SpriteFrames format
##
## Signals:
## - attack_started: Emitted when attack begins
## - attack_finished: Emitted when attack animation completes
##
## Usage:
## var anim_mgr = AnimationControlManager.new()
## anim_mgr.initialize(animated_sprite, attack_hitbox, attack_hitbox_shape)
## anim_mgr.play_walk_animation("down")

signal attack_started
signal attack_finished

@export var attack_duration: float = 0.5

var animated_sprite: AnimatedSprite2D
var attack_hitbox: Area2D
var attack_hitbox_shape: CollisionShape2D
var current_direction: String = "down"
var attack_direction: String = "down"
var is_attacking: bool = false
var attack_timer: float = 0.0

func initialize(sprite: AnimatedSprite2D, hitbox: Area2D, hitbox_shape: CollisionShape2D) -> void:
	"""Initialize animation manager with required node references."""
	animated_sprite = sprite
	attack_hitbox = hitbox
	attack_hitbox_shape = hitbox_shape
	print("[AnimationControlManager] Initialized")

func play_walk_animation() -> void:
	"""Play walking animation in current direction."""
	var anim_name = "walk_" + current_direction
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		# Only start animation if not already playing this animation
		if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
			animated_sprite.play(anim_name)
		update_frame_display()

func play_idle_animation() -> void:
	"""Play idle animation (paused walk on first frame)."""
	# For idle, pause the walk animation on first frame
	var anim_name = "walk_" + current_direction
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
		animated_sprite.pause()  # Pause on current frame for idle
		animated_sprite.frame = 0  # Reset to first frame
		update_frame_display()

func test_attack_animation() -> void:
	"""Play attack animation in current direction with hitbox coordination."""
	print("[ATTACK] test_attack_animation() called")
	# Store the direction when attack starts to maintain facing after attack
	attack_direction = current_direction
	var anim_name = "attack_" + attack_direction
	print("[ATTACK] Playing animation: ", anim_name)

	# Safety check: Verify sprite_frames exists
	if not animated_sprite.sprite_frames:
		print("[ATTACK] ERROR: No sprite_frames loaded!")
		return

	# Safety check: Verify animation exists
	if not animated_sprite.sprite_frames.has_animation(anim_name):
		print("[ATTACK] ERROR: Animation not found: ", anim_name)
		return

	# Safety check: Verify animation has at least one frame
	var frame_count = animated_sprite.sprite_frames.get_frame_count(anim_name)
	print("[ATTACK] Animation frame count: ", frame_count)
	if frame_count == 0:
		print("[ATTACK] ERROR: Animation has no frames: ", anim_name)
		return

	# All checks passed - safe to play animation
	print("[ATTACK] All checks passed - playing animation")
	animated_sprite.play(anim_name)

	# Set a timer to return to walk animation after attack
	is_attacking = true
	attack_timer = attack_duration

	# Enable attack hitbox and position it in front of player
	print("[ATTACK] Enabling attack hitbox...")
	enable_attack_hitbox()
	print("[ATTACK] Attack hitbox enabled")

	# Connect to animation finished signal if not already connected
	if not animated_sprite.animation_finished.is_connected(_on_attack_animation_finished):
		animated_sprite.animation_finished.connect(_on_attack_animation_finished)

	update_frame_display()
	print("[ATTACK] test_attack_animation() completed")
	attack_started.emit()

func enable_attack_hitbox() -> void:
	"""Enable attack hitbox in the direction player is facing."""
	# Position hitbox based on attack direction (close range melee attack)
	var hitbox_offset = 40.0  # Distance in front of character (reduced for better melee range)
	match current_direction:
		"up":
			attack_hitbox.position = Vector2(0, -hitbox_offset)
		"down":
			attack_hitbox.position = Vector2(0, hitbox_offset)
		"left":
			attack_hitbox.position = Vector2(-hitbox_offset, 0)
		"right":
			attack_hitbox.position = Vector2(hitbox_offset, 0)

	print("Attack hitbox enabled at offset: ", attack_hitbox.position, " direction: ", current_direction)

	# Enable the hitbox
	attack_hitbox_shape.disabled = false

	# Wait for physics frames (collision detection happens in physics, not idle!)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Disable hitbox after brief delay (only if still in tree)
	if is_inside_tree():
		await get_tree().create_timer(0.2).timeout
		if is_inside_tree() and attack_hitbox_shape:
			attack_hitbox_shape.disabled = true

func update_frame_display() -> void:
	"""Update frame counter display for current animation."""
	if animated_sprite.sprite_frames and animated_sprite.animation:
		var frame_count = animated_sprite.sprite_frames.get_frame_count(animated_sprite.animation)
		var current_frame = animated_sprite.frame + 1
		print("Frame: %d/%d - %s" % [current_frame, frame_count, animated_sprite.animation])

func update_attack_timer(delta: float) -> bool:
	"""Update attack timer, return true if attack is still active."""
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			attack_finished.emit()
			return false
	return is_attacking

func _on_attack_animation_finished() -> void:
	"""Called when attack animation finishes playing."""
	print("[ATTACK] Animation finished")
	attack_finished.emit()
