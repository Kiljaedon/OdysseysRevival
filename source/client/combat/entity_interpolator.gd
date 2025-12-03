extends RefCounted
## Entity Interpolator - Smooth Network Movement
## PURPOSE: Eliminate snapping by interpolating between server snapshots
## DEPENDENCIES: None (standalone system)
##
## Based on Source Engine interpolation model (Valve's authoritative guide):
## - Render 100ms in the past
## - Buffer recent snapshots
## - Interpolate position between frames
## - Extrapolate briefly during packet loss

class_name EntityInterpolator

## ========== CONFIGURATION ==========

## Interpolation delay - how far behind server we render (Source Engine: 100ms)
const INTERPOLATION_DELAY: float = 0.1  # 100ms delay for smooth interpolation

## Maximum states to buffer (prevent memory growth)
const MAX_BUFFER_SIZE: int = 10

## Extrapolation limit - max time to predict forward during packet loss
const EXTRAPOLATION_LIMIT: float = 0.05  # 50ms max extrapolation

## ========== STATE ==========

## Buffered server snapshots: [{timestamp, position, velocity, hp, state, facing}]
var state_buffer: Array = []

## Last interpolated timestamp (for debugging)
var last_render_timestamp: float = 0.0

## ========== PUBLIC API ==========

func add_state(state: Dictionary) -> void:
	"""
	Add a new server state snapshot to the buffer.
	Called when server sends a state update.
	"""
	var server_timestamp = state.get("server_timestamp", Time.get_ticks_msec())

	state_buffer.append({
		"timestamp": server_timestamp,
		"position": state.get("position", Vector2.ZERO),
		"velocity": state.get("velocity", Vector2.ZERO),
		"hp": state.get("hp", 100),
		"state": state.get("state", "idle"),
		"facing": state.get("facing", "down"),
		"attack_state": state.get("attack_state", "")
	})

	# Trim buffer if too large
	if state_buffer.size() > MAX_BUFFER_SIZE:
		state_buffer.pop_front()

func get_interpolated_state(current_time: float) -> Dictionary:
	"""
	Get interpolated state at render time (current_time - delay).
	Called every frame to get smooth position.

	Returns: {position, hp, state, facing, attack_state}
	"""
	# Need at least 2 states to interpolate
	if state_buffer.size() < 2:
		return state_buffer.back() if state_buffer.size() == 1 else {}

	# Render timestamp = current time - interpolation delay
	var render_time = current_time - (INTERPOLATION_DELAY * 1000.0)
	last_render_timestamp = render_time

	# Find two states that bracket the render time
	var from_state = null
	var to_state = null

	for i in range(state_buffer.size() - 1):
		var state_a = state_buffer[i]
		var state_b = state_buffer[i + 1]

		if state_a.timestamp <= render_time and state_b.timestamp >= render_time:
			from_state = state_a
			to_state = state_b
			break

	# No bracket found - use most recent state (or extrapolate)
	if not from_state or not to_state:
		return _handle_no_bracket(render_time)

	# Interpolate between states
	var time_range = to_state.timestamp - from_state.timestamp
	if time_range == 0:
		return to_state

	var alpha = float(render_time - from_state.timestamp) / float(time_range)
	alpha = clamp(alpha, 0.0, 1.0)

	return {
		"position": from_state.position.lerp(to_state.position, alpha),
		"hp": to_state.hp,  # Don't interpolate HP (instant updates)
		"state": to_state.state,  # Don't interpolate state
		"facing": to_state.facing,  # Don't interpolate facing
		"attack_state": to_state.attack_state
	}

func _handle_no_bracket(render_time: float) -> Dictionary:
	"""
	Handle case where render time isn't bracketed by two states.
	Either too far behind (use oldest) or too far ahead (extrapolate).
	"""
	# If buffer empty, return empty
	if state_buffer.is_empty():
		return {}

	var latest = state_buffer.back()

	# If render time is after latest snapshot, extrapolate
	var time_ahead = render_time - latest.timestamp
	if time_ahead > 0:
		return _extrapolate(latest, time_ahead)

	# Otherwise use oldest or latest
	return latest

func _extrapolate(base_state: Dictionary, time_ahead: float) -> Dictionary:
	"""
	Extrapolate position forward during packet loss.
	Only extrapolate up to EXTRAPOLATION_LIMIT to prevent wild predictions.
	"""
	if time_ahead > EXTRAPOLATION_LIMIT * 1000.0:
		# Too far ahead - just use base state (stop extrapolating)
		return base_state

	# Predict position based on velocity
	var extrapolated_position = base_state.position + base_state.velocity * (time_ahead / 1000.0)

	return {
		"position": extrapolated_position,
		"hp": base_state.hp,
		"state": base_state.state,
		"facing": base_state.facing,
		"attack_state": base_state.attack_state
	}

func cleanup_old_states(current_time: float) -> void:
	"""
	Remove states older than 1 second to prevent memory growth.
	Called every frame.
	"""
	var cutoff_time = current_time - 1000.0  # 1 second ago

	# Keep at least 2 states for interpolation
	while state_buffer.size() > 2:
		if state_buffer[0].timestamp < cutoff_time:
			state_buffer.pop_front()
		else:
			break

func clear() -> void:
	"""Clear all buffered states (e.g., on unit death, battle end)"""
	state_buffer.clear()
	last_render_timestamp = 0.0

