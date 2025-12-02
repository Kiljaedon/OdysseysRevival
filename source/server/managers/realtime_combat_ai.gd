extends RefCounted
## Realtime Combat AI - AI behavior, targeting, and pathfinding
## Extracted from realtime_combat_manager.gd to reduce file size
##
## This class handles:
##   - AI state machine (idle/moving/attacking)
##   - Target selection by archetype
##   - Cardinal direction positioning for attacks
##   - Unit separation to prevent bunching

class_name RealtimeCombatAI

## ========== CONSTANTS ==========
const UNIT_COLLISION_RADIUS: float = 40.0

## ========== AI PACING ==========
## Pause between attacks to make enemies feel less relentless
const PAUSE_AFTER_ATTACK: float = 1.0       # Enemies wait 1s after attack recovery
const PAUSE_CHANCE: float = 0.3             # 30% chance to hesitate instead of attacking

## ========== PUBLIC INTERFACE ==========

static func process_unit_ai(battle: Dictionary, unit: Dictionary, delta: float, callbacks: Dictionary) -> void:
	"""Main AI tick - process unit behavior based on current state

	callbacks should contain:
		- update_facing_from_velocity: Callable(unit)
		- execute_attack: Callable(battle, attacker, target)
	"""
	# If already in attack sequence (wind-up, attacking, recovering), don't change state
	# The attack state machine is processed in realtime_combat_manager._process_battle
	if CombatRules.is_in_attack_sequence(unit):
		unit.velocity = Vector2.ZERO  # Must stay still during attack sequence
		return

	# If being knocked back, don't do anything
	if CombatRules.is_knocked_back(unit):
		return

	# Check if in post-attack pause (hesitation between attacks)
	if unit.get("post_attack_pause", 0.0) > 0:
		unit["post_attack_pause"] = unit.get("post_attack_pause", 0.0) - delta
		unit.velocity = Vector2.ZERO  # Stand still while pausing
		return

	match unit.state:
		"idle":
			_ai_find_target(battle, unit)
		"moving":
			_ai_chase_target(battle, unit, callbacks)
		"attacking":
			_ai_attack(battle, unit, callbacks)


## ========== TARGET SELECTION ==========

static func _ai_find_target(battle: Dictionary, unit: Dictionary) -> void:
	"""Find a target based on archetype"""
	var enemies = get_enemy_units(battle, unit.team)
	if enemies.is_empty():
		return

	var target = select_target_by_archetype(unit, enemies)
	if target:
		unit.target_id = target.id
		unit.state = "moving"


static func select_target_by_archetype(unit: Dictionary, enemies: Array) -> Dictionary:
	"""Select target based on AI archetype"""
	if enemies.is_empty():
		return {}

	match unit.archetype:
		"AGGRESSIVE":
			# Target lowest HP
			enemies.sort_custom(func(a, b): return a.hp < b.hp)
			return enemies[0]
		"DEFENSIVE":
			# Random target (retreat handled elsewhere)
			return enemies.pick_random()
		"TACTICAL":
			# Prioritize casters/ranged
			var priority = enemies.filter(func(e): return e.combat_role in ["caster", "ranged"])
			if not priority.is_empty():
				priority.sort_custom(func(a, b): return a.hp < b.hp)
				return priority[0]
			return enemies.pick_random()
		"CHAOTIC":
			return enemies.pick_random()

	return enemies[0]


static func get_enemy_units(battle: Dictionary, my_team: String) -> Array:
	"""Get all alive enemy units"""
	var enemies = []
	for unit in battle.units.values():
		if unit.team != my_team and unit.state != "dead" and unit.hp > 0:
			enemies.append(unit)
	return enemies


## ========== MOVEMENT / CHASING ==========

