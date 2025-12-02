extends Node
## Realtime Combat Manager - Server-authoritative real-time battle system
## Handles battle instances, unit state, AI, damage, and victory/defeat
##
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
## WARNING: THIS FILE IS AT CAPACITY - DO NOT ADD MORE CODE HERE
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
##
## For new functionality, create separate files:
##   - realtime_combat_ai.gd        -> AI behavior, pathfinding, targeting
##   - realtime_combat_abilities.gd -> Skills, spells, special attacks
##   - realtime_combat_rewards.gd   -> XP, loot, victory calculations
##   - realtime_combat_effects.gd   -> Status effects, buffs, debuffs
##
## This file should only contain core battle lifecycle and state management.
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

class_name RealtimeCombatManager

## ========== CONSTANTS ==========
const STATE_UPDATE_RATE: float = 0.05  # 20 updates per second

## Battle area is now on the game map itself
## Spacing between player and NPC is 10-15 tiles (1280-1920 pixels at 128px/tile)
const BATTLE_TILE_SPACING: int = 12  # Tiles between player and enemy
const TILE_SIZE_SCALED: int = 128  # 32 * 4 scale
const BATTLE_SPAWN_DISTANCE: int = BATTLE_TILE_SPACING * TILE_SIZE_SCALED  # Pixels between player/enemy

## Map boundaries (updated per battle from server map data)
var map_width: int = 2560   # Default sample_map: 20 tiles * 128px (scaled)
var map_height: int = 1920  # Default sample_map: 15 tiles * 128px (scaled)

## Grace period before NPCs can attack (seconds)
const BATTLE_GRACE_PERIOD: float = 2.0

## Unit collision
const UNIT_COLLISION_RADIUS: float = 40.0  # Collision radius for each unit
const MAP_EDGE_PADDING: float = 128.0  # Keep units away from map edges (1 tile)

## Default grass tile (tile ID 568 = basic grass terrain from world maps)
const DEFAULT_GRASS_TILE: int = 568

## Flanking multipliers
const FLANK_FRONT: float = 1.0
const FLANK_SIDE: float = 1.15
const FLANK_BACK: float = 1.30

## Dodge roll constants are in CombatRules

## ========== DEPENDENCIES ==========
var server_world = null
var player_manager = null
var npc_manager = null
var network_handler = null

## ========== BATTLE STATE ==========
var active_battles: Dictionary = {}  # battle_id -> battle data
var next_battle_id: int = 1
var state_update_timer: float = 0.0

## AI callback references (passed to RealtimeCombatAI)
var _ai_callbacks: Dictionary = {}

## ========== LIFECYCLE ==========

func _ready():
	print("[RT_COMBAT] RealtimeCombatManager ready")
	# Setup AI callbacks
	_ai_callbacks = {
		"update_facing_from_velocity": _update_facing_from_velocity,
		"face_target": _face_target,
		"execute_attack": _execute_attack
	}

func initialize(p_server_world, p_player_manager, p_npc_manager) -> void:
	server_world = p_server_world
	player_manager = p_player_manager
	npc_manager = p_npc_manager

	# Get network handler from server_world's stored reference
	if server_world and "network_handler" in server_world:
		network_handler = server_world.network_handler

	print("[RT_COMBAT] Initialized with manager references")

func _physics_process(delta: float) -> void:
	# Process all active battles
	for battle_id in active_battles.keys():
		var battle = active_battles[battle_id]
		if battle.state == "active":
			_process_battle(battle, delta)

	# Broadcast state updates at fixed rate
	state_update_timer += delta
	if state_update_timer >= STATE_UPDATE_RATE:
		state_update_timer = 0.0
		_broadcast_all_battle_states()

## ========== BATTLE INSTANCE MANAGEMENT ==========

