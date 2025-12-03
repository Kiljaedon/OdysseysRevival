extends Node
## Realtime Combat Manager - Server-authoritative real-time battle system
## Handles battle instances, unit state, AI, damage, and victory/defeat
## WARNING: File at 450-line capacity - extract new features to separate files

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

## ========== IMPORTS ==========
const StatsCalculator = preload("res://source/common/combat/stats_calculator.gd")
const ElementalSystem = preload("res://source/common/combat/elemental_system.gd")
const RealTimeCombatSpawner = preload("res://source/server/managers/combat/realtime_combat_spawner.gd")
const RealTimeCombatNetwork = preload("res://source/server/managers/combat/realtime_combat_network.gd")
const RealTimeCombatInput = preload("res://source/server/managers/combat/realtime_combat_input.gd")

## ========== BATTLE STATE ==========
var active_battles: Dictionary = {}  # battle_id -> battle data
var next_battle_id: int = 1
var state_update_timer: float = 0.0

## AI callback references (passed to RealtimeCombatAI)
var _ai_callbacks: Dictionary = {}

## ========== LIFECYCLE ==========

func _ready():
	print("[RT_COMBAT] RealtimeCombatManager ready")
	# Setup AI callbacks - Delegate to Input class static helpers
	_ai_callbacks = {
		"update_facing_from_velocity": func(u): RealTimeCombatInput._update_facing_from_velocity(u),
		"face_target": func(u, t): RealTimeCombatInput._face_target(u, t),
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
		# Use delegated Network component
		RealTimeCombatNetwork.broadcast_all_battle_states(active_battles, network_handler)

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

	# Spawn units using delegated Spawner
	RealTimeCombatSpawner.spawn_player_unit(battle, peer_id, player_data, player_world_pos)
	RealTimeCombatSpawner.spawn_squad_units(battle, peer_id, squad_data, player_world_pos, map_width, map_height)
	RealTimeCombatSpawner.spawn_enemy_units(battle, enemy_data, player_world_pos, map_width, map_height)

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

	# Send battle start to client via Network component
	RealTimeCombatNetwork.send_battle_start(peer_id, battle, player_manager, network_handler)

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

	# Notify participants via Network component
	for peer_id in battle.participants:
		RealTimeCombatNetwork.send_battle_end(peer_id, battle_id, result, rewards, network_handler, multiplayer)

	# Clean up after short delay (let clients process)
	await get_tree().create_timer(2.0).timeout
	active_battles.erase(battle_id)

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

		# Process combo window timer
		CombatRules.process_combo_window(unit, delta)

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

		# Process lunge movement (Fluid Combat)
		var lunge_vel = CombatRules.process_lunge(unit, delta)
		if lunge_vel.length() > 0:
			unit.position += lunge_vel * delta
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
		if unit.velocity.length() > 0 and CombatRules.can_move(unit):
			var normalized_velocity = unit.velocity.normalized() * min(unit.velocity.length(), unit.move_speed)
			unit.position += normalized_velocity * delta
			_clamp_unit_to_arena(unit, battle.arena_pixels)

	# Check victory/defeat conditions
	_check_battle_end_conditions(battle)

func _clamp_unit_to_arena(unit: Dictionary, arena_pixels: Vector2) -> void:
	"""Keep unit within map bounds with proper padding"""
	unit.position.x = clamp(unit.position.x, MAP_EDGE_PADDING, arena_pixels.x - MAP_EDGE_PADDING)
	unit.position.y = clamp(unit.position.y, MAP_EDGE_PADDING, arena_pixels.y - MAP_EDGE_PADDING)

## ========== COMBAT LOGIC ==========

func _execute_attack(battle: Dictionary, attacker: Dictionary, target: Dictionary) -> void:
	"""Calculate and apply damage with balanced combat rules"""
	
	# 1. Calculate Base Damage (Stats)
	var base_damage: float = 0.0
	var damage_type = attacker.get("damage_type", "physical")
	
	if damage_type == "magical":
		# TODO: Pass spell power if this was a spell
		base_damage = StatsCalculator.calculate_magic_damage(
			attacker.base_stats, 
			target.base_stats
		)
	else:
		# Physical attack
		var weapon_power = attacker.source_data.get("weapon_power", 0)
		base_damage = StatsCalculator.calculate_physical_damage(
			attacker.base_stats, 
			target.base_stats,
			weapon_power
		)

	# 2. Apply Element (Weakness/Resistance)
	var attacker_element = attacker.source_data.get("element", "Neutral")
	var target_element = target.source_data.get("element", "Neutral")
	var elem_mod = ElementalSystem.get_elemental_modifier(attacker_element, target_element)
	
	# Apply elemental modifier to base damage
	var damage_after_element = int(base_damage * elem_mod)
	
	# 3. Apply Game Balance (Rules) & Hits-to-Kill Logic
	var damage = CombatRules.calculate_balanced_damage(damage_after_element, attacker, target)

	# Apply flanking bonus
	var flank_type = _get_flank_type(attacker, target)
	var flank_mult = _get_flank_multiplier(flank_type)
	damage = int(damage * flank_mult)

	# Apply weakness (Monster specific weaknesses beyond elements)
	var weakness_mult = _get_weakness_multiplier(attacker.damage_type, target.weaknesses)
	damage = int(damage * weakness_mult)

	# Dodge roll grants invincibility - damage is handled by invincibility frames in CombatRules

	# Apply damage with invincibility check (dodge roll gives iframes)
	var actual_damage = CombatRules.apply_damage(target, damage)

	# Notify clients via Network component
	RealTimeCombatNetwork.broadcast_damage_event(battle, attacker.id, target.id, actual_damage, flank_type, network_handler)

	# Check death
	if target.hp <= 0:
		target.hp = 0
		target.state = "dead"
		RealTimeCombatNetwork.broadcast_unit_death(battle, target.id, network_handler)

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
	if not unit:
		return
		
	RealTimeCombatInput.handle_player_movement(battle, unit, velocity)

func handle_player_attack(peer_id: int, target_id: String) -> void:
	"""Process player attack input"""
	var battle = get_battle_for_peer(peer_id)
	if battle.is_empty():
		print("[RT_COMBAT] Attack rejected: no battle for peer %d" % peer_id)
		return

	var unit = battle.units.get(battle.player_unit_id)
	if not unit:
		return
		
	RealTimeCombatInput.handle_player_attack(battle, unit, target_id)

func handle_player_dodge_roll(peer_id: int, direction_x: float, direction_y: float) -> void:
	"""Process player dodge roll input"""
	var battle = get_battle_for_peer(peer_id)
	if battle.is_empty():
		return

	var unit = battle.units.get(battle.player_unit_id)
	if not unit:
		return
		
	var result = RealTimeCombatInput.handle_player_dodge_roll(battle, unit, direction_x, direction_y)
	if result.success:
		# Notify clients via Network component
		RealTimeCombatNetwork.broadcast_dodge_roll_event(battle, unit.id, result.actual_direction, network_handler)

func handle_player_defend(peer_id: int) -> void:
	"""Process player defend input"""
	var battle = get_battle_for_peer(peer_id)
	if battle.is_empty():
		return

	var unit = battle.units.get(battle.player_unit_id)
	if not unit:
		return
		
	RealTimeCombatInput.handle_player_defend(battle, unit)

