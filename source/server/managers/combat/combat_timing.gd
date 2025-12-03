extends RefCounted
## Combat Timing - Centralized Timing Configuration
## EXTRACTED FROM: combat_rules.gd (lines 10-58)
## PURPOSE: Centralized timing constants and calculations
## DEPENDENCIES: None (pure data + static functions)
##
## This file contains all combat timing values to avoid scattering them
## across multiple files. Extracted to reduce combat_rules.gd bloat.

class_name CombatTiming

## ========== ATTACK TIMING (IMPROVED - Phase 1) ==========
## Reduced from original values for faster, more fluid combat
const WIND_UP_TIME: float = 0.12      # Reduced from 0.15 (20% faster)
const ATTACK_TIME: float = 0.05       # Unchanged (instant damage frame)
const RECOVERY_TIME: float = 0.08     # Reduced from 0.2 (60% faster)

## Total attack commitment = 0.25s (down from 0.4s)
const TOTAL_ATTACK_DURATION: float = WIND_UP_TIME + ATTACK_TIME + RECOVERY_TIME

## ========== MOVEMENT RULES (FLUID COMBAT) ==========
## NEW: Allow movement during recovery for fluid gameplay
const MOVEMENT_ALLOWED_DURING_RECOVERY: bool = true
const MUST_STOP_BEFORE_ATTACK: bool = false
const STOP_TIME_BEFORE_ATTACK: float = 0.0

## Attack-move: Can adjust position during wind-up
const ATTACK_MOVE_SPEED_MULT: float = 0.5  # Move at 50% speed during wind-up

## ========== MOVEMENT SPEED ==========
const BASE_PLAYER_SPEED: float = 300.0      # Players keep current speed
const BASE_ENEMY_SPEED: float = 230.0       # Enemies 23% slower (can always disengage)
const LUNGE_SPEED: float = 600.0            # Burst speed during attack
const LUNGE_FRICTION: float = 10.0          # How fast lunge slows down

## ========== DODGE TIMING (ENHANCED - Phase 1) ==========
## Improved values for more mobility and tactical depth
const DODGE_ROLL_DURATION: float = 0.35       # Reduced from 0.4 (faster roll)
const DODGE_ROLL_DISTANCE: float = 500.0      # Increased from 400 (more range)
const DODGE_ROLL_IFRAMES: float = 0.35        # Full duration invincible
const DODGE_ROLL_COOLDOWN: float = 0.8        # Reduced from 1.0 (more frequent)
const DODGE_ROLL_ENERGY_COST: int = 15        # Unchanged

## ========== INVINCIBILITY FRAMES ==========
const INVINCIBILITY_DURATION: float = 0.5   # 500ms after taking damage

## ========== RESOURCE REGENERATION ==========
const ENERGY_REGEN_RATE: float = 10.0   # Energy regenerated per second
const MANA_REGEN_RATE: float = 3.0      # Mana regenerated per second

## ========== KNOCKBACK ==========
const BLOCK_KNOCKBACK_DISTANCE: float = 80.0
const BLOCK_KNOCKBACK_DURATION: float = 0.3

## ========== COMBO TIMING (NEW - Phase 4) ==========
## Combo chain system for progressive attack speed
const COMBO_CHAIN_WINDOW: float = 0.5     # Time window to continue combo
const MAX_COMBO_COUNT: int = 3            # Maximum combo chain length

## Speed scaling for each hit in combo (1st, 2nd, 3rd)
const COMBO_WIND_UP_SCALES: Array[float] = [1.0, 0.85, 0.7]   # Each hit winds up faster
const COMBO_RECOVERY_SCALES: Array[float] = [1.0, 0.9, 0.8]   # Each hit recovers faster

## ========== TIMING HELPERS ==========

static func get_wind_up_time(combo_count: int = 0) -> float:
	"""Get wind-up time with optional combo scaling"""
	if combo_count <= 0 or combo_count > MAX_COMBO_COUNT:
		return WIND_UP_TIME

	var scale_index = clamp(combo_count - 1, 0, COMBO_WIND_UP_SCALES.size() - 1)
	return WIND_UP_TIME * COMBO_WIND_UP_SCALES[scale_index]

