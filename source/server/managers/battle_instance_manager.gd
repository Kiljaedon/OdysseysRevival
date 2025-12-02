extends Node
## Battle Instance Manager - Handles isolated battle instances
## Works alongside RealtimeCombatManager to provide instance isolation
##
## Responsibilities:
##   - Create/destroy battle instances
##   - Track which players are in which instances
##   - Freeze world NPCs during battles
##   - Generate spawn positions based on who attacked first

class_name BattleInstanceManager

## Dependencies
var battle_map_loader: BattleMapLoader = null
var player_manager = null
var npc_manager = null

## Instance tracking
var active_instances: Dictionary = {}  # instance_id -> instance_data
var player_to_instance: Dictionary = {}  # peer_id -> instance_id
var npc_in_battle: Dictionary = {}  # world_npc_id -> instance_id

## Instance counter for unique IDs
var next_instance_id: int = 1


func _ready() -> void:
	print("[BattleInstanceManager] Initialized")


func initialize(p_battle_map_loader: BattleMapLoader, p_player_manager, p_npc_manager) -> void:
	"""Initialize with required dependencies"""
	battle_map_loader = p_battle_map_loader
	player_manager = p_player_manager
	npc_manager = p_npc_manager
	print("[BattleInstanceManager] Dependencies set")


## ========== INSTANCE CREATION ==========

func create_instance(peer_id: int, world_npc_id: int, world_map_name: String, ally_count: int = 1, enemy_count: int = 1, player_is_aggressor: bool = true) -> Dictionary:
	"""Create a new battle instance for a player vs NPC encounter.

	Args:
		peer_id: The player's network ID
		world_npc_id: The NPC being fought
		world_map_name: Map where battle takes place
		ally_count: Player + mercenaries (1-4)
		enemy_count: Number of enemies (1-3)
		player_is_aggressor: True if player attacked first (gets bottom spawn)

	Returns instance data with spawn points."""

	# Check if player already in a battle
	if player_to_instance.has(peer_id):
		print("[BattleInstanceManager] Player %d already in battle" % peer_id)
		return {}

	# Check if NPC already in a battle
	if npc_in_battle.has(world_npc_id):
		print("[BattleInstanceManager] NPC %d already in battle" % world_npc_id)
		return {}

	var instance_id = "battle_%d" % next_instance_id
	next_instance_id += 1

	# Generate spawn positions based on aggressor
	var spawns = battle_map_loader.generate_battle_spawns(
		world_map_name,
		ally_count,
		enemy_count,
		player_is_aggressor
	)

	var instance = {
		"instance_id": instance_id,
		"world_map": world_map_name,
		"players": [peer_id],
		"world_npc_id": world_npc_id,
		"player_is_aggressor": player_is_aggressor,
		"ally_spawns": spawns.ally_spawns,
		"enemy_spawns": spawns.enemy_spawns,
		"ally_facing": spawns.ally_facing,
		"enemy_facing": spawns.enemy_facing,
		"map_bounds": spawns.map_bounds,
		"is_pvp": false,
		"state": "active",
		"created_at": Time.get_ticks_msec()
	}

	# Track the instance
	active_instances[instance_id] = instance
	player_to_instance[peer_id] = instance_id
	npc_in_battle[world_npc_id] = instance_id

	# Freeze world NPC
	_freeze_world_npc(world_npc_id)

	print("[BattleInstanceManager] Created instance %s for peer %d vs NPC %d" % [instance_id, peer_id, world_npc_id])
	print("[BattleInstanceManager]   Player is aggressor: %s" % player_is_aggressor)
	print("[BattleInstanceManager]   Ally spawns: %d positions" % spawns.ally_spawns.size())
	print("[BattleInstanceManager]   Enemy spawns: %d positions" % spawns.enemy_spawns.size())

	return instance


func create_pvp_instance(challenger_id: int, target_id: int, world_map_name: String, challenger_ally_count: int = 1, target_ally_count: int = 1) -> Dictionary:
	"""Create a battle instance for PvP between two players.
	Challenger is always the aggressor (gets bottom spawn)."""

	# Check if either player already in battle
	if player_to_instance.has(challenger_id):
		print("[BattleInstanceManager] Challenger %d already in battle" % challenger_id)
		return {}
	if player_to_instance.has(target_id):
		print("[BattleInstanceManager] Target %d already in battle" % target_id)
		return {}

	var instance_id = "pvp_%d" % next_instance_id
	next_instance_id += 1

	# Challenger attacked first, so they get bottom (aggressor position)
	var spawns = battle_map_loader.generate_battle_spawns(
		world_map_name,
		challenger_ally_count,  # Challenger's team as "allies"
		target_ally_count,      # Target's team as "enemies"
		true  # Challenger is aggressor
	)

	var instance = {
		"instance_id": instance_id,
		"world_map": world_map_name,
		"players": [challenger_id, target_id],
		"challenger_id": challenger_id,
		"target_id": target_id,
		"world_npc_id": -1,
		"challenger_spawns": spawns.ally_spawns,
		"target_spawns": spawns.enemy_spawns,
		"challenger_facing": spawns.ally_facing,
		"target_facing": spawns.enemy_facing,
		"map_bounds": spawns.map_bounds,
		"is_pvp": true,
		"state": "active",
		"created_at": Time.get_ticks_msec()
	}

	active_instances[instance_id] = instance
	player_to_instance[challenger_id] = instance_id
	player_to_instance[target_id] = instance_id

	print("[BattleInstanceManager] Created PvP instance %s: peer %d vs peer %d" % [instance_id, challenger_id, target_id])

	return instance