static func _ai_chase_target(battle: Dictionary, unit: Dictionary, callbacks: Dictionary) -> void:
	"""Move toward target, positioning for cardinal direction attack"""
	# Check if movement is allowed (not in attack sequence, not defending, not dead)
	if not CombatRules.can_move(unit):
		unit.velocity = Vector2.ZERO
		return

	if unit.target_id.is_empty():
		unit.state = "idle"
		return

	var target = battle.units.get(unit.target_id)
	if not target or target.state == "dead":
		unit.target_id = ""
		unit.state = "idle"
		return

	var to_target = target.position - unit.position
	var distance = to_target.length()

	# Check if we're in a valid attack position (cardinal direction aligned)
	var attack_position = get_cardinal_attack_position(unit, target)

	if attack_position.aligned and distance <= unit.attack_range:
		# Properly aligned and in range - stop and prepare to attack!
		unit.velocity = Vector2.ZERO
		unit.state = "attacking"
		return

	# Need to reposition for attack
	# Move toward the best cardinal attack position
	var target_pos = calculate_attack_approach_position(unit, target, battle)
	var move_dir = (target_pos - unit.position).normalized()

	# Apply archetype behavior for approach style
	match unit.archetype:
		"AGGRESSIVE":
			# Move directly to attack position
			unit.velocity = move_dir * unit.move_speed
		"DEFENSIVE":
			# Slower approach, more cautious
			if distance < unit.attack_range * 2:
				unit.velocity = move_dir * unit.move_speed * 0.7
			else:
				unit.velocity = move_dir * unit.move_speed
		"TACTICAL":
			# Try to approach from behind
			unit.velocity = move_dir * unit.move_speed
		_:
			unit.velocity = move_dir * unit.move_speed

	# Avoid bunching with allies
	unit.velocity = apply_separation(battle, unit, unit.velocity)

	# Update facing direction
	if callbacks.has("update_facing_from_velocity"):
		callbacks.update_facing_from_velocity.call(unit)


## ========== POSITIONING ==========

static func get_cardinal_attack_position(attacker: Dictionary, target: Dictionary) -> Dictionary:
	"""Check if attacker is close enough to attack - for action combat we don't require strict alignment"""
	var to_target = target.position - attacker.position
	var abs_x = abs(to_target.x)
	var abs_y = abs(to_target.y)

	# For action-based combat: always allow attack if in range, determine facing direction
	var cardinal_dir = ""

	# Face the dominant direction toward target
	if abs_x > abs_y:
		cardinal_dir = "right" if to_target.x > 0 else "left"
	else:
		cardinal_dir = "down" if to_target.y > 0 else "up"

	# Always aligned for action combat - attack if in range
	return {"aligned": true, "direction": cardinal_dir}


static func calculate_attack_approach_position(unit: Dictionary, target: Dictionary, battle: Dictionary) -> Vector2:
	"""Calculate the best position to move to for attacking"""
	var attack_range = unit.attack_range
	var target_pos = target.position

	# Calculate 4 cardinal attack positions around target
	var positions = [
		target_pos + Vector2(0, -attack_range * 0.8),   # Above
		target_pos + Vector2(0, attack_range * 0.8),    # Below
		target_pos + Vector2(-attack_range * 0.8, 0),   # Left
		target_pos + Vector2(attack_range * 0.8, 0)     # Right
	]

	# Find the closest unoccupied position
	var best_pos = positions[0]
	var best_score = 999999.0

	for pos in positions:
		var dist_to_pos = unit.position.distance_to(pos)
		var score = dist_to_pos

		# Penalize positions occupied by other units
		for other in battle.units.values():
			if other.id != unit.id and other.state != "dead":
				var other_dist = other.position.distance_to(pos)
				if other_dist < 60:
					score += 500  # Heavy penalty for occupied positions

		# Penalize positions outside arena
		if pos.x < 50 or pos.x > battle.arena_pixels.x - 50:
			score += 300
		if pos.y < 50 or pos.y > battle.arena_pixels.y - 50:
			score += 300

		if score < best_score:
			best_score = score
			best_pos = pos

	return best_pos


