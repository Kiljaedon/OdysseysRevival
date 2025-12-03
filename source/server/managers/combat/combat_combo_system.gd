extends RefCounted
## Combat Combo System - Progressive Attack Chains
## NEW SYSTEM: 3-hit combo chains with speed scaling
## PURPOSE: Track combo state, apply progressive speed bonuses
## DEPENDENCIES: CombatTiming
##
## Implements a 3-hit combo system where each successive attack in the chain
## executes faster, rewarding players for maintaining pressure. Combo resets
## if the player waits too long between attacks (COMBO_CHAIN_WINDOW).

class_name CombatComboSystem

## Import timing constants
const CombatTiming = preload("res://source/server/managers/combat/combat_timing.gd")

## ========== COMBO FIELDS ==========

static func init_combo_fields(unit: Dictionary) -> void:
	"""Initialize combo tracking fields on a unit"""
	unit["attack_combo_count"] = 0      # Current position in combo (0-2 for hits 1-3)
	unit["combo_window_timer"] = 0.0    # Time remaining to continue combo
	unit["combo_active"] = false         # Whether unit is currently in a combo chain

static func reset_combo(unit: Dictionary) -> void:
	"""Reset combo state (called when window expires or combat ends)"""
	unit["attack_combo_count"] = 0
	unit["combo_window_timer"] = 0.0
	unit["combo_active"] = false

## ========== COMBO STATE MANAGEMENT ==========

static func process_combo_window(unit: Dictionary, delta: float) -> void:
	"""Process combo window timer, reset combo if expired"""
	if unit.get("combo_window_timer", 0.0) > 0:
		unit["combo_window_timer"] -= delta

		# Check if window expired
		if unit["combo_window_timer"] <= 0:
			reset_combo(unit)

static func advance_combo(unit: Dictionary) -> int:
	"""
	Advance to next combo hit. Returns new combo count.
	Wraps back to 0 after max combo count (continuous chain).
	"""
	var current = unit.get("attack_combo_count", 0)

	# Increment combo (wraps after max)
	unit["attack_combo_count"] = (current + 1) % CombatTiming.MAX_COMBO_COUNT

	# Refresh combo window
	unit["combo_window_timer"] = CombatTiming.COMBO_CHAIN_WINDOW
	unit["combo_active"] = true

	return unit["attack_combo_count"]

static func get_combo_count(unit: Dictionary) -> int:
	"""Get current combo count (0-2 for hits 1-3)"""
	return unit.get("attack_combo_count", 0)

static func is_in_combo(unit: Dictionary) -> bool:
	"""Check if unit is currently in an active combo chain"""
	return unit.get("combo_active", false) and unit.get("combo_window_timer", 0.0) > 0

## ========== COMBO TIMING CALCULATIONS ==========

static func get_scaled_wind_up_time(unit: Dictionary) -> float:
	"""Get wind-up time with combo scaling applied"""
	var combo_count = get_combo_count(unit)
	return CombatTiming.get_wind_up_time(combo_count)

static func get_scaled_recovery_time(unit: Dictionary) -> float:
	"""Get recovery time with combo scaling applied"""
	var combo_count = get_combo_count(unit)
	return CombatTiming.get_recovery_time(combo_count)

static func get_scaled_total_duration(unit: Dictionary) -> float:
	"""Get total attack duration with combo scaling"""
	var combo_count = get_combo_count(unit)
	return CombatTiming.get_total_attack_duration(combo_count)

## ========== COMBO BONUSES ==========

static func get_combo_damage_multiplier(unit: Dictionary) -> float:
	"""
	Get damage multiplier based on combo position.
	Currently 1.0 for all hits (balanced), but can be tuned.
	Example: Could make 3rd hit deal 1.2x damage for "finisher" feel.
	"""
	var combo_count = get_combo_count(unit)

	# For now, no damage bonus (speed is the reward)
	# Can be tuned later: [1.0, 1.05, 1.15] for escalating damage
	return 1.0

static func should_break_combo(unit: Dictionary, interruption_type: String) -> bool:
	"""
	Check if an interruption should break the combo chain.
	interruption_type: "hit", "dodge", "stun", "death", etc.
	"""
	match interruption_type:
		"death":
			return true  # Death always breaks combo
		"stun":
			return true  # Stun breaks combo
		"hit":
			return false  # Taking damage doesn't break combo (risky aggression!)
		"dodge":
			return false  # Dodge roll doesn't break combo (tactical option)
		_:
			return false

## ========== COMBO VISUALIZATION DATA ==========

static func get_combo_display_info(unit: Dictionary) -> Dictionary:
	"""
	Get info for client-side combo counter display.
	Returns: {combo_count, max_combo, progress, time_remaining}
	"""
	var combo_count = get_combo_count(unit)
	var window_timer = unit.get("combo_window_timer", 0.0)

	return {
		"combo_count": combo_count,
		"max_combo": CombatTiming.MAX_COMBO_COUNT,
		"progress": float(combo_count) / float(CombatTiming.MAX_COMBO_COUNT),
		"time_remaining": window_timer,
		"window_duration": CombatTiming.COMBO_CHAIN_WINDOW,
		"active": is_in_combo(unit)
	}

## ========== DEBUG UTILITIES ==========

static func get_combo_state_summary(unit: Dictionary) -> String:
	"""Get human-readable combo state for debugging"""
	var combo_count = get_combo_count(unit)
	var window = unit.get("combo_window_timer", 0.0)
	var active = is_in_combo(unit)

	if not active:
		return "No combo"

	return "Combo: %d/%d (%.1fs remaining)" % [
		combo_count + 1,  # Display as 1-3 instead of 0-2
		CombatTiming.MAX_COMBO_COUNT,
		window
	]

static func print_combo_timings() -> void:
	"""Print combo timing breakdown for balancing"""
	print("=== Combo Timing Breakdown ===")
	for i in range(CombatTiming.MAX_COMBO_COUNT):
		var hit_num = i + 1
		var wind_up = CombatTiming.get_wind_up_time(i)
		var recovery = CombatTiming.get_recovery_time(i)
		var total = CombatTiming.get_total_attack_duration(i)
		print("Hit %d: wind-up=%.3fs, recovery=%.3fs, total=%.3fs" % [hit_num, wind_up, recovery, total])

## ========== COMBO RESET CONDITIONS ==========

static func check_combo_reset_conditions(unit: Dictionary, event: String) -> void:
	"""
	Check if a game event should reset the combo.
	Called by combat manager when events occur.
	"""
	if should_break_combo(unit, event):
		reset_combo(unit)
