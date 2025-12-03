class_name RealTimeCombatInput
extends RefCounted

static func handle_player_movement(battle: Dictionary, unit: Dictionary, velocity: Vector2) -> void:
	"""Process player movement input"""
	if unit.state == "dead":
		return

	# Use combat rules to check if movement is allowed
	# (blocks during attack wind-up, attack, recovery, and defending)
	if not CombatRules.can_move(unit):
		return

	# Clamp velocity to max speed
	if velocity.length() > unit.move_speed:
		velocity = velocity.normalized() * unit.move_speed

	unit.velocity = velocity

	if velocity.length() > 0:
		_update_facing_from_velocity(unit)
		unit.state = "moving"
	else:
		unit.state = "idle"

static func handle_player_attack(battle: Dictionary, unit: Dictionary, target_id: String) -> Dictionary:
	"""
	Process player attack input.
	Returns { "success": bool, "reason": String }
	"""
	if unit.state == "dead":
		print("[RT_COMBAT] Attack rejected: no unit or dead")
		return {"success": false, "reason": "dead"}

	# Can't attack while dodge rolling
	if CombatRules.is_dodge_rolling(unit):
		print("[RT_COMBAT] Attack rejected: dodge rolling")
		return {"success": false, "reason": "dodge_rolling"}

	# Check cooldown (minimum 1 second enforced)
	if unit.cooldown_timer > 0:
		print("[RT_COMBAT] Attack rejected: cooldown %.2f remaining" % unit.cooldown_timer)
		return {"success": false, "reason": "cooldown"}

	var target = battle.units.get(target_id)
	if not target or target.state == "dead" or target.team == unit.team:
		print("[RT_COMBAT] Attack rejected: invalid target %s" % target_id)
		return {"success": false, "reason": "invalid_target"}

	# Check range
	var distance = unit.position.distance_to(target.position)
	if distance > unit.attack_range:
		print("[RT_COMBAT] Attack rejected: out of range (dist=%.1f, range=%.1f)" % [distance, unit.attack_range])
		return {"success": false, "reason": "out_of_range"}

	# Fluid Combat: Removed strict cardinal alignment check. 
	# If target is in range, we snap to face them and attack.

	# Use combat rules to check if attack can start (includes max attackers check)
	var can_attack = CombatRules.can_start_attack(unit, battle, target_id)
	if not can_attack.allowed:
		print("[RT_COMBAT] Attack rejected: %s" % can_attack.reason)
		return {"success": false, "reason": can_attack.reason}

	# Face target automatically when attacking (snap turn)
	_face_target(unit, target.position)

	# Start attack with wind-up (includes Lunge velocity calculation)
	CombatRules.start_attack(unit, target_id, battle.units)
	print("[RT_COMBAT] Attack started (wind-up): %s -> %s" % [unit.id, target_id])
	
	return {"success": true}

static func handle_player_dodge_roll(battle: Dictionary, unit: Dictionary, direction_x: float, direction_y: float) -> Dictionary:
	"""
	Process player dodge roll input.
	Returns { "success": bool, "reason": String, "actual_direction": Vector2 }
	"""
	if unit.state == "dead":
		return {"success": false}

	# Check if can dodge roll (pass battle for enemy proximity check)
	var can_roll = CombatRules.can_dodge_roll(unit, battle)
	if not can_roll.allowed:
		print("[RT_COMBAT] Dodge roll rejected: %s" % can_roll.reason)
		return {"success": false, "reason": can_roll.reason}

	# Start the dodge roll (rolls in facing direction)
	var direction = Vector2(direction_x, direction_y)
	CombatRules.start_dodge_roll(unit, direction)

	# Get actual roll direction for broadcast (based on facing)
	var actual_direction = unit.get("dodge_roll_direction", direction)
	print("[RT_COMBAT] Dodge roll started: %s direction=%s" % [unit.id, actual_direction])
	
	return {"success": true, "actual_direction": actual_direction}

static func handle_player_defend(battle: Dictionary, unit: Dictionary) -> void:
	"""
	Process player defend input (Stub implementation)
	"""
	if unit.state == "dead":
		return
		
	print("[RT_COMBAT] Player defend action triggered (Not Implemented Yet)")
	# TODO: Implement defensive stance logic in CombatRules

## ========== HELPER FUNCTIONS ==========

static func _update_facing_from_velocity(unit: Dictionary) -> void:
	"""Update facing direction based on velocity"""
	if unit.velocity.length() < 1.0:
		return

	if abs(unit.velocity.x) > abs(unit.velocity.y):
		unit.facing = "right" if unit.velocity.x > 0 else "left"
	else:
		unit.facing = "down" if unit.velocity.y > 0 else "up"

static func _face_target(unit: Dictionary, target_pos: Vector2) -> void:
	"""Face toward a target position"""
	var to_target = target_pos - unit.position

	if abs(to_target.x) > abs(to_target.y):
		unit.facing = "right" if to_target.x > 0 else "left"
	else:
		unit.facing = "down" if to_target.y > 0 else "up"
