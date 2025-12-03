extends RefCounted
## Combat Input Buffer - Responsive Action Queuing
## PURPOSE: Queue combat actions pressed during cooldowns
## DEPENDENCIES: None (standalone system)
##
## Based on fighting game input buffering (Street Fighter, Tekken style).
## When a player presses attack 100ms before cooldown ends, instead of
## discarding the input, we buffer it and execute when ready.
##
## This eliminates the "unresponsive" feeling where button presses are lost.

class_name CombatInputBuffer

## ========== CONFIGURATION ==========

## Buffer window in seconds (fighting game standard: 0.1-0.2s)
const BUFFER_WINDOW: float = 0.15  # 150ms grace period

## Maximum buffered actions to prevent queue overflow
const MAX_BUFFER_SIZE: int = 3

## ========== STATE ==========

## Action queue: [{action: String, timestamp: float, data: Variant}]
var queue: Array = []

## ========== PUBLIC API ==========

func buffer_action(action: String, data: Variant = null) -> bool:
	"""
	Buffer an action for later execution.
	Returns true if buffered, false if rejected (duplicate or queue full).

	action: Action type ("attack", "dodge_roll", "ability_1", etc.)
	data: Action-specific data (target_id for attack, direction for dodge, etc.)
	"""
	# Check for duplicates - prevent buffering same action multiple times
	for entry in queue:
		if entry.action == action:
			return false  # Already buffered

	# Check queue capacity
	if queue.size() >= MAX_BUFFER_SIZE:
		return false  # Queue full (shouldn't happen in practice)

	# Add to queue
	queue.append({
		"action": action,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"data": data
	})

	return true

func process_queue(ready_states: Dictionary, executor: Object) -> int:
	"""
	Process buffered inputs and execute if conditions are met.

	ready_states: Dictionary of {action_name + "_ready": bool}
	  Example: {"attack_ready": true, "dodge_roll_ready": false}

	executor: Object with execute_<action>() methods
	  Example: execute_attack(target_id), execute_dodge_roll(direction)

	Returns: Number of actions executed this frame
	"""
	var current_time = Time.get_ticks_msec() / 1000.0
	var executed_count = 0
	var i = 0

	while i < queue.size():
		var entry = queue[i]
		var age = current_time - entry.timestamp

		# Expire old entries (older than buffer window)
		if age > BUFFER_WINDOW:
			queue.remove_at(i)
			continue  # Don't increment i, check same index again

		# Check if action is ready to execute
		var ready_key = entry.action + "_ready"
		var is_ready = ready_states.get(ready_key, false)

		if is_ready:
			# Execute via executor object
			var method_name = "execute_" + entry.action
			if executor.has_method(method_name):
				executor.call(method_name, entry.data)
				executed_count += 1
				queue.remove_at(i)
				continue  # Don't increment i
			else:
				# Method doesn't exist - remove invalid action
				push_error("[CombatInputBuffer] Executor missing method: %s" % method_name)
				queue.remove_at(i)
				continue

		# Not ready yet, keep in queue
		i += 1

	return executed_count

func clear() -> void:
	"""Clear all buffered actions (e.g., on death, battle end)"""
	queue.clear()

func is_buffered(action: String) -> bool:
	"""Check if an action is currently buffered"""
	for entry in queue:
		if entry.action == action:
			return true
	return false

func get_buffered_count() -> int:
	"""Get number of buffered actions"""
	return queue.size()

func get_time_until_expiry(action: String) -> float:
	"""
	Get time until a buffered action expires.
	Returns -1 if action is not buffered.
	"""
	var current_time = Time.get_ticks_msec() / 1000.0

	for entry in queue:
		if entry.action == action:
			var age = current_time - entry.timestamp
			var remaining = BUFFER_WINDOW - age
			return max(0.0, remaining)

	return -1.0

## ========== DEBUG / INFO ==========

func get_buffer_state() -> Dictionary:
	"""Get buffer state for debugging/UI"""
	return {
		"queue_size": queue.size(),
		"max_size": MAX_BUFFER_SIZE,
		"buffer_window": BUFFER_WINDOW,
		"actions": _get_action_summary()
	}

