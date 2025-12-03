class_name StatsCalculator
extends RefCounted

## Stats Calculator
## Pure math functions for calculating base damage from attributes.
## No state, no side effects.

const STR_MULTIPLIER = 1.5
const INT_MULTIPLIER = 1.5
const VIT_DIVISOR = 0.5
const WIS_DIVISOR = 0.5

static func calculate_physical_damage(attacker_stats: Dictionary, defender_stats: Dictionary, weapon_power: int = 0) -> float:
	var str = float(attacker_stats.get("str", 10))
	var vit = float(defender_stats.get("vit", 10))
	
	# Formula: (STR * 1.5 + Weapon) - (VIT * 0.5)
	var attack_power = (str * STR_MULTIPLIER) + weapon_power
	var defense_power = (vit * VIT_DIVISOR)
	
	return max(1.0, attack_power - defense_power)

static func calculate_magic_damage(attacker_stats: Dictionary, defender_stats: Dictionary, spell_power: int = 0) -> float:
	var int_stat = float(attacker_stats.get("int", 10))
	var wis_stat = float(defender_stats.get("wis", 10)) # Wisdom resists magic
	
	# Formula: (Spell Power + INT * 1.5) - (WIS * 0.5)
	var magic_power = spell_power + (int_stat * INT_MULTIPLIER)
	var magic_resist = (wis_stat * WIS_DIVISOR)
	
	return max(1.0, magic_power - magic_resist)