func create_battle(peer_id: int, npc_id: int, player_data: Dictionary, squad_data: Array, enemy_data: Array, battle_map_name: String = "sample_map") -> int:
	"""Create a new battle instance. Returns battle_id."""
	var battle_id = next_battle_id
	next_battle_id += 1

	# Get player's current world position for battle positioning
	var player_world_pos = Vector2.ZERO
	if player_manager:
		player_world_pos = player_manager.player_positions.get(peer_id, Vector2(map_width / 2.0, map_height / 2.0))

	# Battle uses the game map itself - player at bottom, enemies at top
	# Calculate battle area bounds based on player position
	var battle_center = player_world_pos
	var battle_area = Vector2(map_width, map_height)  # Full map for movement

	# Create battle data
	var battle = {
		"id": battle_id,
		"state": "active",
		"participants": [peer_id],
		"battle_center": battle_center,  # Player's position as center reference
		"arena_pixels": battle_area,  # Full map bounds
		"map_width": map_width,
		"map_height": map_height,
		"battle_map_name": battle_map_name,  # Map to load for this battle
		"units": {},
		"player_unit_id": "",
		"captain_id": "",
		"npc_id": npc_id,  # Original overworld NPC
		"created_at": Time.get_ticks_msec(),
		"grace_timer": BATTLE_GRACE_PERIOD  # NPCs wait before attacking
	}

	# Spawn units based on player's world position
	_spawn_player_unit(battle, peer_id, player_data, player_world_pos)
	_spawn_squad_units(battle, peer_id, squad_data, player_world_pos)
	_spawn_enemy_units(battle, enemy_data, player_world_pos)

	active_battles[battle_id] = battle
	print("[RT_COMBAT] Battle %d created for peer %d vs NPC %d" % [battle_id, peer_id, npc_id])

	# Debug: print unit info
	for uid in battle.units:
		var u = battle.units[uid]
		print("[RT_COMBAT] Unit %s: class=%s, npc_type=%s" % [
			uid,
			u.source_data.get("class_name", "NONE"),
			u.source_data.get("npc_type", "NONE")
		])

	# Send battle start to client
	_send_battle_start(peer_id, battle)

	return battle_id

func get_battle(battle_id: int) -> Dictionary:
	return active_battles.get(battle_id, {})

func get_battle_for_peer(peer_id: int) -> Dictionary:
	"""Find active battle for a peer"""
	for battle in active_battles.values():
		if peer_id in battle.participants:
			return battle
	return {}

func end_battle(battle_id: int, result: String) -> void:
	"""End a battle with victory or defeat"""
	if not active_battles.has(battle_id):
		return

	var battle = active_battles[battle_id]
	battle.state = result  # "victory" or "defeat"

	print("[RT_COMBAT] Battle %d ended: %s" % [battle_id, result])

	# Calculate rewards if victory
	var rewards = {}
	if result == "victory":
		rewards = _calculate_rewards(battle)

	# Notify participants
	for peer_id in battle.participants:
		_send_battle_end(peer_id, battle_id, result, rewards)

	# Clean up after short delay (let clients process)
	await get_tree().create_timer(2.0).timeout
	active_battles.erase(battle_id)

## ========== UNIT SPAWNING ==========

func _spawn_player_unit(battle: Dictionary, peer_id: int, player_data: Dictionary, player_world_pos: Vector2) -> void:
	"""Spawn the player's unit at their current world position"""
	var unit_id = "player_%d" % peer_id

	var unit = _create_unit_data(unit_id, player_data, "player")
	# Player stays at their current world position
	unit.position = player_world_pos
	unit.facing = "up"  # Facing enemies at top
	unit.is_player_controlled = true
	unit.is_captain = true
	unit.peer_id = peer_id

	battle.units[unit_id] = unit
	battle.player_unit_id = unit_id
	battle.captain_id = unit_id