func _get_action_summary() -> Array:
	"""Get summary of buffered actions"""
	var summary = []
	var current_time = Time.get_ticks_msec() / 1000.0

	for entry in queue:
		var age = current_time - entry.timestamp
		summary.append({
			"action": entry.action,
			"age": age,
			"time_remaining": BUFFER_WINDOW - age
		})

	return summary

func print_buffer_state() -> void:
	"""Print buffer contents for debugging"""
	if queue.is_empty():
		print("[InputBuffer] Empty")
		return

	print("[InputBuffer] %d actions buffered:" % queue.size())
	var current_time = Time.get_ticks_msec() / 1000.0

	for entry in queue:
		var age = current_time - entry.timestamp
		var remaining = BUFFER_WINDOW - age
		print("  - %s (%.3fs old, %.3fs remaining)" % [entry.action, age, remaining])

## ========== ADVANCED FEATURES ==========

func get_oldest_action() -> Dictionary:
	"""Get the oldest buffered action (FIFO order)"""
	if queue.is_empty():
		return {}
	return queue.front()

func remove_action(action: String) -> bool:
	"""
	Remove a specific action from the buffer.
	Returns true if removed, false if not found.
	"""
	for i in range(queue.size()):
		if queue[i].action == action:
			queue.remove_at(i)
			return true
	return false

func has_space() -> bool:
	"""Check if buffer has space for more actions"""
	return queue.size() < MAX_BUFFER_SIZE

func get_actions_by_type(action_type: String) -> Array:
	"""Get all buffered actions of a specific type"""
	var results = []
	for entry in queue:
		if entry.action == action_type:
			results.append(entry)
	return results

## ========== PRIORITY SYSTEM (OPTIONAL) ==========

func buffer_action_with_priority(action: String, priority: int, data: Variant = null) -> bool:
	"""
	Buffer action with priority level.
	Higher priority actions execute first if multiple are ready.

	Priority levels:
	  0 = Normal (attack, dodge)
	  1 = High (abilities, special moves)
	  2 = Critical (emergency actions like parry)
	"""
	# Check for duplicates
	for entry in queue:
		if entry.action == action:
			return false

	# Check capacity
	if queue.size() >= MAX_BUFFER_SIZE:
		return false

	# Add with priority
	queue.append({
		"action": action,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"data": data,
		"priority": priority
	})

	# Sort by priority (higher first), then by timestamp (older first)
	queue.sort_custom(func(a, b):
		var a_priority = a.get("priority", 0)
		var b_priority = b.get("priority", 0)
		if a_priority != b_priority:
			return a_priority > b_priority  # Higher priority first
		return a.timestamp < b.timestamp  # Older first
	)

	return true

## ========== STATISTICS ==========

var _stats: Dictionary = {
	"total_buffered": 0,
	"total_executed": 0,
	"total_expired": 0,
	"total_rejected": 0
}

func _update_stats_buffered() -> void:
	_stats.total_buffered += 1

func _update_stats_executed() -> void:
	_stats.total_executed += 1

func _update_stats_expired() -> void:
	_stats.total_expired += 1

func _update_stats_rejected() -> void:
	_stats.total_rejected += 1

func get_stats() -> Dictionary:
	"""Get buffering statistics"""
	var total = _stats.total_buffered
	var success_rate = 0.0
	if total > 0:
		success_rate = float(_stats.total_executed) / float(total) * 100.0

	return {
		"total_buffered": _stats.total_buffered,
		"total_executed": _stats.total_executed,
		"total_expired": _stats.total_expired,
		"total_rejected": _stats.total_rejected,
		"success_rate": success_rate,
		"current_queue_size": queue.size()
	}

func reset_stats() -> void:
	"""Reset statistics (for testing/benchmarking)"""
	_stats = {
		"total_buffered": 0,
		"total_executed": 0,
		"total_expired": 0,
		"total_rejected": 0
	}

func print_stats() -> void:
	"""Print statistics for debugging"""
	var stats = get_stats()
	print("=== Input Buffer Statistics ===")
	print("Total buffered: %d" % stats.total_buffered)
	print("Total executed: %d (%.1f%%)" % [stats.total_executed, stats.success_rate])
	print("Total expired: %d" % stats.total_expired)
	print("Total rejected: %d" % stats.total_rejected)
	print("Current queue: %d/%d" % [stats.current_queue_size, MAX_BUFFER_SIZE])
