extends RefCounted
## Combat Rules - Tactical Combat Coordinator (REFACTORED)
## REFACTORED: Extracted timing, combo, dodge to separate systems
## PURPOSE: High-level rule enforcement and coordination
## SIZE: ~350 lines (down from 486)
##
## This file now acts as a coordinator, delegating to specialized systems:
## - CombatTiming: All timing constants and calculations
## - CombatComboSystem: Combo chain management
## - CombatDodgeSystem: Dodge roll mechanics
##
## Refactoring reduced this file by ~136 lines while improving organization.

class_name CombatRules

## ========== IMPORTS ==========
const CombatTiming = preload("res://source/server/managers/combat/combat_timing.gd")
const CombatComboSystem = preload("res://source/server/managers/combat/combat_combo_system.gd")
const CombatDodgeSystem = preload("res://source/server/managers/combat/combat_dodge_system.gd")

## ========== BALANCE CONSTANTS (RETAINED) ==========
## These stay here as they're core game balance, not timing mechanics

## Hits-to-kill balance
const HITS_TO_KILL_PLAYER: int = 6          # Player survives 6 hits
const HITS_TO_KILL_WEAK_ENEMY: int = 2      # Weak enemies die in 2 hits
const HITS_TO_KILL_NORMAL_ENEMY: int = 4    # Normal enemies die in 4 hits
const HITS_TO_KILL_STRONG_ENEMY: int = 6    # Strong enemies die in 6 hits

## Engagement rules
const MAX_MELEE_ATTACKERS_PER_TARGET: int = 2
const MAX_RANGED_ATTACKERS_PER_TARGET: int = 4
const MELEE_RANGE_THRESHOLD: float = 150.0

## Knockback (retained for block mechanics)
const BLOCK_KNOCKBACK_DISTANCE: float = 80.0
const BLOCK_KNOCKBACK_DURATION: float = 0.3

## ========== ATTACK STATE CHECKS ==========

static func can_move(unit: Dictionary) -> bool:
	"""Check if a unit is allowed to move (UPDATED - uses CombatTiming)"""
	# Check attack state via CombatTiming
	var attack_state = unit.get("attack_state", "")
	if not CombatTiming.is_movement_allowed_in_state(attack_state):
		return false

	# Delegate dodge check to CombatDodgeSystem
	if CombatDodgeSystem.is_dodge_rolling(unit):
		return false

	# Can't move if dead
	if unit.get("state", "") == "dead":
		return false

	return true

static func can_start_attack(unit: Dictionary, battle: Dictionary, target_id: String) -> Dictionary:
	"""Check if a unit can start an attack. Returns {allowed: bool, reason: String}"""
	# Already in attack sequence?
	if unit.get("attack_state", "") != "":
		return {"allowed": false, "reason": "already_attacking"}

	# On cooldown?
	if unit.get("cooldown_timer", 0.0) > 0:
		return {"allowed": false, "reason": "on_cooldown"}

	# Dead?
	if unit.get("state", "") == "dead":
		return {"allowed": false, "reason": "dead"}

	# Dodge rolling?
	if CombatDodgeSystem.is_dodge_rolling(unit):
		return {"allowed": false, "reason": "dodge_rolling"}

	# Check max attackers on target
	var target = battle.units.get(target_id, {})
	if target.is_empty():
		return {"allowed": false, "reason": "invalid_target"}

	var current_attackers = _count_attackers_on_target(battle, target_id, unit.id)
	var is_melee = unit.get("attack_range", 100.0) <= MELEE_RANGE_THRESHOLD
	var max_attackers = MAX_MELEE_ATTACKERS_PER_TARGET if is_melee else MAX_RANGED_ATTACKERS_PER_TARGET

	if current_attackers >= max_attackers:
		return {"allowed": false, "reason": "target_has_max_attackers"}

	return {"allowed": true, "reason": ""}

