extends RefCounted
## Combat Dodge System - Dodge Roll Mechanics
## EXTRACTED FROM: combat_rules.gd (lines 243-247, 397-486)
## PURPOSE: Dodge roll state, i-frames, cooldown management
## DEPENDENCIES: CombatTiming
##
## Manages the dodge roll mechanic - a quick evasive dash with invincibility frames.
## Used for tactical repositioning and avoiding damage.

class_name CombatDodgeSystem

const CombatTiming = preload("res://source/server/managers/combat/combat_timing.gd")

## ========== DODGE FIELDS INITIALIZATION ==========

static func init_dodge_fields(unit: Dictionary) -> void:
	"""Initialize dodge roll fields on a unit"""
	unit["is_dodge_rolling"] = false
	unit["dodge_roll_timer"] = 0.0
	unit["dodge_roll_direction"] = Vector2.ZERO
	unit["dodge_roll_cooldown"] = 0.0

## ========== DODGE STATE CHECKS ==========

static func can_dodge_roll(unit: Dictionary, _battle: Dictionary = {}) -> Dictionary:
	"""
	Check if unit can start a dodge roll.
	Returns: {allowed: bool, reason: String}
	"""
	# Dead?
	if unit.get("state", "") == "dead":
		return {"allowed": false, "reason": "dead"}

	# Already dodge rolling?
	if unit.get("is_dodge_rolling", false):
		return {"allowed": false, "reason": "already_dodging"}

	# On cooldown?
	if unit.get("dodge_roll_cooldown", 0.0) > 0:
		return {"allowed": false, "reason": "on_cooldown"}

	# Check energy cost
	var energy = unit.get("energy", 0)
	if energy < CombatTiming.DODGE_ROLL_ENERGY_COST:
		return {"allowed": false, "reason": "insufficient_energy"}

	return {"allowed": true, "reason": ""}

static func is_dodge_rolling(unit: Dictionary) -> bool:
	"""Check if unit is currently performing a dodge roll"""
	return unit.get("is_dodge_rolling", false)

static func get_dodge_cooldown_remaining(unit: Dictionary) -> float:
	"""Get remaining cooldown time in seconds"""
	return unit.get("dodge_roll_cooldown", 0.0)

static func is_dodge_on_cooldown(unit: Dictionary) -> bool:
	"""Check if dodge roll is on cooldown"""
	return unit.get("dodge_roll_cooldown", 0.0) > 0

## ========== DODGE EXECUTION ==========

static func start_dodge_roll(unit: Dictionary, direction: Vector2) -> void:
	"""
	Begin a dodge roll - dashes in the specified direction with i-frames.
	Direction should be normalized.
	"""
	# Cancel any active attack if we are rolling
	if unit.get("attack_state", "") != "":
		_cancel_attack_for_dodge(unit)

	# Normalize direction (just in case)
	var roll_direction = direction.normalized()
	if roll_direction.length() < 0.1:
		# Fallback: roll backward based on facing
		roll_direction = _get_fallback_dodge_direction(unit)

	# Set dodge roll state
	unit["is_dodge_rolling"] = true
	unit["dodge_roll_timer"] = CombatTiming.DODGE_ROLL_DURATION
	unit["dodge_roll_direction"] = roll_direction
	unit["dodge_roll_cooldown"] = CombatTiming.DODGE_ROLL_COOLDOWN

	# Consume energy
	unit["energy"] = unit.get("energy", 100) - CombatTiming.DODGE_ROLL_ENERGY_COST

	# Grant invincibility for most of the roll
	unit["invincibility_timer"] = CombatTiming.DODGE_ROLL_IFRAMES

	# Set state for animation
	unit["state"] = "dodge_rolling"

static func _cancel_attack_for_dodge(unit: Dictionary) -> void:
	"""Cancel active attack when dodge rolling (internal helper)"""
	unit["attack_state"] = ""
	unit["attack_state_timer"] = 0.0
	unit["attack_target_id"] = ""
	unit["lunge_velocity"] = Vector2.ZERO