func _spawn_squad_units(battle: Dictionary, peer_id: int, squad_data: Array, player_world_pos: Vector2) -> void:
	"""Spawn squad mercenaries around the player's world position"""
	# Squad positions: flanking player (relative to player's world position)
	var squad_offsets = [
		Vector2(-120, 0),    # Left of player
		Vector2(120, 0),     # Right of player
		Vector2(0, 80)       # Slightly behind player (lower on screen = higher Y)
	]

	for i in range(min(squad_data.size(), squad_offsets.size())):
		var merc_data = squad_data[i]
		var unit_id = "squad_%d_%d" % [peer_id, i]

		var unit = _create_unit_data(unit_id, merc_data, "player")
		var spawn_pos = player_world_pos + squad_offsets[i]
		# Clamp to map bounds
		spawn_pos.x = clamp(spawn_pos.x, MAP_EDGE_PADDING, map_width - MAP_EDGE_PADDING)
		spawn_pos.y = clamp(spawn_pos.y, MAP_EDGE_PADDING, map_height - MAP_EDGE_PADDING)
		unit.position = spawn_pos
		unit.facing = "up"  # Facing enemies
		unit.is_player_controlled = false
		unit.peer_id = peer_id
		unit.archetype = merc_data.get("ai_archetype", "AGGRESSIVE")

		battle.units[unit_id] = unit

func _spawn_enemy_units(battle: Dictionary, enemy_data: Array, player_world_pos: Vector2) -> void:
	"""Spawn enemies 10-15 tiles ABOVE the player on the map (lower Y = higher on screen)"""
	# Enemy base position: 12 tiles above player (negative Y direction)
	var enemy_base_y = player_world_pos.y - BATTLE_SPAWN_DISTANCE
	var center_x = player_world_pos.x

	# Ensure enemies don't spawn outside map bounds
	enemy_base_y = max(enemy_base_y, MAP_EDGE_PADDING)

	# Front row: main enemy position
	var enemy_y_front = enemy_base_y
	# Back row: slightly further from player (smaller Y)
	var enemy_y_back = enemy_base_y - (TILE_SIZE_SCALED * 2)  # 2 tiles behind front row
	enemy_y_back = max(enemy_y_back, MAP_EDGE_PADDING)

	# Enemy positions relative to player's X position
	var enemy_positions = [
		Vector2(center_x, enemy_y_front),           # Center (boss/main)
		Vector2(center_x - 180, enemy_y_front),     # Left
		Vector2(center_x + 180, enemy_y_front),     # Right
		Vector2(center_x - 100, enemy_y_back),      # Left-back
		Vector2(center_x + 100, enemy_y_back)       # Right-back
	]

	var enemy_captain_set = false

	for i in range(min(enemy_data.size(), enemy_positions.size())):
		var e_data = enemy_data[i]
		var unit_id = "enemy_%d" % i

		var unit = _create_unit_data(unit_id, e_data, "enemy")
		var spawn_pos = enemy_positions[i]
		# Clamp to map bounds
		spawn_pos.x = clamp(spawn_pos.x, MAP_EDGE_PADDING, map_width - MAP_EDGE_PADDING)
		spawn_pos.y = clamp(spawn_pos.y, MAP_EDGE_PADDING, map_height - MAP_EDGE_PADDING)
		unit.position = spawn_pos
		unit.facing = "down"  # Facing player (down = toward higher Y)
		unit.is_player_controlled = false
		unit.archetype = e_data.get("ai_archetype", "AGGRESSIVE")

		# First enemy is captain
		if not enemy_captain_set:
			unit.is_captain = true
			enemy_captain_set = true

		battle.units[unit_id] = unit

