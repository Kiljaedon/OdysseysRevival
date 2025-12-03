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
		if network_handler:
			network_handler.rt_state_update.rpc_id(peer_id, units_state)

static func broadcast_damage_event(battle: Dictionary, attacker_id: String, target_id: String, damage: int, flank_type: String, network_handler: Node) -> void:
	"""Notify clients of damage"""
	for peer_id in battle.participants:
		if network_handler:
			network_handler.rt_damage_event.rpc_id(peer_id, attacker_id, target_id, damage, flank_type)

static func broadcast_unit_death(battle: Dictionary, unit_id: String, network_handler: Node) -> void:
	"""Notify clients of unit death"""
	for peer_id in battle.participants:
		if network_handler:
			network_handler.rt_unit_death.rpc_id(peer_id, unit_id)

static func broadcast_dodge_roll_event(battle: Dictionary, unit_id: String, direction: Vector2, network_handler: Node) -> void:
	"""Notify clients of dodge roll activation"""
	for peer_id in battle.participants:
		if network_handler:
			network_handler.rt_dodge_roll_event.rpc_id(peer_id, unit_id, direction.x, direction.y)

static func send_battle_start(peer_id: int, battle: Dictionary, player_manager: Node, network_handler: Node) -> void:
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

static func send_battle_end(peer_id: int, battle_id: int, result: String, rewards: Dictionary, network_handler: Node, multiplayer_api: MultiplayerAPI) -> void:
	"""Send battle end notification"""
	if network_handler:
		# Check if peer is still connected before sending
		var peers = multiplayer_api.get_peers()
		if peer_id in peers:
			network_handler.rt_battle_end.rpc_id(peer_id, battle_id, result, rewards)
		else:
			print("[RT_COMBAT] Skipping battle_end for disconnected peer: %d" % peer_id)