static func apply_separation(battle: Dictionary, unit: Dictionary, velocity: Vector2) -> Vector2:
	"""Apply separation force to avoid bunching with ALL units (allies and enemies)
	Also enforces hard collision: enemies cannot pass through player units"""

	# Knocked-back units skip separation (can pass through others)
	if CombatRules.is_knocked_back(unit):
		return velocity

	var separation_force = Vector2.ZERO
	var separation_radius = UNIT_COLLISION_RADIUS * 2.5  # Keep some distance from all units

	for other in battle.units.values():
		if other.id == unit.id or other.state == "dead":
			continue

		var to_other = other.position - unit.position
		var dist = to_other.length()

		# Hard collision: enemies cannot push through player units
		if unit.get("team", "") == "enemy" and other.get("team", "") == "player":
			if dist < UNIT_COLLISION_RADIUS * 2 and dist > 0:
				# Block movement toward player - slide along instead
				var block_dir = -to_other.normalized()
				var velocity_toward_player = velocity.dot(to_other.normalized())
				if velocity_toward_player > 0:
					# Remove component moving toward player
					velocity = velocity - to_other.normalized() * velocity_toward_player
					# Add sliding force perpendicular
					var slide_dir = Vector2(-to_other.y, to_other.x).normalized()
					if velocity.dot(slide_dir) < 0:
						slide_dir = -slide_dir
					velocity = slide_dir * unit.move_speed * 0.5

		if dist < separation_radius and dist > 0:
			# Push away from other unit (stronger push for closer units)
			var push_strength = (separation_radius - dist) / separation_radius
			var push = -to_other.normalized() * push_strength
			separation_force += push

	# Blend separation with original velocity
	if separation_force.length() > 0:
		velocity = (velocity.normalized() + separation_force * 0.5).normalized() * unit.move_speed

	return velocity


## ========== ATTACK EXECUTION ==========

static func _ai_attack(battle: Dictionary, unit: Dictionary, callbacks: Dictionary) -> void:
	"""Start attack wind-up if allowed by combat rules (stop-to-attack, max attackers, etc.)"""
	var target = battle.units.get(unit.target_id)
	if not target or target.state == "dead":
		unit.target_id = ""
		unit.state = "idle"
		return

	var distance = unit.position.distance_to(target.position)
	if distance > unit.attack_range:
		unit.state = "moving"
		return

	# Check if properly aligned on cardinal direction
	var attack_position = get_cardinal_attack_position(unit, target)
	if not attack_position.aligned:
		# Not aligned, need to reposition
		unit.state = "moving"
		return

	# Must be stopped to attack
	unit.velocity = Vector2.ZERO

	# Face target
	if callbacks.has("face_target"):
		callbacks.face_target.call(unit, target.position)

	# Use CombatRules to check if attack can start
	# This enforces: cooldowns, max attackers per target, must-stop-to-attack, etc.
	var can_attack = CombatRules.can_start_attack(unit, battle, target.id)
	if not can_attack.allowed:
		# Can't attack - check if target has max attackers, find alternative
		if can_attack.reason == "target_has_max_attackers":
			var alt_target_id = CombatRules.find_alternative_target(battle, unit)
			if not alt_target_id.is_empty():
				unit.target_id = alt_target_id
				unit.state = "moving"
		# Otherwise wait (on cooldown, etc.)
		return

	# Random hesitation - makes AI feel less robotic
	if randf() < PAUSE_CHANCE:
		unit["post_attack_pause"] = randf_range(0.5, 1.5)
		return

	# Start attack wind-up (damage happens after wind-up in realtime_combat_manager)
	CombatRules.start_attack(unit, target.id)

	# Set post-attack pause so enemy doesn't immediately attack again
	unit["post_attack_pause"] = PAUSE_AFTER_ATTACK

	# Check if target died (shouldn't happen here but safety check)
	if target.state == "dead":
		CombatRules.cancel_attack(unit)
		unit.target_id = ""
		unit.state = "idle"
