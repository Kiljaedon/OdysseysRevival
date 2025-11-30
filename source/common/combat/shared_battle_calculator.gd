class_name SharedBattleCalculator
extends RefCounted
## Shared Battle Logic - The "Single Source of Truth" for Math
## Used by: Client (Predictive), Server (Authoritative)
##
## Contains pure functions only. No state. No logging.

## ========== DAMAGE CONSTANTS ==========
const BASE_DAMAGE_MIN = 1.0
const CRIT_MULTIPLIER = 1.5
const DEFEND_MULTIPLIER = 0.5
const MAGIC_INT_MULTIPLIER = 2.2
const PHYSICAL_STR_MULTIPLIER = 2

## ========== RANGE PENALTY CONSTANTS ==========
const MELEE_BACK_ROW_PENALTY = 0.6
const MELEE_VS_BACK_ROW_PENALTY = 0.6
const MELEE_FLOOR_PENALTY = 0.36
const RANGED_FRONT_ROW_PENALTY = 0.5
const HYBRID_VERSATILITY_PENALTY = 0.95

## ========== DEFENSIVE MODIFIER CONSTANTS ==========
const CASTER_FRAGILITY = 1.2
const HYBRID_FRAGILITY = 1.15
const RANGED_FRAGILITY = 1.1
const MELEE_DEFENSE = 1.0

## ========== ELEMENTAL CHART ==========
# 0: Neutral, 1: Venus, 2: Mercury, 3: Mars, 4: Jupiter
const ELEMENT_MODIFIERS = {
	"Venus":   {"Venus": 1.0, "Mercury": 1.2, "Mars": 0.8, "Jupiter": 1.0},
	"Mercury": {"Venus": 0.8, "Mercury": 1.0, "Mars": 1.2, "Jupiter": 1.0},
	"Mars":    {"Venus": 1.0, "Mercury": 0.8, "Mars": 1.0, "Jupiter": 1.2},
	"Jupiter": {"Venus": 1.2, "Mercury": 1.0, "Mars": 0.8, "Jupiter": 1.0}
}

## ========== FORMATIONS ==========

static func is_front_row(panel_index: int) -> bool:
	# Panels 0, 1, 2 are Front
	return panel_index < 3

## ========== DAMAGE FORMULA ==========

static func calculate_physical_damage(
	attacker_stats: Dictionary, 
	defender_stats: Dictionary, 
	is_crit: bool = false,
	is_defending: bool = false
) -> int:
	
	var atk = float(attacker_stats.get("attack", 10))
	var defense = float(defender_stats.get("defense", 10))
	
	# Golden Sun-style: (Atk - Def) * 0.5
	# We add a base clamp to prevent 0 damage on equal stats
	var base_dmg = max(BASE_DAMAGE_MIN, (atk - defense) * 0.5)
	
	if is_crit:
		base_dmg *= CRIT_MULTIPLIER
		
	if is_defending:
		base_dmg *= DEFEND_MULTIPLIER
		
	return int(round(base_dmg))

static func calculate_psynergy_damage(
	power: float,
	attacker_element_power: float,
	defender_element_resist: float
) -> int:
	# Base + (Power * (1 + (ElemPwr - ElemRes)/200))
	var modifier = 1.0 + ((attacker_element_power - defender_element_resist) / 200.0)
	return int(round(power * modifier))


## ========== COMBAT ROLE DETECTION ==========

static func get_character_attack_type(character_data: Dictionary) -> String:
	"""Determine combat role based on character's combat_role tag"""
	# Use combat_role field if available
	if character_data.has("combat_role"):
		var role = character_data.combat_role.to_lower()
		if role in ["melee", "ranged", "caster", "hybrid"]:
			return role

	# Fallback: auto-detect from character_name
	var char_name = character_data.get("character_name", "").to_lower()

	# Melee keywords
	if "warrior" in char_name or "knight" in char_name or "paladin" in char_name or "berserker" in char_name or "monk" in char_name or "fighter" in char_name:
		return "melee"

	# Ranged keywords
	if "archer" in char_name or "ranger" in char_name or "gunner" in char_name or "sniper" in char_name or "hunter" in char_name:
		return "ranged"

	# Caster keywords
	if "mage" in char_name or "sorcerer" in char_name or "wizard" in char_name or "warlock" in char_name:
		return "caster"

	# Hybrid keywords
	if "spellblade" in char_name or "battlemage" in char_name:
		return "hybrid"

	# Default to melee
	return "melee"


## ========== RANGE PENALTY CALCULATION ==========

