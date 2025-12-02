extends RefCounted
## Combat Rules - Tactical combat pacing and engagement rules
## Enforces stop-to-attack, attack timing, and max attackers per target
##
## Attack sequence: IDLE -> WINDING_UP (400ms) -> ATTACKING -> RECOVERING (300ms) -> IDLE
## Units cannot move during wind-up, attack, or recovery

class_name CombatRules

## ========== TIMING CONSTANTS ==========

## Attack phases (in seconds)
const WIND_UP_TIME: float = 0.4      # Time before attack lands (can be dodged)
const ATTACK_TIME: float = 0.1       # Attack execution (instant damage)
const RECOVERY_TIME: float = 0.3     # Time after attack before can move

## Total attack commitment = 0.8 seconds
const TOTAL_ATTACK_DURATION: float = WIND_UP_TIME + ATTACK_TIME + RECOVERY_TIME

## Movement rules
const MUST_STOP_BEFORE_ATTACK: bool = true
const STOP_TIME_BEFORE_ATTACK: float = 0.1  # Must be still for 100ms before attacking

## ========== MOVEMENT SPEED ==========
## Players are faster than enemies so they can always disengage
const BASE_PLAYER_SPEED: float = 300.0      # Players keep current speed
const BASE_ENEMY_SPEED: float = 230.0       # Enemies 23% slower

## ========== INVINCIBILITY FRAMES ==========
## Brief invincibility after taking damage to prevent damage loops
const INVINCIBILITY_DURATION: float = 0.5   # 500ms after taking damage

## ========== RESOURCE REGENERATION ==========
## Base regen rates per second
const ENERGY_REGEN_RATE: float = 10.0   # Energy regenerated per second
const MANA_REGEN_RATE: float = 3.0      # Mana regenerated per second

## ========== HITS-TO-KILL BALANCE ==========
## Approximate hits to kill at equal level - makes combat predictable
const HITS_TO_KILL_PLAYER: int = 6          # Player survives 6 hits
const HITS_TO_KILL_WEAK_ENEMY: int = 2      # Weak enemies die in 2 hits
const HITS_TO_KILL_NORMAL_ENEMY: int = 4    # Normal enemies die in 4 hits
const HITS_TO_KILL_STRONG_ENEMY: int = 6    # Strong enemies die in 6 hits

## ========== KNOCKBACK ==========
## Push attacker away when their attack is blocked
const BLOCK_KNOCKBACK_DISTANCE: float = 80.0
const BLOCK_KNOCKBACK_DURATION: float = 0.3

## ========== DODGE ROLL ==========
## Quick evasive roll with invincibility frames - only usable in battle
const DODGE_ROLL_DURATION: float = 0.4        # Time spent rolling
const DODGE_ROLL_DISTANCE: float = 400.0      # Pixels traveled (few tiles dash)
const DODGE_ROLL_IFRAMES: float = 0.35        # Invincibility during roll
const DODGE_ROLL_COOLDOWN: float = 1.0        # Seconds before can roll again
const DODGE_ROLL_ENERGY_COST: int = 15        # Energy consumed per roll

## ========== ENGAGEMENT RULES ==========

## Max melee attackers on single target (prevents dog-piling)
const MAX_MELEE_ATTACKERS_PER_TARGET: int = 2

## Max ranged attackers can be higher (they're at distance)
const MAX_RANGED_ATTACKERS_PER_TARGET: int = 4

## Distance for melee vs ranged determination
const MELEE_RANGE_THRESHOLD: float = 150.0


## ========== ATTACK STATE CHECKS ==========

static func can_move(unit: Dictionary) -> bool:
	"""Check if a unit is allowed to move"""
	# Can't move while in attack sequence
	if unit.get("attack_state", "") in ["winding_up", "attacking", "recovering"]:
		return false
	# Can't move while dodge rolling (roll has its own movement)
	if unit.get("is_dodge_rolling", false):
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
	if unit.get("is_dodge_rolling", false):
		return {"allowed": false, "reason": "dodge_rolling"}

	# Must be stopped before attacking?
	if MUST_STOP_BEFORE_ATTACK:
		var velocity = unit.get("velocity", Vector2.ZERO)
		if velocity.length() > 10.0:  # Small threshold for "stopped"
			return {"allowed": false, "reason": "must_stop_first"}

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

