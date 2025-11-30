extends Node
## Server Battle Calculator - Server-side authoritative damage calculations
## Delegates to SharedBattleCalculator for math, keeps validation server-only

class_name ServerBattleCalculator


## ========== DELEGATED METHODS ==========

func is_front_row(panel_index: int, is_enemy: bool) -> bool:
	"""Determine if a panel is in the front row based on formation"""
	return SharedBattleCalculator.is_front_row(panel_index)


func get_character_attack_type(character_data: Dictionary) -> String:
	"""Determine combat role based on character's combat_role tag"""
	return SharedBattleCalculator.get_character_attack_type(character_data)


func calculate_range_penalty(attacker_data: Dictionary, attacker_index: int, defender_index: int, is_attacker_enemy: bool, is_defender_enemy: bool) -> float:
	"""Calculate damage multiplier based on combat role and position"""
	return SharedBattleCalculator.calculate_range_penalty(attacker_data, attacker_index, defender_index, is_attacker_enemy, is_defender_enemy)


func get_defensive_modifier(combat_role: String) -> float:
	"""Get defensive damage multiplier based on combat role"""
	return SharedBattleCalculator.get_defensive_modifier(combat_role)


func calculate_damage(attacker: Dictionary, defender: Dictionary, attacker_index: int = -1, defender_index: int = -1, is_attacker_enemy: bool = false) -> int:
	"""Calculate damage using shared formulas with range penalties and defensive modifiers"""
	return SharedBattleCalculator.calculate_damage(attacker, defender, attacker_index, defender_index, is_attacker_enemy)


func calculate_basic_damage(attacker: Dictionary, defender: Dictionary) -> int:
	"""DEPRECATED: Use calculate_damage() instead"""
	return SharedBattleCalculator.calculate_damage(attacker, defender, -1, -1, false)


## ========== SERVER-ONLY VALIDATION ==========

func validate_action(action: String, target_index: int, actor_type: String, combat: Dictionary) -> Dictionary:
	"""
	Validate that a player action is valid
	Returns {valid: bool, error: String}
	"""
	# Validate action
	if not action in ["attack", "defend", "skill", "item"]:
		return {"valid": false, "error": "Invalid action: %s" % action}

	# Validate target
	if action == "attack":
		if target_index < 0 or target_index >= combat.enemy_squad.size():
			return {"valid": false, "error": "Invalid target index"}

		var target = combat.enemy_squad[target_index]
		if target.get("hp", 0) <= 0:
			return {"valid": false, "error": "Target is already defeated"}

	return {"valid": true, "error": ""}


func validate_damage_calculation(damage: int, attacker: Dictionary, defender: Dictionary) -> bool:
	"""
	Validate damage calculation against expected ranges
	Helps detect tampering or exploits
	"""
	# Recalculate damage
	var expected_damage = calculate_damage(attacker, defender)

	# Allow small variance due to rounding
	if abs(damage - expected_damage) > 5:
		print("WARNING: Damage variance detected - expected %d, got %d" % [expected_damage, damage])
		return false

	return true