func _create_unit_data(unit_id: String, source_data: Dictionary, team: String) -> Dictionary:
	"""Create standardized unit data structure"""
	var base_stats = source_data.get("base_stats", {})
	var derived_stats = source_data.get("derived_stats", {})

	# HP: derived_stats.max_hp > base_stats.hp > source.hp > 100
	var max_hp = derived_stats.get("max_hp", base_stats.get("max_hp", source_data.get("max_hp", source_data.get("hp", 100))))
	var hp = source_data.get("hp", max_hp)

	# MP: derived_stats.max_mp > base_stats.mp > source.mp > 50
	var max_mp = derived_stats.get("max_mp", base_stats.get("max_mp", source_data.get("max_mp", source_data.get("mp", 50))))
	var mp = source_data.get("mp", max_mp)

	# Energy/Stamina: derived_stats.max_ep > energy > 100
	var max_energy = derived_stats.get("max_ep", source_data.get("max_energy", source_data.get("energy", 100)))
	var energy = source_data.get("energy", max_energy)

	var dex = base_stats.get("dex", 10)

	# Use CombatRules for movement speed (players faster than enemies)
	var base_attack_speed = source_data.get("base_as", 1.0)  # Attacks per second

	# Speed will be set based on team after unit is created
	var move_speed = CombatRules.BASE_PLAYER_SPEED  # Default, will be adjusted
	# Minimum 1 second cooldown between attacks
	var attack_cooldown = max(1.0, 1.0 / base_attack_speed)

	var unit = {
		"id": unit_id,
		"name": source_data.get("character_name", source_data.get("name", "Unit")),
		"team": team,
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"facing": "down",
		"hp": hp,
		"max_hp": max_hp,
		"mp": mp,
		"max_mp": max_mp,
		"energy": energy,
		"max_energy": max_energy,
		"dex": dex,
		"move_speed": move_speed,
		"attack_cooldown": attack_cooldown,
		"cooldown_timer": 0.0,
		"combat_role": source_data.get("combat_role", "melee"),
		"attack_range": _get_attack_range(source_data.get("combat_role", "melee")),
		"size": source_data.get("size", "standard"),
		"state": "idle",  # idle, moving, attacking, dead
		"target_id": "",
		"is_player_controlled": false,
		"is_captain": false,
		"archetype": "AGGRESSIVE",
		"peer_id": -1,
		"base_stats": base_stats,
		"weaknesses": source_data.get("weaknesses", {}),
		"damage_type": source_data.get("damage_type", "physical"),
		"source_data": source_data
	}

	# Initialize combat rules fields (attack state system)
	CombatRules.init_combat_fields(unit)

	# Set movement speed based on team (players faster than enemies)
	unit.move_speed = CombatRules.get_unit_speed(unit)

	return unit

func _get_attack_range(combat_role: String) -> float:
	match combat_role:
		"melee": return 100.0  # Increased for better gameplay
		"hybrid": return 180.0
		"caster": return 280.0
		"ranged": return 350.0
	return 100.0

## ========== BATTLE PROCESSING ==========