static func _count_attackers_on_target(battle: Dictionary, target_id: String, exclude_unit_id: String) -> int:
	"""Count how many units are currently attacking the target"""
	var count = 0
	for unit_id in battle.units:
		if unit_id == exclude_unit_id:
			continue
		var unit = battle.units[unit_id]
		# Count units in attack sequence targeting this unit
		if unit.get("attack_target_id", "") == target_id:
			if unit.get("attack_state", "") in ["winding_up", "attacking"]:
				count += 1
	return count

## ========== ATTACK STATE MANAGEMENT ==========

static func start_attack(unit: Dictionary, target_id: String, battle_units: Dictionary = {}) -> void:
	"""Begin the attack wind-up phase with lunge (UPDATED - uses CombatTiming + Combo)"""
	# Get combo-scaled timing
	var wind_up_time = CombatComboSystem.get_scaled_wind_up_time(unit)

	unit["attack_state"] = "winding_up"
	unit["attack_state_timer"] = wind_up_time
	unit["attack_target_id"] = target_id
	unit["velocity"] = Vector2.ZERO  # Reset input velocity
	unit["state"] = "attacking"

	# Lunge towards target
	var target = battle_units.get(target_id)
	if target:
		var direction = (target.position - unit.position).normalized()
		unit["lunge_velocity"] = direction * CombatTiming.LUNGE_SPEED
	else:
		# Fallback: lunge forward based on facing
		var dir = Vector2.DOWN
		match unit.get("facing", "down"):
			"up": dir = Vector2.UP
			"left": dir = Vector2.LEFT
			"right": dir = Vector2.RIGHT
		unit["lunge_velocity"] = dir * CombatTiming.LUNGE_SPEED

	# Advance combo chain
	CombatComboSystem.advance_combo(unit)

static func process_lunge(unit: Dictionary, delta: float) -> Vector2:
	"""Process lunge velocity decay. Returns velocity to apply."""
	var lunge = unit.get("lunge_velocity", Vector2.ZERO)
	if lunge.length_squared() < 1.0:
		return Vector2.ZERO

	# Apply friction
	lunge = lunge.lerp(Vector2.ZERO, delta * CombatTiming.LUNGE_FRICTION)
	unit["lunge_velocity"] = lunge

	return lunge

static func process_attack_state(unit: Dictionary, delta: float) -> String:
	"""Process attack state timer (UPDATED - uses CombatTiming + Combo)"""
	var attack_state = unit.get("attack_state", "")
	if attack_state == "":
		return ""

	unit["attack_state_timer"] = unit.get("attack_state_timer", 0.0) - delta

	if unit["attack_state_timer"] <= 0:
		match attack_state:
			"winding_up":
				# Wind-up complete - execute the attack
				unit["attack_state"] = "attacking"
				unit["attack_state_timer"] = CombatTiming.ATTACK_TIME
				return "execute_attack"

			"attacking":
				# Attack done - enter recovery (combo-scaled)
				var recovery_time = CombatComboSystem.get_scaled_recovery_time(unit)
				unit["attack_state"] = "recovering"
				unit["attack_state_timer"] = recovery_time
				return ""

			"recovering":
				# Recovery done - can act again
				unit["attack_state"] = ""
				unit["attack_target_id"] = ""
				unit["state"] = "idle"
				return "attack_complete"

	return ""

static func cancel_attack(unit: Dictionary) -> void:
	"""Cancel an attack (e.g., if target dies during wind-up)"""
	unit["attack_state"] = ""
	unit["attack_state_timer"] = 0.0
	unit["attack_target_id"] = ""
	unit["state"] = "idle"
	unit["lunge_velocity"] = Vector2.ZERO

static func is_in_attack_sequence(unit: Dictionary) -> bool:
	"""Check if unit is currently in any attack phase"""
	return unit.get("attack_state", "") != ""

## ========== UNIT INITIALIZATION ==========