static func get_recovery_time(combo_count: int = 0) -> float:
	"""Get recovery time with optional combo scaling"""
	if combo_count <= 0 or combo_count > MAX_COMBO_COUNT:
		return RECOVERY_TIME

	var scale_index = clamp(combo_count - 1, 0, COMBO_RECOVERY_SCALES.size() - 1)
	return RECOVERY_TIME * COMBO_RECOVERY_SCALES[scale_index]

static func get_total_attack_duration(combo_count: int = 0) -> float:
	"""Get total attack duration (wind-up + attack + recovery) with combo scaling"""
	return get_wind_up_time(combo_count) + ATTACK_TIME + get_recovery_time(combo_count)

static func is_movement_allowed_in_state(attack_state: String) -> bool:
	"""Check if movement is allowed during this attack state"""
	match attack_state:
		"": return true  # Idle - can move freely
		"winding_up": return false  # Locked during wind-up (can add attack-move later)
		"attacking": return false  # Locked during attack frame
		"recovering": return MOVEMENT_ALLOWED_DURING_RECOVERY  # NEW: Can move during recovery!
		_: return true

## ========== STATE VALIDATION ==========

static func validate_attack_state_transition(from_state: String, to_state: String) -> bool:
	"""Validate that an attack state transition is legal"""
	# Empty state can always start winding up
	if from_state == "" and to_state == "winding_up":
		return true

	# Valid progression: winding_up -> attacking -> recovering -> ""
	match from_state:
		"winding_up":
			return to_state == "attacking"
		"attacking":
			return to_state == "recovering"
		"recovering":
			return to_state == "" or to_state == "winding_up"  # Can start new attack
		_:
			return false

## ========== TIMING CALCULATIONS ==========

static func calculate_attack_progress(state_timer: float, attack_state: String, combo_count: int = 0) -> float:
	"""Calculate 0.0-1.0 progress through current attack state"""
	match attack_state:
		"winding_up":
			var duration = get_wind_up_time(combo_count)
			return 1.0 - clamp(state_timer / duration, 0.0, 1.0)
		"attacking":
			return 1.0 - clamp(state_timer / ATTACK_TIME, 0.0, 1.0)
		"recovering":
			var duration = get_recovery_time(combo_count)
			return 1.0 - clamp(state_timer / duration, 0.0, 1.0)
		_:
			return 0.0

static func get_dodge_roll_speed() -> float:
	"""Calculate speed needed to travel DODGE_ROLL_DISTANCE in DODGE_ROLL_DURATION"""
	return DODGE_ROLL_DISTANCE / DODGE_ROLL_DURATION

## ========== DEBUG UTILITIES ==========

static func get_timing_summary() -> Dictionary:
	"""Get a summary of all timing values for debugging"""
	return {
		"attack": {
			"wind_up": WIND_UP_TIME,
			"attack": ATTACK_TIME,
			"recovery": RECOVERY_TIME,
			"total": TOTAL_ATTACK_DURATION
		},
		"dodge": {
			"duration": DODGE_ROLL_DURATION,
			"distance": DODGE_ROLL_DISTANCE,
			"cooldown": DODGE_ROLL_COOLDOWN,
			"speed": get_dodge_roll_speed()
		},
		"combo": {
			"window": COMBO_CHAIN_WINDOW,
			"max_count": MAX_COMBO_COUNT,
			"wind_up_scales": COMBO_WIND_UP_SCALES,
			"recovery_scales": COMBO_RECOVERY_SCALES
		}
	}

static func print_timing_summary() -> void:
	"""Print timing values for debugging"""
	var summary = get_timing_summary()
	print("=== Combat Timing Summary ===")
	print("Attack: %s" % summary.attack)
	print("Dodge: %s" % summary.dodge)
	print("Combo: %s" % summary.combo)