static func calculate_range_penalty(attacker_data: Dictionary, attacker_index: int, defender_index: int, is_attacker_enemy: bool, is_defender_enemy: bool) -> float:
	"""Calculate damage multiplier based on combat role and position"""
	var combat_role = get_character_attack_type(attacker_data)
	var attacker_front = is_front_row(attacker_index)
	var defender_front = is_front_row(defender_index)

	var penalty_multiplier = 1.0

	match combat_role:
		"caster":
			# CASTER: Full damage from any position
			return 1.0

		"hybrid":
			# HYBRID: 95% damage from any position (versatile but not specialized)
			return HYBRID_VERSATILITY_PENALTY

		"ranged":
			# RANGED: Full damage from back row, 50% if forced to melee in front
			if attacker_front:
				return RANGED_FRONT_ROW_PENALTY
			return 1.0

		"melee":
			# MELEE: Full damage in front row, penalties for back row positioning

			# Melee attacker in BACK ROW = 40% penalty
			if not attacker_front:
				penalty_multiplier *= MELEE_BACK_ROW_PENALTY

			# Attacking BACK ROW defender = additional 40% penalty
			if not defender_front:
				penalty_multiplier *= MELEE_VS_BACK_ROW_PENALTY

			# Hard floor: minimum 36% damage
			penalty_multiplier = max(MELEE_FLOOR_PENALTY, penalty_multiplier)
			return penalty_multiplier

	# Default fallback
	return 1.0


## ========== DEFENSIVE MODIFIER ==========

static func get_defensive_modifier(combat_role: String) -> float:
	"""Get defensive damage multiplier based on combat role"""
	match combat_role:
		"caster":
			# Casters take 20% extra damage (no armor)
			return CASTER_FRAGILITY
		"hybrid":
			# Hybrids take 15% extra damage (light armor)
			return HYBRID_FRAGILITY
		"ranged":
			# Ranged take 10% extra damage (light armor)
			return RANGED_FRAGILITY
		"melee":
			# Melee have normal defense (heavy armor)
			return MELEE_DEFENSE
	return 1.0


## ========== FULL DAMAGE CALCULATION ==========

static func calculate_damage(attacker: Dictionary, defender: Dictionary, attacker_index: int = -1, defender_index: int = -1, is_attacker_enemy: bool = false) -> int:
	"""Calculate damage using STAT_SYSTEM.md formulas with range penalties and defensive modifiers"""
	var attacker_str = 10
	var attacker_int = 10
	var defender_vit = 10
	var defender_int = 10
	var defender_wis = 10

	if attacker.has("base_stats"):
		attacker_str = attacker.base_stats.get("str", 10)
		attacker_int = attacker.base_stats.get("int", 10)
	if defender.has("base_stats"):
		defender_vit = defender.base_stats.get("vit", 10)
		defender_int = defender.base_stats.get("int", 10)
		defender_wis = defender.base_stats.get("wis", 10)

	# Determine attack type based on combat role
	var combat_role = get_character_attack_type(attacker)
	var base_damage: int = 0

	if combat_role == "caster":
		# Magic Damage = (INT * 2.2) - (INT / 2 + WIS / 3)
		var magic_attack = int(attacker_int * MAGIC_INT_MULTIPLIER)
		var magic_defense = int(defender_int / 2.0) + int(defender_wis / 3.0)
		base_damage = max(1, magic_attack - magic_defense)
	else:
		# Physical Damage = (STR * 2) + Weapon Power - (VIT / 2)
		var weapon_power = 0
		if attacker.has("weapon_power"):
			weapon_power = attacker.weapon_power
		var physical_attack = (attacker_str * PHYSICAL_STR_MULTIPLIER) + weapon_power
		var physical_defense = int(defender_vit / 2.0)
		base_damage = max(1, physical_attack - physical_defense)

	# Apply offensive range penalty (attacker's combat role)
	if attacker_index >= 0 and defender_index >= 0:
		var is_defender_enemy = !is_attacker_enemy  # Opposite teams
		var range_multiplier = calculate_range_penalty(attacker, attacker_index, defender_index, is_attacker_enemy, is_defender_enemy)
		base_damage = int(base_damage * range_multiplier)

	# Apply defensive modifier (defender's combat role)
	var defender_role = get_character_attack_type(defender)
	var defensive_multiplier = get_defensive_modifier(defender_role)
	if defensive_multiplier != 1.0:
		base_damage = int(base_damage * defensive_multiplier)

	# Minimum 1 damage
	return max(1, base_damage)