func _process_battle(battle: Dictionary, delta: float) -> void:
	"""Main battle tick - process all units"""
	var units = battle.units

	# Update grace period timer
	if battle.grace_timer > 0:
		battle.grace_timer -= delta

	for unit_id in units.keys():
		var unit = units[unit_id]
		if unit.state == "dead":
			continue

		# Update timers
		unit.cooldown_timer = max(0, unit.cooldown_timer - delta)

		# Process invincibility timer
		CombatRules.process_invincibility(unit, delta)

		# Process resource regeneration (energy + mana)
		CombatRules.process_resource_regen(unit, delta)

		# Process dodge roll cooldown
		CombatRules.process_dodge_cooldown(unit, delta)

		# Process dodge roll movement (overrides normal movement)
		var roll_velocity = CombatRules.process_dodge_roll(unit, delta)
		if roll_velocity.length() > 0:
			unit.position += roll_velocity * delta
			_clamp_unit_to_arena(unit, battle.arena_pixels)

		# Process knockback movement
		if CombatRules.process_knockback(unit, delta):
			# Apply knockback velocity (overrides normal movement)
			var kb_vel = unit.get("knockback_velocity", Vector2.ZERO)
			unit.position += kb_vel * delta
			_clamp_unit_to_arena(unit, battle.arena_pixels)

		# Process attack state machine (wind-up -> attack -> recovery)
		var attack_event = CombatRules.process_attack_state(unit, delta)
		if attack_event == "execute_attack":
			# Wind-up complete - execute the actual attack
			var target = battle.units.get(unit.get("attack_target_id", ""))
			if target and target.state != "dead":
				_execute_attack(battle, unit, target)
			else:
				# Target died or invalid, cancel attack
				CombatRules.cancel_attack(unit)

		# Process AI for non-player units (only after grace period)
		if not unit.is_player_controlled:
			if battle.grace_timer <= 0:
				RealtimeCombatAI.process_unit_ai(battle, unit, delta, _ai_callbacks)
			else:
				# During grace period, NPCs stand still
				unit.velocity = Vector2.ZERO
				unit.state = "idle"

		# Apply movement (normalize velocity to prevent speed exploits)
		# Use CombatRules.can_move() to block movement during attack sequence
		if unit.velocity.length() > 0 and CombatRules.can_move(unit):
			var normalized_velocity = unit.velocity.normalized() * min(unit.velocity.length(), unit.move_speed)
			var new_position = unit.position + normalized_velocity * delta

			# Unit collision DISABLED - will be used as spell/ability later
			# For now, all units can pass through each other freely
			# var collision = _check_unit_collision(battle, unit, new_position)
			# if collision.collided:
			# 	new_position = _resolve_collision(unit.position, new_position, collision)

			unit.position = new_position
			_clamp_unit_to_arena(unit, battle.arena_pixels)

	# Check victory/defeat conditions
	_check_battle_end_conditions(battle)

func _check_unit_collision(battle: Dictionary, moving_unit: Dictionary, new_pos: Vector2) -> Dictionary:
	"""Check if moving to new_pos would collide with another unit"""
	for unit_id in battle.units:
		var other = battle.units[unit_id]
		if other.id == moving_unit.id or other.state == "dead":
			continue

		var distance = new_pos.distance_to(other.position)
		var min_distance = UNIT_COLLISION_RADIUS * 2  # Both units have radius

		if distance < min_distance:
			return {
				"collided": true,
				"other_unit": other,
				"overlap": min_distance - distance,
				"direction": (new_pos - other.position).normalized()
			}

	return {"collided": false}

func _resolve_collision(old_pos: Vector2, new_pos: Vector2, collision: Dictionary) -> Vector2:
	"""Resolve collision by pushing unit away from collision"""
	var push_dir = collision.direction
	if push_dir.length() < 0.1:
		push_dir = Vector2(1, 0)  # Default push direction

	# Push back to minimum distance
	var other_pos = collision.other_unit.position
	var min_distance = UNIT_COLLISION_RADIUS * 2
	var resolved_pos = other_pos + push_dir * min_distance

	# Blend between old position and resolved position for smoother movement
	return old_pos.lerp(resolved_pos, 0.5)

func _clamp_unit_to_arena(unit: Dictionary, arena_pixels: Vector2) -> void:
	"""Keep unit within map bounds with proper padding"""
	unit.position.x = clamp(unit.position.x, MAP_EDGE_PADDING, arena_pixels.x - MAP_EDGE_PADDING)
	unit.position.y = clamp(unit.position.y, MAP_EDGE_PADDING, arena_pixels.y - MAP_EDGE_PADDING)

## ========== COMBAT LOGIC ==========

