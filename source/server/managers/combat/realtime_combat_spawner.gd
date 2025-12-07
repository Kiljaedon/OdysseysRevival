class_name RealTimeCombatSpawner
extends RefCounted

## ========== IMPORTS ==========
const CombatRules = preload("res://source/server/managers/combat_rules.gd")
const CombatRoles = preload("res://source/server/managers/combat/combat_roles.gd")

## ========== CONSTANTS ==========
const BATTLE_TILE_SPACING: int = 12
const TILE_SIZE_SCALED: int = 128
const BATTLE_SPAWN_DISTANCE: int = BATTLE_TILE_SPACING * TILE_SIZE_SCALED
const MAP_EDGE_PADDING: float = 128.0

## ========== MAP MANAGER REFERENCE ==========
## Used for collision-free spawn validation
static var _map_manager = null

static func set_map_manager(map_mgr) -> void:
	"""Set map manager reference for collision validation during spawning"""
	_map_manager = map_mgr

static func _validate_spawn_position(position: Vector2, map_name: String, map_width: int, map_height: int) -> Vector2:
	"""Validate spawn position is not in collision zone, find free spot if blocked"""
	# Clamp to bounds first
	position.x = clamp(position.x, MAP_EDGE_PADDING, map_width - MAP_EDGE_PADDING)
	position.y = clamp(position.y, MAP_EDGE_PADDING, map_height - MAP_EDGE_PADDING)

	# If map_manager available, find nearest free spawn
	if _map_manager and _map_manager.has_method("find_nearest_free_spawn"):
		position = _map_manager.find_nearest_free_spawn(map_name, position)

	return position

static func spawn_player_unit(battle: Dictionary, peer_id: int, player_data: Dictionary, player_world_pos: Vector2) -> void:
	var unit_id = "player_%d" % peer_id
	var unit = _create_unit_data(unit_id, player_data, "player")

	# VALIDATE spawn position against collision zones
	var map_name = battle.get("battle_map_name", "sample_map")
	var map_width = battle.get("map_width", 2560)
	var map_height = battle.get("map_height", 1920)
	player_world_pos = _validate_spawn_position(player_world_pos, map_name, map_width, map_height)

	unit.position = player_world_pos
	unit.facing = "up"
	unit.is_player_controlled = true
	unit.is_captain = true
	unit.peer_id = peer_id

	battle.units[unit_id] = unit
	battle.player_unit_id = unit_id
	battle.captain_id = unit_id

static func spawn_squad_units(battle: Dictionary, peer_id: int, squad_data: Array, player_world_pos: Vector2, map_width: int, map_height: int) -> void:
	var squad_offsets = [
		Vector2(-120, 0),    # Left
		Vector2(120, 0),     # Right
		Vector2(0, 80)       # Behind
	]

	# Get map name for collision validation
	var map_name = battle.get("battle_map_name", "sample_map")

	for i in range(min(squad_data.size(), squad_offsets.size())):
		var merc_data = squad_data[i]
		var unit_id = "squad_%d_%d" % [peer_id, i]

		var unit = _create_unit_data(unit_id, merc_data, "player")
		var spawn_pos = player_world_pos + squad_offsets[i]

		# VALIDATE spawn position against collision zones
		spawn_pos = _validate_spawn_position(spawn_pos, map_name, map_width, map_height)

		unit.position = spawn_pos
		unit.facing = "up"
		unit.is_player_controlled = false
		unit.peer_id = peer_id
		unit.archetype = merc_data.get("ai_archetype", "AGGRESSIVE")

		battle.units[unit_id] = unit

static func spawn_enemy_units(battle: Dictionary, enemy_data: Array, player_world_pos: Vector2, map_width: int, map_height: int) -> void:
	var enemy_base_y = player_world_pos.y - BATTLE_SPAWN_DISTANCE
	var center_x = player_world_pos.x

	enemy_base_y = max(enemy_base_y, MAP_EDGE_PADDING)

	var enemy_y_front = enemy_base_y
	var enemy_y_back = enemy_base_y - (TILE_SIZE_SCALED * 2)
	enemy_y_back = max(enemy_y_back, MAP_EDGE_PADDING)

	var enemy_positions = [
		Vector2(center_x, enemy_y_front),
		Vector2(center_x - 180, enemy_y_front),
		Vector2(center_x + 180, enemy_y_front),
		Vector2(center_x - 100, enemy_y_back),
		Vector2(center_x + 100, enemy_y_back)
	]

	# Get map name for collision validation
	var map_name = battle.get("battle_map_name", "sample_map")

	var enemy_captain_set = false

	for i in range(min(enemy_data.size(), enemy_positions.size())):
		var e_data = enemy_data[i]
		var unit_id = "enemy_%d" % i

		var unit = _create_unit_data(unit_id, e_data, "enemy")
		var spawn_pos = enemy_positions[i]

		# VALIDATE spawn position against collision zones
		spawn_pos = _validate_spawn_position(spawn_pos, map_name, map_width, map_height)

		unit.position = spawn_pos
		unit.facing = "down"
		unit.is_player_controlled = false
		unit.archetype = e_data.get("ai_archetype", "AGGRESSIVE")

		if not enemy_captain_set:
			unit.is_captain = true
			enemy_captain_set = true

		battle.units[unit_id] = unit

static func _create_unit_data(unit_id: String, source_data: Dictionary, team: String) -> Dictionary:
	var base_stats = source_data.get("base_stats", {})
	var derived_stats = source_data.get("derived_stats", {})

	var max_hp = derived_stats.get("max_hp", base_stats.get("max_hp", source_data.get("max_hp", 100)))
	var hp = source_data.get("hp", max_hp)
	var max_mp = derived_stats.get("max_mp", base_stats.get("max_mp", source_data.get("max_mp", 50)))
	var mp = source_data.get("mp", max_mp)
	var max_energy = derived_stats.get("max_ep", source_data.get("max_energy", source_data.get("energy", 100)))
	var energy = source_data.get("energy", max_energy)

	var dex = base_stats.get("dex", 10)
	var base_attack_speed = source_data.get("base_as", 1.0)

	# Default move speed (will be overridden by get_unit_speed below)
	var move_speed = 300.0
	var attack_cooldown = max(1.0, 1.0 / base_attack_speed)

	# Get combat role and its properties
	# First check source_data, then look up from class_name if player character
	var combat_role = source_data.get("combat_role", "")

	if combat_role == "":
		# Try to get combat_role from class definition
		var class_name_str = source_data.get("class_name", "")
		if class_name_str != "":
			var class_data = _load_class_data(class_name_str)
			combat_role = class_data.get("combat_role", "melee")
		else:
			combat_role = "melee"

	var attack_range = CombatRoles.get_attack_range(combat_role)
	var move_speed_mult = CombatRoles.get_move_speed_mult(combat_role)

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
		"move_speed": move_speed * move_speed_mult,  # Apply role speed modifier
		"attack_cooldown": attack_cooldown,
		"cooldown_timer": 0.0,
		"combat_role": combat_role,
		"attack_range": attack_range,
		"size": source_data.get("size", "standard"),
		"state": "idle",
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

	CombatRules.init_combat_fields(unit)
	unit.move_speed = CombatRules.get_unit_speed(unit)

	return unit

## ========== HELPER FUNCTIONS ==========

static func _load_class_data(class_name_str: String) -> Dictionary:
	"""Load class definition to get combat_role and other class-specific data"""
	var file_path = "res://characters/classes/%s.json" % class_name_str
	if not FileAccess.file_exists(file_path):
		return {"combat_role": "melee"}

	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) == OK:
		return json.data

	return {"combat_role": "melee"}