static func _get_fallback_dodge_direction(unit: Dictionary) -> Vector2:
	"""Get fallback dodge direction based on facing (internal helper)"""
	var facing = unit.get("facing", "down")
	match facing:
		"up": return Vector2.DOWN      # Roll backward
		"down": return Vector2.UP
		"left": return Vector2.RIGHT
		"right": return Vector2.LEFT
		_: return Vector2.DOWN

## ========== DODGE PROCESSING ==========

static func process_dodge_roll(unit: Dictionary, delta: float) -> Vector2:
	"""
	Process dodge roll movement. Returns velocity vector to apply.
	Called every frame during active dodge roll.
	"""
	if not unit.get("is_dodge_rolling", false):
		return Vector2.ZERO

	# Update timer
	unit["dodge_roll_timer"] = unit.get("dodge_roll_timer", 0.0) - delta

	# Check if roll complete
	if unit["dodge_roll_timer"] <= 0:
		_end_dodge_roll(unit)
		return Vector2.ZERO

	# Calculate roll velocity (constant speed throughout roll)
	var roll_speed = CombatTiming.get_dodge_roll_speed()
	return unit.get("dodge_roll_direction", Vector2.ZERO) * roll_speed

static func _end_dodge_roll(unit: Dictionary) -> void:
	"""End dodge roll and reset state (internal helper)"""
	unit["is_dodge_rolling"] = false
	unit["dodge_roll_direction"] = Vector2.ZERO
	unit["state"] = "idle"

static func process_dodge_cooldown(unit: Dictionary, delta: float) -> void:
	"""Update dodge roll cooldown timer"""
	if unit.get("dodge_roll_cooldown", 0.0) > 0:
		unit["dodge_roll_cooldown"] = unit.get("dodge_roll_cooldown", 0.0) - delta

## ========== DODGE INFORMATION ==========

static func get_dodge_info(unit: Dictionary) -> Dictionary:
	"""
	Get dodge roll information for UI/debugging.
	Returns: {is_rolling, cooldown_remaining, can_dodge, energy_cost}
	"""
	var can_dodge_result = can_dodge_roll(unit)

	return {
		"is_rolling": is_dodge_rolling(unit),
		"cooldown_remaining": get_dodge_cooldown_remaining(unit),
		"can_dodge": can_dodge_result.allowed,
		"block_reason": can_dodge_result.reason,
		"energy_cost": CombatTiming.DODGE_ROLL_ENERGY_COST,
		"duration": CombatTiming.DODGE_ROLL_DURATION,
		"distance": CombatTiming.DODGE_ROLL_DISTANCE,
		"iframe_duration": CombatTiming.DODGE_ROLL_IFRAMES
	}

static func get_dodge_progress(unit: Dictionary) -> float:
	"""Get 0.0-1.0 progress through current dodge roll"""
	if not is_dodge_rolling(unit):
		return 0.0

	var elapsed = CombatTiming.DODGE_ROLL_DURATION - unit.get("dodge_roll_timer", 0.0)
	return clamp(elapsed / CombatTiming.DODGE_ROLL_DURATION, 0.0, 1.0)

## ========== DEBUG UTILITIES ==========

static func get_dodge_state_summary(unit: Dictionary) -> String:
	"""Get human-readable dodge state for debugging"""
	if is_dodge_rolling(unit):
		var remaining = unit.get("dodge_roll_timer", 0.0)
		return "Dodge rolling (%.2fs remaining)" % remaining

	var cooldown = get_dodge_cooldown_remaining(unit)
	if cooldown > 0:
		return "Dodge on cooldown (%.2fs)" % cooldown

	var can_dodge_result = can_dodge_roll(unit)
	if can_dodge_result.allowed:
		return "Dodge ready"
	else:
		return "Dodge blocked: %s" % can_dodge_result.reason