func _execute_attack(battle: Dictionary, attacker: Dictionary, target: Dictionary) -> void:
	"""Calculate and apply damage with balanced combat rules"""
	# Base damage from SharedBattleCalculator
	var base_damage = SharedBattleCalculator.calculate_damage(
		attacker.source_data,
		target.source_data,
		-1, -1,
		attacker.team == "enemy"
	)

	# Apply hits-to-kill balance to make combat predictable
	var damage = CombatRules.calculate_balanced_damage(base_damage, attacker, target)

	# Apply flanking bonus
	var flank_type = _get_flank_type(attacker, target)
	var flank_mult = _get_flank_multiplier(flank_type)
	damage = int(damage * flank_mult)

	# Apply weakness
	var weakness_mult = _get_weakness_multiplier(attacker.damage_type, target.weaknesses)
	damage = int(damage * weakness_mult)

	# Dodge roll grants invincibility - damage is handled by invincibility frames in CombatRules

	# Apply damage with invincibility check (dodge roll gives iframes)
	var actual_damage = CombatRules.apply_damage(target, damage)

	# Notify clients (use actual_damage which may be 0 if invincible)
	_broadcast_damage_event(battle, attacker.id, target.id, actual_damage, flank_type)

	# Check death
	if target.hp <= 0:
		target.hp = 0
		target.state = "dead"
		_broadcast_unit_death(battle, target.id)

		# Check if captain died
		if target.is_captain:
			var result = "victory" if target.team == "enemy" else "defeat"
			end_battle(battle.id, result)

func _get_flank_type(attacker: Dictionary, defender: Dictionary) -> String:
	"""Determine flank type: front, side, or back"""
	var to_attacker = (attacker.position - defender.position).normalized()
	var defender_facing = _get_facing_vector(defender.facing)

	var dot = to_attacker.dot(defender_facing)

	if dot > 0.5:
		return "front"
	elif dot < -0.5:
		return "back"
	else:
		return "side"

func _get_flank_multiplier(flank_type: String) -> float:
	match flank_type:
		"front": return FLANK_FRONT
		"side": return FLANK_SIDE
		"back": return FLANK_BACK
	return FLANK_FRONT

func _get_weakness_multiplier(damage_type: String, weaknesses: Dictionary) -> float:
	return weaknesses.get(damage_type, 1.0)

func _get_facing_vector(facing: String) -> Vector2:
	match facing:
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN

func _update_facing_from_velocity(unit: Dictionary) -> void:
	"""Update facing direction based on velocity"""
	if unit.velocity.length() < 1.0:
		return

	if abs(unit.velocity.x) > abs(unit.velocity.y):
		unit.facing = "right" if unit.velocity.x > 0 else "left"
	else:
		unit.facing = "down" if unit.velocity.y > 0 else "up"

func _face_target(unit: Dictionary, target_pos: Vector2) -> void:
	"""Face toward a target position"""
	var to_target = target_pos - unit.position

	if abs(to_target.x) > abs(to_target.y):
		unit.facing = "right" if to_target.x > 0 else "left"
	else:
		unit.facing = "down" if to_target.y > 0 else "up"

func _is_facing_target(unit: Dictionary, target_pos: Vector2) -> bool:
	"""Check if unit is facing toward the target (cardinal direction only)"""
	var to_target = target_pos - unit.position
	var facing_vec = _get_facing_vector(unit.facing)

	# Calculate dot product to see if facing toward target
	var dot = to_target.normalized().dot(facing_vec)

	# Must be facing generally toward target (dot > 0.3 allows some tolerance)
	return dot > 0.3

## ========== VICTORY/DEFEAT ==========

func _check_battle_end_conditions(battle: Dictionary) -> void:
	"""Check if battle should end"""
	if battle.state != "active":
		return

	var player_team_alive = false
	var enemy_team_alive = false

	for unit in battle.units.values():
		if unit.state != "dead" and unit.hp > 0:
			if unit.team == "player":
				player_team_alive = true
			else:
				enemy_team_alive = true

	if not enemy_team_alive:
		end_battle(battle.id, "victory")
	elif not player_team_alive:
		end_battle(battle.id, "defeat")

func _calculate_rewards(battle: Dictionary) -> Dictionary:
	"""Calculate XP and gold rewards"""
	# For now, simple fixed rewards
	# TODO: Use CombatManager.calculate_rewards() for full implementation
	return {
		"xp": 50,
		"gold": 25
	}