static func init_combat_fields(unit: Dictionary) -> void:
	"""Add combat rule fields to a unit (UPDATED - delegates to subsystems)"""
	# Attack state
	unit["attack_state"] = ""           # "", "winding_up", "attacking", "recovering"
	unit["attack_state_timer"] = 0.0    # Time remaining in current attack phase
	unit["attack_target_id"] = ""       # Who we're attacking
	unit["lunge_velocity"] = Vector2.ZERO # Forward momentum during attack

	# Invincibility frames
	unit["invincibility_timer"] = 0.0   # Time remaining invincible after taking damage

	# Knockback
	unit["knockback_velocity"] = Vector2.ZERO
	unit["knockback_timer"] = 0.0
	unit["is_knocked_back"] = false

	# AI pause after attacking
	unit["post_attack_pause"] = 0.0

	# Initialize subsystems
	CombatDodgeSystem.init_dodge_fields(unit)
	CombatComboSystem.init_combo_fields(unit)

## ========== INVINCIBILITY FRAMES ==========

static func is_invincible(unit: Dictionary) -> bool:
	"""Check if unit is currently invincible"""
	return unit.get("invincibility_timer", 0.0) > 0

static func apply_damage(unit: Dictionary, damage: int) -> int:
	"""Apply damage with invincibility check. Returns actual damage dealt."""
	if is_invincible(unit):
		return 0
	unit["invincibility_timer"] = CombatTiming.INVINCIBILITY_DURATION
	unit["hp"] = unit.get("hp", 0) - damage
	return damage

static func process_invincibility(unit: Dictionary, delta: float) -> void:
	"""Update invincibility timer"""
	if unit.get("invincibility_timer", 0.0) > 0:
		unit["invincibility_timer"] = unit.get("invincibility_timer", 0.0) - delta

## ========== RESOURCE REGENERATION ==========

static func process_resource_regen(unit: Dictionary, delta: float) -> void:
	"""Regenerate energy and mana over time"""
	# Energy regen
	var current_energy = unit.get("energy", 0)
	var max_energy = unit.get("max_energy", 100)
	if current_energy < max_energy:
		current_energy = min(current_energy + CombatTiming.ENERGY_REGEN_RATE * delta, max_energy)
		unit["energy"] = int(current_energy)

	# Mana regen
	var current_mp = unit.get("mp", 0)
	var max_mp = unit.get("max_mp", 50)
	if current_mp < max_mp:
		current_mp = min(current_mp + CombatTiming.MANA_REGEN_RATE * delta, max_mp)
		unit["mp"] = int(current_mp)

## ========== COMBO SYSTEM (DELEGATED) ==========
## Thin wrapper that delegates to CombatComboSystem

static func process_combo_window(unit: Dictionary, delta: float) -> void:
	"""Update combo window timer (delegates to CombatComboSystem)"""
	CombatComboSystem.process_combo_window(unit, delta)

## ========== DODGE ROLL (DELEGATED) ==========
## These are now thin wrappers that delegate to CombatDodgeSystem

static func can_dodge_roll(unit: Dictionary, battle: Dictionary = {}) -> Dictionary:
	"""Check if unit can start a dodge roll (delegates to CombatDodgeSystem)"""
	return CombatDodgeSystem.can_dodge_roll(unit, battle)

static func start_dodge_roll(unit: Dictionary, direction: Vector2) -> void:
	"""Begin a dodge roll (delegates to CombatDodgeSystem)"""
	CombatDodgeSystem.start_dodge_roll(unit, direction)

static func process_dodge_roll(unit: Dictionary, delta: float) -> Vector2:
	"""Process dodge roll movement (delegates to CombatDodgeSystem)"""
	return CombatDodgeSystem.process_dodge_roll(unit, delta)

static func process_dodge_cooldown(unit: Dictionary, delta: float) -> void:
	"""Update dodge roll cooldown (delegates to CombatDodgeSystem)"""
	CombatDodgeSystem.process_dodge_cooldown(unit, delta)

static func is_dodge_rolling(unit: Dictionary) -> bool:
	"""Check if unit is dodge rolling (delegates to CombatDodgeSystem)"""
	return CombatDodgeSystem.is_dodge_rolling(unit)

## ========== KNOCKBACK ==========