static func start_attack(unit: Dictionary, target_id: String) -> void:
	"""Begin the attack wind-up phase"""
	unit["attack_state"] = "winding_up"
	unit["attack_state_timer"] = WIND_UP_TIME
	unit["attack_target_id"] = target_id
	unit["velocity"] = Vector2.ZERO  # Force stop
	unit["state"] = "attacking"


static func process_attack_state(unit: Dictionary, delta: float) -> String:
	"""Process attack state timer. Returns event: '', 'execute_attack', 'attack_complete'"""
	var attack_state = unit.get("attack_state", "")
	if attack_state == "":
		return ""

	unit["attack_state_timer"] = unit.get("attack_state_timer", 0.0) - delta

	if unit["attack_state_timer"] <= 0:
		match attack_state:
			"winding_up":
				# Wind-up complete - execute the attack
				unit["attack_state"] = "attacking"
				unit["attack_state_timer"] = ATTACK_TIME
				return "execute_attack"

			"attacking":
				# Attack done - enter recovery
				unit["attack_state"] = "recovering"
				unit["attack_state_timer"] = RECOVERY_TIME
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


static func is_in_attack_sequence(unit: Dictionary) -> bool:
	"""Check if unit is currently in any attack phase"""
	return unit.get("attack_state", "") != ""


## ========== UNIT INITIALIZATION ==========

static func init_combat_fields(unit: Dictionary) -> void:
	"""Add combat rule fields to a unit"""
	unit["attack_state"] = ""           # "", "winding_up", "attacking", "recovering"
	unit["attack_state_timer"] = 0.0    # Time remaining in current attack phase
	unit["attack_target_id"] = ""       # Who we're attacking
	# Invincibility frames
	unit["invincibility_timer"] = 0.0   # Time remaining invincible after taking damage
	# Knockback
	unit["knockback_velocity"] = Vector2.ZERO
	unit["knockback_timer"] = 0.0
	unit["is_knocked_back"] = false
	# AI pause after attacking
	unit["post_attack_pause"] = 0.0
	# Dodge roll
	unit["is_dodge_rolling"] = false
	unit["dodge_roll_timer"] = 0.0
	unit["dodge_roll_direction"] = Vector2.ZERO
	unit["dodge_roll_cooldown"] = 0.0


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
		return BASE_PLAYER_SPEED
	else:
		return BASE_ENEMY_SPEED


## ========== INVINCIBILITY FRAMES ==========

static func is_invincible(unit: Dictionary) -> bool:
	"""Check if unit is currently invincible"""
	return unit.get("invincibility_timer", 0.0) > 0


static func apply_damage(unit: Dictionary, damage: int) -> int:
	"""Apply damage with invincibility check. Returns actual damage dealt."""
	if is_invincible(unit):
		return 0
	unit["invincibility_timer"] = INVINCIBILITY_DURATION
	unit["hp"] = unit.get("hp", 0) - damage
	return damage


static func process_invincibility(unit: Dictionary, delta: float) -> void:
	"""Update invincibility timer"""
	if unit.get("invincibility_timer", 0.0) > 0:
		unit["invincibility_timer"] = unit.get("invincibility_timer", 0.0) - delta


static func process_resource_regen(unit: Dictionary, delta: float) -> void:
	"""Regenerate energy and mana over time"""
	# Energy regen
	var current_energy = unit.get("energy", 0)
	var max_energy = unit.get("max_energy", 100)
	if current_energy < max_energy:
		current_energy = min(current_energy + ENERGY_REGEN_RATE * delta, max_energy)
		unit["energy"] = int(current_energy)

	# Mana regen
	var current_mp = unit.get("mp", 0)
	var max_mp = unit.get("max_mp", 50)
	if current_mp < max_mp:
		current_mp = min(current_mp + MANA_REGEN_RATE * delta, max_mp)
		unit["mp"] = int(current_mp)


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