## ========== INSTANCE QUERIES ==========

func get_instance(instance_id: String) -> Dictionary:
	"""Get instance data by ID"""
	return active_instances.get(instance_id, {})


func get_player_instance(peer_id: int) -> Dictionary:
	"""Get the battle instance a player is in"""
	var instance_id = player_to_instance.get(peer_id, "")
	if instance_id:
		return active_instances.get(instance_id, {})
	return {}


func is_player_in_battle(peer_id: int) -> bool:
	"""Check if a player is currently in a battle"""
	return player_to_instance.has(peer_id)


func is_npc_in_battle(npc_id: int) -> bool:
	"""Check if a world NPC is currently in a battle"""
	return npc_in_battle.has(npc_id)


func get_instance_for_npc(npc_id: int) -> String:
	"""Get the instance ID that a world NPC is in"""
	return npc_in_battle.get(npc_id, "")


## ========== INSTANCE DESTRUCTION ==========

func end_instance(instance_id: String, result: String = "ended") -> void:
	"""End a battle instance and clean up"""
	if not active_instances.has(instance_id):
		return

	var instance = active_instances[instance_id]
	instance.state = result

	# Release players
	for peer_id in instance.players:
		if player_to_instance.get(peer_id) == instance_id:
			player_to_instance.erase(peer_id)

	# Release and handle world NPC
	var world_npc_id = instance.world_npc_id
	if world_npc_id >= 0 and npc_in_battle.has(world_npc_id):
		npc_in_battle.erase(world_npc_id)

		if result == "victory":
			# NPC defeated - remove from world or respawn later
			_handle_npc_defeated(world_npc_id)
		else:
			# Player fled or lost - unfreeze NPC
			_unfreeze_world_npc(world_npc_id)

	active_instances.erase(instance_id)
	print("[BattleInstanceManager] Instance %s ended: %s" % [instance_id, result])


func end_instance_for_player(peer_id: int, result: String = "ended") -> void:
	"""End the battle instance a player is in"""
	var instance_id = player_to_instance.get(peer_id, "")
	if instance_id:
		end_instance(instance_id, result)


## ========== WORLD NPC MANAGEMENT ==========

func _freeze_world_npc(npc_id: int) -> void:
	"""Freeze a world NPC while in battle (stop movement/AI)"""
	if npc_manager and npc_manager.has_method("freeze_npc"):
		npc_manager.freeze_npc(npc_id)
	print("[BattleInstanceManager] Froze world NPC %d" % npc_id)


func _unfreeze_world_npc(npc_id: int) -> void:
	"""Unfreeze a world NPC after battle"""
	if npc_manager and npc_manager.has_method("unfreeze_npc"):
		npc_manager.unfreeze_npc(npc_id)
	print("[BattleInstanceManager] Unfroze world NPC %d" % npc_id)


func _handle_npc_defeated(npc_id: int) -> void:
	"""Handle NPC being defeated - remove or mark for respawn"""
	if npc_manager and npc_manager.has_method("handle_npc_defeated"):
		npc_manager.handle_npc_defeated(npc_id)
	else:
		# Fallback: just unfreeze (NPC stays alive)
		_unfreeze_world_npc(npc_id)
	print("[BattleInstanceManager] NPC %d defeated" % npc_id)


## ========== CLEANUP ==========

func cleanup_player(peer_id: int) -> void:
	"""Clean up when a player disconnects"""
	if player_to_instance.has(peer_id):
		var instance_id = player_to_instance[peer_id]
		end_instance(instance_id, "disconnected")


func get_active_instance_count() -> int:
	"""Get number of active battle instances"""
	return active_instances.size()


func get_debug_info() -> Dictionary:
	"""Get debug information about active instances"""
	return {
		"active_instances": active_instances.size(),
		"players_in_battle": player_to_instance.size(),
		"npcs_in_battle": npc_in_battle.size()
	}
