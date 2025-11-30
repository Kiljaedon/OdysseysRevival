## Battle Damage Calculator - Client Wrapper
## Delegates all calculations to SharedBattleCalculator for consistency
## Keeps wrapper for client-specific logging if needed
class_name BattleDamageCalculator


## ========== DELEGATED METHODS ==========

static func is_front_row(panel_index: int, is_enemy: bool) -> bool:
	"""Determine if a panel is in the front row based on formation"""
	return SharedBattleCalculator.is_front_row(panel_index)


static func get_character_attack_type(character_data: Dictionary) -> String:
	"""Determine combat role based on character's combat_role tag"""
	return SharedBattleCalculator.get_character_attack_type(character_data)


static func calculate_range_penalty(attacker_data: Dictionary, attacker_index: int, defender_index: int, is_attacker_enemy: bool, is_defender_enemy: bool) -> float:
	"""Calculate damage multiplier based on combat role and position"""
	return SharedBattleCalculator.calculate_range_penalty(attacker_data, attacker_index, defender_index, is_attacker_enemy, is_defender_enemy)


static func get_defensive_modifier(combat_role: String) -> float:
	"""Get defensive damage multiplier based on combat role"""
	return SharedBattleCalculator.get_defensive_modifier(combat_role)


static func calculate_damage(attacker: Dictionary, defender: Dictionary, attacker_index: int = -1, defender_index: int = -1, is_attacker_enemy: bool = false) -> int:
	"""Calculate damage using shared formulas with range penalties and defensive modifiers"""
	return SharedBattleCalculator.calculate_damage(attacker, defender, attacker_index, defender_index, is_attacker_enemy)


static func calculate_basic_damage(attacker: Dictionary, defender: Dictionary) -> int:
	"""DEPRECATED: Use calculate_damage() instead"""
	return SharedBattleCalculator.calculate_damage(attacker, defender, -1, -1, false)