## ========== PLAYER INPUT HANDLING ==========

func handle_player_movement(peer_id: int, velocity: Vector2) -> void:
	"""Process player movement input"""
	var battle = get_battle_for_peer(peer_id)
	if battle.is_empty():
		return

	var unit = battle.units.get(battle.player_unit_id)
	if not unit or unit.state == "dead":
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

func handle_player_attack(peer_id: int, target_id: String) -> void:
	"""Process player attack input"""
	var battle = get_battle_for_peer(peer_id)
	if battle.is_empty():
		print("[RT_COMBAT] Attack rejected: no battle for peer %d" % peer_id)
		return

	var unit = battle.units.get(battle.player_unit_id)
	if not unit or unit.state == "dead":
		print("[RT_COMBAT] Attack rejected: no unit or dead")
		return

	# Can't attack while dodge rolling
	if CombatRules.is_dodge_rolling(unit):
		print("[RT_COMBAT] Attack rejected: dodge rolling")
		return

	# Check cooldown (minimum 1 second enforced)
	if unit.cooldown_timer > 0:
		print("[RT_COMBAT] Attack rejected: cooldown %.2f remaining" % unit.cooldown_timer)
		return

	var target = battle.units.get(target_id)
	if not target or target.state == "dead" or target.team == unit.team:
		print("[RT_COMBAT] Attack rejected: invalid target %s" % target_id)
		return

	# Check range
	var distance = unit.position.distance_to(target.position)
	if distance > unit.attack_range:
		print("[RT_COMBAT] Attack rejected: out of range (dist=%.1f, range=%.1f)" % [distance, unit.attack_range])
		return

	# Check if aligned on cardinal direction to target
	var attack_position = RealtimeCombatAI.get_cardinal_attack_position(unit, target)
	if not attack_position.aligned:
		print("[RT_COMBAT] Attack rejected: not aligned (need cardinal direction)")
		return

	# Use combat rules to check if attack can start (includes max attackers check)
	var can_attack = CombatRules.can_start_attack(unit, battle, target_id)
	if not can_attack.allowed:
		print("[RT_COMBAT] Attack rejected: %s" % can_attack.reason)
		return

	# Face target automatically when attacking
	_face_target(unit, target.position)

	# Start attack with wind-up (doesn't execute immediately)
	CombatRules.start_attack(unit, target_id)
	print("[RT_COMBAT] Attack started (wind-up): %s -> %s" % [unit.id, target_id])

func handle_player_dodge_roll(peer_id: int, direction_x: float, direction_y: float) -> void:
	"""Process player dodge roll input"""
	var battle = get_battle_for_peer(peer_id)
	if battle.is_empty():
		return

	var unit = battle.units.get(battle.player_unit_id)
	if not unit or unit.state == "dead":
		return

	# Check if can dodge roll (pass battle for enemy proximity check)
	var can_roll = CombatRules.can_dodge_roll(unit, battle)
	if not can_roll.allowed:
		print("[RT_COMBAT] Dodge roll rejected: %s" % can_roll.reason)
		return

	# Start the dodge roll (rolls in facing direction)
	var direction = Vector2(direction_x, direction_y)
	CombatRules.start_dodge_roll(unit, direction)

	# Get actual roll direction for broadcast (based on facing)
	var actual_direction = unit.get("dodge_roll_direction", direction)
	print("[RT_COMBAT] Dodge roll started: %s direction=%s" % [unit.id, actual_direction])

	# Notify clients
	_broadcast_dodge_roll_event(battle, unit.id, actual_direction)

## ========== NETWORK BROADCASTING ==========

func _broadcast_all_battle_states() -> void:
	"""Send state updates to all battle participants"""
	for battle in active_battles.values():
		if battle.state != "active":
			continue
		_broadcast_battle_state(battle)

