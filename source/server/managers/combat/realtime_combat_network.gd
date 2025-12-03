class_name RealTimeCombatNetwork
extends RefCounted

static func broadcast_all_battle_states(active_battles: Dictionary, network_handler: Node) -> void:
	"""Send state updates to all battle participants"""
	for battle in active_battles.values():
		if battle.state != "active":
			continue
		_broadcast_battle_state(battle, network_handler)

static func _broadcast_battle_state(battle: Dictionary, network_handler: Node) -> void:
	"""Send unit states to participants"""
	if not network_handler:
		return

	# Get list of connected peers
	var connected_peers = network_handler.multiplayer.get_peers()

	var server_timestamp = Time.get_ticks_msec()  # Timestamp for interpolation
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
			"attack_target_id": unit.get("attack_target_id", ""),
			"server_timestamp": server_timestamp  # For client interpolation
		})

	for peer_id in battle.participants:
		# Only send to connected peers
		if peer_id in connected_peers:
			network_handler.rt_state_update.rpc_id(peer_id, units_state)

static func broadcast_damage_event(battle: Dictionary, attacker_id: String, target_id: String, damage: int, flank_type: String, network_handler: Node) -> void:
	"""Notify clients of damage"""
	if not network_handler:
		return

	var connected_peers = network_handler.multiplayer.get_peers()
	for peer_id in battle.participants:
		if peer_id in connected_peers:
			network_handler.rt_damage_event.rpc_id(peer_id, attacker_id, target_id, damage, flank_type)

static func broadcast_unit_death(battle: Dictionary, unit_id: String, network_handler: Node) -> void:
	"""Notify clients of unit death"""
	if not network_handler:
		return

	var connected_peers = network_handler.multiplayer.get_peers()
	for peer_id in battle.participants:
		if peer_id in connected_peers:
			network_handler.rt_unit_death.rpc_id(peer_id, unit_id)

static func broadcast_dodge_roll_event(battle: Dictionary, unit_id: String, direction: Vector2, network_handler: Node) -> void:
	"""Notify clients of dodge roll activation"""
	if not network_handler:
		return

	var connected_peers = network_handler.multiplayer.get_peers()
	for peer_id in battle.participants:
		if peer_id in connected_peers:
			network_handler.rt_dodge_roll_event.rpc_id(peer_id, unit_id, direction.x, direction.y)

static func send_battle_start(peer_id: int, battle: Dictionary, player_manager: Node, network_handler: Node) -> void:
	"""Send battle start to client"""
	if not network_handler:
		return

	# Check if peer is connected
	var connected_peers = network_handler.multiplayer.get_peers()
	if not peer_id in connected_peers:
		print("[RT_NETWORK] Cannot send battle_start to disconnected peer: %d" % peer_id)
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
			"combat_role": unit.get("combat_role", "melee"),  # NEEDED for client-side range checks!
			"attack_range": unit.get("attack_range", 120.0),  # NEEDED for client-side range checks!
			"class_name": unit.source_data.get("class_name", ""),
			"npc_type": unit.source_data.get("npc_type", unit.source_data.get("name", ""))
		}

		# Include animations if available in source data
		if unit.source_data.has("animations"):
			unit_data["animations"] = unit.source_data.animations

		battle_data.units[unit_id] = unit_data

	network_handler.rt_battle_start.rpc_id(peer_id, battle_data)

static func send_battle_end(peer_id: int, battle_id: int, result: String, rewards: Dictionary, network_handler: Node, multiplayer_api: MultiplayerAPI) -> void:
	"""Send battle end notification"""
	if network_handler:
		# Check if peer is still connected before sending
		var peers = multiplayer_api.get_peers()
		if peer_id in peers:
			network_handler.rt_battle_end.rpc_id(peer_id, battle_id, result, rewards)
		else:
			print("[RT_COMBAT] Skipping battle_end for disconnected peer: %d" % peer_id)

## ========== PROJECTILE BROADCASTS ==========

static func broadcast_projectile_spawn(battle: Dictionary, projectile: Dictionary, network_handler: Node) -> void:
	"""Notify clients of projectile spawn"""
	if not network_handler:
		return

	var connected_peers = network_handler.multiplayer.get_peers()
	var proj_data = {
		"id": projectile.id,
		"attacker_id": projectile.attacker_id,
		"position": projectile.position,
		"velocity": projectile.velocity,
		"texture": projectile.texture
	}

	for peer_id in battle.participants:
		if peer_id in connected_peers:
			network_handler.rt_projectile_spawn.rpc_id(peer_id, proj_data)

static func broadcast_projectile_hit(battle: Dictionary, projectile_id: String, target_id: String, hit_position: Vector2, network_handler: Node) -> void:
	"""Notify clients of projectile hit"""
	if not network_handler:
		return

	var connected_peers = network_handler.multiplayer.get_peers()
	for peer_id in battle.participants:
		if peer_id in connected_peers:
			network_handler.rt_projectile_hit.rpc_id(peer_id, projectile_id, target_id, hit_position)

static func broadcast_projectile_miss(battle: Dictionary, projectile_id: String, final_position: Vector2, network_handler: Node) -> void:
	"""Notify clients of projectile miss (despawn)"""
	if not network_handler:
		return

	var connected_peers = network_handler.multiplayer.get_peers()
	for peer_id in battle.participants:
		if peer_id in connected_peers:
			network_handler.rt_projectile_miss.rpc_id(peer_id, projectile_id, final_position)
