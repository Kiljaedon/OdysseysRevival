class_name MovementValidator
extends Node
## Movement validation system
## Detects impossible movements, speed hacks, and teleports

# Validation settings
var max_speed: float = 250.0  # Slightly higher than normal movement for lag tolerance
var max_distance_per_tick: float = 15.0  # Maximum pixels per server tick (0.05s)
var teleport_distance_threshold: float = 100.0  # Instant jumps larger than this are flagged

# Collision checking
var collision_enabled: bool = true
var collision_world: Node2D = null  # Reference to server's collision world

## ========== MOVEMENT VALIDATION ==========

func validate_movement(old_pos: Vector2, new_pos: Vector2, delta: float) -> Dictionary:
	"""Validate if movement is physically possible
	Returns: {valid: bool, reason: String, severity: int}"""

	var distance = old_pos.distance_to(new_pos)
	var max_allowed = max_speed * delta * 1.1  # 10% tolerance for network lag

	# Check for teleporting
	if distance > teleport_distance_threshold:
		return {
			"valid": false,
			"reason": "teleport",
			"severity": 3,  # Critical
			"distance": distance
		}

	# Check for speed hacking
	if distance > max_allowed:
		return {
			"valid": false,
			"reason": "speed_hack",
			"severity": 2,  # High
			"distance": distance,
			"max_allowed": max_allowed
		}

	# Check for collision (wall-hacking)
	if collision_enabled and collision_world:
		if is_path_blocked(old_pos, new_pos):
			return {
				"valid": false,
				"reason": "collision_detected",
				"severity": 10,  # Critical - wall hacking attempt
				"old_pos": old_pos,
				"new_pos": new_pos
			}

	return {
		"valid": true,
		"reason": "",
		"severity": 0
	}


func validate_position_in_bounds(position: Vector2, map_width: float, map_height: float) -> bool:
	"""Check if position is within map boundaries"""
	if map_width <= 0 or map_height <= 0:
		return true  # No bounds set

	return (
		position.x >= 0 and position.x <= map_width and
		position.y >= 0 and position.y <= map_height
	)


func calculate_speed(old_pos: Vector2, new_pos: Vector2, delta: float) -> float:
	"""Calculate movement speed in pixels per second"""
	if delta <= 0:
		return 0.0

	var distance = old_pos.distance_to(new_pos)
	return distance / delta


func is_suspicious_movement(positions: Array) -> Dictionary:
	"""Analyze movement history for bot-like patterns
	Returns: {suspicious: bool, reason: String, confidence: float}"""

	if positions.size() < 10:
		return {"suspicious": false, "reason": "", "confidence": 0.0}

	# Check for perfectly straight movement (bots often move in straight lines)
	var is_too_straight = check_movement_linearity(positions)
	if is_too_straight:
		return {
			"suspicious": true,
			"reason": "bot_like_movement",
			"confidence": 0.7
		}

	# Check for impossible precision (exact pixel movements)
	var is_too_precise = check_movement_precision(positions)
	if is_too_precise:
		return {
			"suspicious": true,
			"reason": "bot_precision",
			"confidence": 0.8
		}

	return {"suspicious": false, "reason": "", "confidence": 0.0}


func check_movement_linearity(positions: Array) -> bool:
	"""Check if movement is suspiciously linear (bot-like)"""
	if positions.size() < 5:
		return false

	# Calculate average deviation from straight line
	var start = positions[0]
	var end = positions[positions.size() - 1]
	var total_deviation = 0.0

	for i in range(1, positions.size() - 1):
		var point = positions[i]
		var deviation = distance_to_line(point, start, end)
		total_deviation += deviation

	var avg_deviation = total_deviation / (positions.size() - 2)

	# Human players rarely move in perfect straight lines
	return avg_deviation < 5.0  # Less than 5 pixels average deviation


func check_movement_precision(positions: Array) -> bool:
	"""Check if movements are suspiciously precise (bot-like)"""
	if positions.size() < 5:
		return false

	var precise_movements = 0

	for i in range(1, positions.size()):
		var delta = positions[i] - positions[i - 1]

		# Check if movement is exactly horizontal or vertical
		if abs(delta.x) < 0.1 or abs(delta.y) < 0.1:
			precise_movements += 1

	# Bots often move in perfect cardinal directions
	var precision_ratio = float(precise_movements) / positions.size()
	return precision_ratio > 0.9  # More than 90% precise movements


func distance_to_line(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	"""Calculate perpendicular distance from point to line"""
	var line_vec = line_end - line_start
	var point_vec = point - line_start

	if line_vec.length_squared() < 0.01:
		return point_vec.length()

	var projection = point_vec.dot(line_vec) / line_vec.length_squared()
	projection = clamp(projection, 0.0, 1.0)

	var closest_point = line_start + line_vec * projection
	return point.distance_to(closest_point)


## ========== COLLISION CHECKING ==========

func is_path_blocked(from_pos: Vector2, to_pos: Vector2) -> bool:
	"""Check if movement path intersects with any collision shapes"""
	if not collision_world:
		return false

	# Use Godot's physics raycast to check collision
	var space_state = collision_world.get_world_2d().direct_space_state
	if not space_state:
		return false

	# Create raycast query
	var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collision_mask = 1  # Check layer 1 (collision objects)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	# Perform raycast
	var result = space_state.intersect_ray(query)

	# If raycast hit something, path is blocked
	return not result.is_empty()