func get_buffer_size() -> int:
	"""Get number of buffered states (for debugging)"""
	return state_buffer.size()

func get_interpolation_delay_ms() -> float:
	"""Get interpolation delay in milliseconds"""
	return INTERPOLATION_DELAY * 1000.0

## ========== DEBUG / INFO ==========

func get_buffer_info() -> Dictionary:
	"""Get buffer state for debugging/UI"""
	if state_buffer.is_empty():
		return {
			"buffer_size": 0,
			"oldest_timestamp": 0.0,
			"newest_timestamp": 0.0,
			"time_span_ms": 0.0,
			"last_render_timestamp": last_render_timestamp
		}

	var oldest = state_buffer.front().timestamp
	var newest = state_buffer.back().timestamp

	return {
		"buffer_size": state_buffer.size(),
		"oldest_timestamp": oldest,
		"newest_timestamp": newest,
		"time_span_ms": newest - oldest,
		"last_render_timestamp": last_render_timestamp,
		"interpolation_delay_ms": INTERPOLATION_DELAY * 1000.0
	}

func print_buffer_state() -> void:
	"""Print buffer contents for debugging"""
	if state_buffer.is_empty():
		print("[EntityInterpolator] Buffer empty")
		return

	var info = get_buffer_info()
	print("[EntityInterpolator] Buffer: %d states, span=%.1fms" % [
		info.buffer_size,
		info.time_span_ms
	])

	for i in range(min(3, state_buffer.size())):
		var state = state_buffer[i]
		print("  [%d] t=%.1f pos=%s vel=%s" % [
			i,
			state.timestamp,
			state.position,
			state.velocity
		])

## ========== ADVANCED FEATURES ==========

func get_velocity_estimate() -> Vector2:
	"""
	Estimate current velocity from recent state changes.
	Useful for smooth animation blending.
	"""
	if state_buffer.size() < 2:
		return Vector2.ZERO

	var latest = state_buffer.back()
	var previous = state_buffer[state_buffer.size() - 2]

	var time_delta = (latest.timestamp - previous.timestamp) / 1000.0
	if time_delta <= 0:
		return Vector2.ZERO

	var position_delta = latest.position - previous.position
	return position_delta / time_delta

func is_behind_schedule(current_time: float, threshold_ms: float = 50.0) -> bool:
	"""
	Check if interpolator is falling behind (too few states).
	Useful for detecting network issues.
	"""
	if state_buffer.is_empty():
		return true

	var latest = state_buffer.back()
	var time_since_latest = current_time - latest.timestamp

	return time_since_latest > threshold_ms

func is_extrapolating(current_time: float) -> bool:
	"""Check if currently extrapolating (beyond latest snapshot)"""
	if state_buffer.is_empty():
		return false

	var render_time = current_time - (INTERPOLATION_DELAY * 1000.0)
	var latest = state_buffer.back()

	return render_time > latest.timestamp

func get_interpolation_alpha() -> float:
	"""
	Get current interpolation alpha (0.0-1.0) for debug visualization.
	Returns -1 if not interpolating.
	"""
	if state_buffer.size() < 2:
		return -1.0

	var current_time = Time.get_ticks_msec()
	var render_time = current_time - (INTERPOLATION_DELAY * 1000.0)

	for i in range(state_buffer.size() - 1):
		var state_a = state_buffer[i]
		var state_b = state_buffer[i + 1]

		if state_a.timestamp <= render_time and state_b.timestamp >= render_time:
			var time_range = state_b.timestamp - state_a.timestamp
			if time_range == 0:
				return 1.0
			return float(render_time - state_a.timestamp) / float(time_range)

	return -1.0

func set_interpolation_delay(delay_seconds: float) -> void:
	"""
	Dynamically adjust interpolation delay (for network condition adaptation).
	Not recommended - use the default 100ms unless you have specific needs.
	"""
	# Note: This would require making INTERPOLATION_DELAY non-const
	push_warning("[EntityInterpolator] Delay adjustment not supported (const INTERPOLATION_DELAY)")

## ========== STATISTICS ==========

var _stats: Dictionary = {
	"total_states_added": 0,
	"total_interpolations": 0,
	"total_extrapolations": 0,
	"total_cleanups": 0
}

func _update_stats_state_added() -> void:
	_stats.total_states_added += 1

func _update_stats_interpolation() -> void:
	_stats.total_interpolations += 1

func _update_stats_extrapolation() -> void:
	_stats.total_extrapolations += 1

func get_stats() -> Dictionary:
	"""Get interpolation statistics"""
	return _stats.duplicate()

func reset_stats() -> void:
	"""Reset statistics (for testing/benchmarking)"""
	_stats = {
		"total_states_added": 0,
		"total_interpolations": 0,
		"total_extrapolations": 0,
		"total_cleanups": 0
	}

func print_stats() -> void:
	"""Print statistics for debugging"""
	print("=== Entity Interpolator Statistics ===")
	print("States added: %d" % _stats.total_states_added)
	print("Interpolations: %d" % _stats.total_interpolations)
	print("Extrapolations: %d" % _stats.total_extrapolations)
	print("Buffer cleanups: %d" % _stats.total_cleanups)
	print("Current buffer size: %d/%d" % [get_buffer_size(), MAX_BUFFER_SIZE])
