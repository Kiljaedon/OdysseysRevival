class_name InputProcessor
extends Node
## Server-side input processing
## Processes client inputs and calculates authoritative positions
## Prevents position hacking by not trusting client positions

# Movement settings
var movement_speed: float = 200.0
var diagonal_speed_multiplier: float = 0.707  # sqrt(2)/2 for normalized diagonal

# Map boundaries (set by server_world)
var map_width: float = 0
var map_height: float = 0

## ========== INPUT PROCESSING ==========

func process_input(current_position: Vector2, input: Dictionary, delta: float) -> Dictionary:
	"""Process client input and calculate new position
	Returns: {position: Vector2, velocity: Vector2, direction: String}"""

	var velocity = Vector2.ZERO
	var direction = "down"  # Default direction

	# Calculate velocity from input
	if input.get("up", false):
		velocity.y -= 1
		direction = "up"
	if input.get("down", false):
		velocity.y += 1
		direction = "down"
	if input.get("left", false):
		velocity.x -= 1
		direction = "left"
	if input.get("right", false):
		velocity.x += 1
		direction = "right"

	# Normalize diagonal movement
	if velocity.length() > 0:
		velocity = velocity.normalized() * movement_speed

	# Calculate new position
	var new_position = current_position + velocity * delta

	# Clamp to map boundaries
	if map_width > 0 and map_height > 0:
		new_position.x = clamp(new_position.x, 0, map_width)
		new_position.y = clamp(new_position.y, 0, map_height)

	return {
		"position": new_position,
		"velocity": velocity,
		"direction": direction
	}


func validate_input(input: Dictionary) -> bool:
	"""Validate input structure to prevent exploits"""

	# Check required keys exist
	if not input.has("timestamp"):
		return false

	# Validate timestamp is reasonable (not too old, not in future)
	var timestamp = input.get("timestamp", 0)
	var current_time = Time.get_ticks_msec()
	var time_diff = abs(current_time - timestamp)

	# Reject inputs with excessive time drift (60 seconds for development, reduce in production)
	# This accounts for network latency, clock drift, and client/server time desync
	if time_diff > 60000:
		return false

	# Validate input types are boolean
	for key in ["up", "down", "left", "right"]:
		if input.has(key) and typeof(input[key]) != TYPE_BOOL:
			return false

	return true


func get_direction_from_velocity(velocity: Vector2) -> String:
	"""Get cardinal direction from velocity vector"""
	if velocity.length() < 0.1:
		return "down"  # Idle, return default

	# Determine primary direction
	if abs(velocity.x) > abs(velocity.y):
		return "right" if velocity.x > 0 else "left"
	else:
		return "down" if velocity.y > 0 else "up"
