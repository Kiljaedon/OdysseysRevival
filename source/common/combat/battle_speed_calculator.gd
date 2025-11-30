class_name BattleSpeedCalculator
extends RefCounted
## Battle Speed Calculator - DEX-based speed calculations
## Used by: Client (Predictive), Server (Authoritative)
## Pure functions only. No state.

## ========== DEX SCALING CONSTANTS ==========
const DEX_MOVE_SPEED_PERCENT_PER_POINT: float = 0.01   # +1% per DEX
const DEX_ATTACK_SPEED_PERCENT_PER_POINT: float = 0.015 # +1.5% per DEX
const BASE_DEX: int = 10  # Baseline DEX (no bonus/penalty at this value)

## ========== SIZE MODIFIERS ==========
const SIZE_CONFIGS = {
	"small": {"move_speed_modifier": 1.15, "attack_speed_modifier": 1.20},
	"standard": {"move_speed_modifier": 1.0, "attack_speed_modifier": 1.0},
	"large": {"move_speed_modifier": 0.80, "attack_speed_modifier": 0.85},
	"massive": {"move_speed_modifier": 0.65, "attack_speed_modifier": 0.70}
}

## ========== BASE SPEEDS ==========
const DEFAULT_BASE_MOVE_SPEED: float = 200.0  # pixels per second
const DEFAULT_BASE_ATTACK_COOLDOWN: float = 1.5  # seconds between attacks (0.66 attacks/sec)

## ========== SPEED CALCULATIONS ==========

static func calculate_move_speed(base_speed: float, dex: int, size: String = "standard") -> float:
	"""Calculate final move speed with DEX and size modifiers"""
	# DEX modifier: (dex - BASE_DEX) * 1% per point
	var dex_modifier = 1.0 + ((dex - BASE_DEX) * DEX_MOVE_SPEED_PERCENT_PER_POINT)

	# Size modifier
	var size_config = SIZE_CONFIGS.get(size, SIZE_CONFIGS["standard"])
	var size_modifier = size_config.move_speed_modifier

	return base_speed * dex_modifier * size_modifier

static func calculate_attack_cooldown(base_cooldown: float, dex: int, size: String = "standard") -> float:
	"""Calculate attack cooldown (lower = faster attacks)"""
	# DEX reduces cooldown: higher DEX = lower cooldown
	var dex_modifier = 1.0 - ((dex - BASE_DEX) * DEX_ATTACK_SPEED_PERCENT_PER_POINT)
	dex_modifier = max(0.3, dex_modifier)  # Cap at 70% reduction

	# Size modifier (inverted - smaller = faster)
	var size_config = SIZE_CONFIGS.get(size, SIZE_CONFIGS["standard"])
	var size_modifier = size_config.attack_speed_modifier
	# For cooldown, we invert the modifier since lower attack_speed_modifier = faster
	# But our SIZE_CONFIGS stores the speed multiplier, so we divide
	var cooldown_size_modifier = 1.0 / size_modifier if size_modifier > 0 else 1.0

	return base_cooldown * dex_modifier * cooldown_size_modifier

static func calculate_attacks_per_second(base_cooldown: float, dex: int, size: String = "standard") -> float:
	"""Calculate attacks per second (convenience function)"""
	var cooldown = calculate_attack_cooldown(base_cooldown, dex, size)
	return 1.0 / cooldown if cooldown > 0 else 1.0

## ========== CONVENIENCE FUNCTIONS ==========

static func get_move_speed_from_stats(unit_data: Dictionary) -> float:
	"""Extract move speed from unit data dictionary"""
	var base_speed = unit_data.get("base_move_speed", DEFAULT_BASE_MOVE_SPEED)
	var dex = _get_dex_from_data(unit_data)
	var size = unit_data.get("size", "standard")
	return calculate_move_speed(base_speed, dex, size)

static func get_attack_cooldown_from_stats(unit_data: Dictionary) -> float:
	"""Extract attack cooldown from unit data dictionary"""
	var base_cooldown = unit_data.get("base_attack_cooldown", DEFAULT_BASE_ATTACK_COOLDOWN)
	var dex = _get_dex_from_data(unit_data)
	var size = unit_data.get("size", "standard")
	return calculate_attack_cooldown(base_cooldown, dex, size)

static func _get_dex_from_data(unit_data: Dictionary) -> int:
	"""Extract DEX from various data formats"""
	if unit_data.has("base_stats") and unit_data.base_stats.has("dex"):
		return unit_data.base_stats.dex
	if unit_data.has("dex"):
		return unit_data.dex
	return BASE_DEX