static func apply_block_knockback(attacker: Dictionary, defender: Dictionary) -> void:
	"""Push attacker away when their attack is blocked"""
	var knockback_dir = (attacker.position - defender.position).normalized()
	attacker["knockback_velocity"] = knockback_dir * (BLOCK_KNOCKBACK_DISTANCE / BLOCK_KNOCKBACK_DURATION)
	attacker["knockback_timer"] = BLOCK_KNOCKBACK_DURATION
	attacker["is_knocked_back"] = true

static func process_knockback(unit: Dictionary, delta: float) -> bool:
	"""Process knockback movement. Returns true if unit is being knocked back."""
	if not unit.get("is_knocked_back", false):
		return false

	unit["knockback_timer"] = unit.get("knockback_timer", 0.0) - delta

	if unit["knockback_timer"] <= 0:
		unit["is_knocked_back"] = false
		unit["knockback_velocity"] = Vector2.ZERO
		return false

	return true

static func is_knocked_back(unit: Dictionary) -> bool:
	"""Check if unit is currently being knocked back"""
	return unit.get("is_knocked_back", false)

## ========== HITS-TO-KILL BALANCE ==========

static func calculate_balanced_damage(base_damage: int, attacker: Dictionary, defender: Dictionary) -> int:
	"""Scale damage to achieve hits-to-kill targets for predictable combat pacing"""
	var defender_max_hp = defender.get("max_hp", 100)
	var target_hits: int

	if defender.get("team", "") == "player":
		target_hits = HITS_TO_KILL_PLAYER
	else:
		# Enemy tiers based on archetype
		var archetype = defender.get("archetype", "AGGRESSIVE")
		match archetype:
			"DEFENSIVE":
				target_hits = HITS_TO_KILL_STRONG_ENEMY
			"TACTICAL":
				target_hits = HITS_TO_KILL_NORMAL_ENEMY
			_:
				target_hits = HITS_TO_KILL_NORMAL_ENEMY

	# Scale damage so max_hp / damage = target_hits
	var target_damage = float(defender_max_hp) / float(target_hits)

	# Blend base damage with target (70% target, 30% base stats)
	# This keeps stats relevant while ensuring predictable pacing
	return int(target_damage * 0.7 + float(base_damage) * 0.3)

## ========== AI HELPERS ==========

static func should_ai_stop_to_attack(unit: Dictionary, target_pos: Vector2, attack_range: float) -> bool:
	"""Check if AI should stop moving to begin attack"""
	var dist = unit.position.distance_to(target_pos)
	# In range and not in attack sequence = should stop and attack
	return dist <= attack_range and not is_in_attack_sequence(unit)

static func find_alternative_target(battle: Dictionary, attacker: Dictionary) -> String:
	"""Find a target that doesn't have max attackers"""
	var attacker_team = attacker.get("team", "")
	var is_melee = attacker.get("attack_range", 100.0) <= MELEE_RANGE_THRESHOLD
	var max_attackers = MAX_MELEE_ATTACKERS_PER_TARGET if is_melee else MAX_RANGED_ATTACKERS_PER_TARGET

	var best_target_id = ""
	var best_distance = INF

	for unit_id in battle.units:
		var unit = battle.units[unit_id]
		# Skip same team, dead units
		if unit.get("team", "") == attacker_team:
			continue
		if unit.get("state", "") == "dead":
			continue

		# Check if target has room for another attacker
		var current_attackers = _count_attackers_on_target(battle, unit_id, attacker.id)
		if current_attackers >= max_attackers:
			continue

		# Prefer closest valid target
		var dist = attacker.position.distance_to(unit.position)
		if dist < best_distance:
			best_distance = dist
			best_target_id = unit_id

	return best_target_id

## ========== MOVEMENT SPEED ==========

static func get_unit_speed(unit: Dictionary) -> float:
	"""Get movement speed based on team - players are faster than enemies"""
	if unit.get("team", "") == "player":
		return CombatTiming.BASE_PLAYER_SPEED
	else:
		return CombatTiming.BASE_ENEMY_SPEED