func _broadcast_battle_state(battle: Dictionary) -> void:
	"""Send unit states to participants"""
	var units_state = []
	for unit in battle.units.values():
		units_state.append({
			"id": unit.id,
			"position": unit.position,
			"velocity": unit.velocity,
			"facing": unit.facing,
			"hp": unit.hp,
			"mp": unit.get("mp", 0),
			"energy": unit.get("energy", 0),
			"state": unit.state,
			"is_dodge_rolling": unit.get("is_dodge_rolling", false),
			"attack_state": unit.get("attack_state", ""),  # winding_up, attacking, recovering
			"attack_target_id": unit.get("attack_target_id", "")
		})

	for peer_id in battle.participants:
		if network_handler:
			network_handler.rt_state_update.rpc_id(peer_id, units_state)

func _broadcast_damage_event(battle: Dictionary, attacker_id: String, target_id: String, damage: int, flank_type: String) -> void:
	"""Notify clients of damage"""
	for peer_id in battle.participants:
		if network_handler:
			network_handler.rt_damage_event.rpc_id(peer_id, attacker_id, target_id, damage, flank_type)

func _broadcast_unit_death(battle: Dictionary, unit_id: String) -> void:
	"""Notify clients of unit death"""
	for peer_id in battle.participants:
		if network_handler:
			network_handler.rt_unit_death.rpc_id(peer_id, unit_id)

func _broadcast_dodge_roll_event(battle: Dictionary, unit_id: String, direction: Vector2) -> void:
	"""Notify clients of dodge roll activation"""
	for peer_id in battle.participants:
		if network_handler:
			network_handler.rt_dodge_roll_event.rpc_id(peer_id, unit_id, direction.x, direction.y)

func _send_battle_start(peer_id: int, battle: Dictionary) -> void:
	"""Send battle start to client"""
	if not network_handler:
		return

	# Get player's world position for map tile capture
	var player_position = Vector2.ZERO
	if player_manager:
		var player_data = player_manager.get_player_data(peer_id)
		if player_data:
			player_position = player_data.get("position", Vector2.ZERO)

	# Build client-friendly battle data
	var battle_data = {
		"id": battle.id,
		"arena_pixels": battle.arena_pixels,
		"player_unit_id": battle.player_unit_id,
		"player_position": player_position,  # For map tile capture on client
		"battle_map_name": battle.get("battle_map_name", "sample_map"),  # Map to load on client
		"player_move_speed": 300.0,  # Base move speed for player
		"units": {}
	}

	# Include unit data
	for unit_id in battle.units:
		var unit = battle.units[unit_id]
		var unit_data = {
			"id": unit.id,
			"name": unit.name,
			"team": unit.team,
			"position": unit.position,
			"facing": unit.facing,
			"hp": unit.hp,
			"max_hp": unit.max_hp,
			"mp": unit.mp,
			"max_mp": unit.max_mp,
			"energy": unit.energy,
			"max_energy": unit.max_energy,
			"state": unit.state,
			"is_player_controlled": unit.is_player_controlled,
			"is_dodge_rolling": unit.get("is_dodge_rolling", false),
			"class_name": unit.source_data.get("class_name", ""),
			"npc_type": unit.source_data.get("npc_type", unit.source_data.get("name", ""))
		}

		# Include animations if available in source data
		if unit.source_data.has("animations"):
			unit_data["animations"] = unit.source_data.animations

		battle_data.units[unit_id] = unit_data

	network_handler.rt_battle_start.rpc_id(peer_id, battle_data)

func _send_battle_end(peer_id: int, battle_id: int, result: String, rewards: Dictionary) -> void:
	"""Send battle end notification"""
	if network_handler:
		# Check if peer is still connected before sending
		var peers = multiplayer.get_peers()
		if peer_id in peers:
			network_handler.rt_battle_end.rpc_id(peer_id, battle_id, result, rewards)
		else:
			print("[RT_COMBAT] Skipping battle_end for disconnected peer: %d" % peer_id)