## ========== DODGE ROLL ==========

static func can_dodge_roll(unit: Dictionary, _battle: Dictionary = {}) -> Dictionary:
	"""Check if unit can start a dodge roll. Returns {allowed: bool, reason: String}"""
	# Dead?
	if unit.get("state", "") == "dead":
		return {"allowed": false, "reason": "dead"}

	# Already rolling?
	if unit.get("is_dodge_rolling", false):
		return {"allowed": false, "reason": "already_rolling"}

	# On cooldown?
	if unit.get("dodge_roll_cooldown", 0.0) > 0:
		return {"allowed": false, "reason": "on_cooldown"}

	# In attack sequence?
	if unit.get("attack_state", "") in ["winding_up", "attacking", "recovering"]:
		return {"allowed": false, "reason": "attacking"}

	# Enough energy? (check both 'energy' and 'ep' fields for compatibility)
	var current_energy = unit.get("energy", unit.get("ep", 0))
	if current_energy < DODGE_ROLL_ENERGY_COST:
		return {"allowed": false, "reason": "not_enough_energy"}

	# Dodge roll is only available in battle (handled by caller - realtime_combat_manager)
	return {"allowed": true, "reason": ""}


static func start_dodge_roll(unit: Dictionary, direction: Vector2) -> void:
	"""Begin a dodge roll - dashes in the direction player is facing"""
	# Always roll in facing direction (ignore input direction for now)
	match unit.get("facing", "down"):
		"up": direction = Vector2.UP
		"down": direction = Vector2.DOWN
		"left": direction = Vector2.LEFT
		"right": direction = Vector2.RIGHT
		_: direction = Vector2.DOWN

	direction = direction.normalized()

	# Deduct energy (use 'energy' field, not 'ep')
	var current = unit.get("energy", unit.get("ep", 0))
	unit["energy"] = current - DODGE_ROLL_ENERGY_COST

	# Start roll
	unit["is_dodge_rolling"] = true
	unit["dodge_roll_timer"] = DODGE_ROLL_DURATION
	unit["dodge_roll_direction"] = direction
	unit["dodge_roll_cooldown"] = DODGE_ROLL_COOLDOWN

	# Grant invincibility for most of the roll
	unit["invincibility_timer"] = DODGE_ROLL_IFRAMES

	# Set state for animation
	unit["state"] = "dodge_rolling"


static func process_dodge_roll(unit: Dictionary, delta: float) -> Vector2:
	"""Process dodge roll movement. Returns velocity to apply."""
	if not unit.get("is_dodge_rolling", false):
		return Vector2.ZERO

	unit["dodge_roll_timer"] = unit.get("dodge_roll_timer", 0.0) - delta

	if unit["dodge_roll_timer"] <= 0:
		# Roll complete
		unit["is_dodge_rolling"] = false
		unit["dodge_roll_direction"] = Vector2.ZERO
		unit["state"] = "idle"
		return Vector2.ZERO

	# Calculate roll velocity (constant speed throughout roll)
	var roll_speed = DODGE_ROLL_DISTANCE / DODGE_ROLL_DURATION
	return unit.get("dodge_roll_direction", Vector2.ZERO) * roll_speed


static func process_dodge_cooldown(unit: Dictionary, delta: float) -> void:
	"""Update dodge roll cooldown timer"""
	if unit.get("dodge_roll_cooldown", 0.0) > 0:
		unit["dodge_roll_cooldown"] = unit.get("dodge_roll_cooldown", 0.0) - delta


static func is_dodge_rolling(unit: Dictionary) -> bool:
	"""Check if unit is currently dodge rolling"""
	return unit.get("is_dodge_rolling", false)
