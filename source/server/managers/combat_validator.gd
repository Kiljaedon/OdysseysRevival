extends Node
class_name CombatValidator

## Combat Validator - Security and validation for combat system
## Extracted from CombatManager for focused responsibility
## Handles: stat validation, action validation, peer verification, bounds checking

# Constants
const ACTION_TIMEOUT_SECONDS: float = 8.0
const MAX_LEVEL: int = 100
const MIN_LEVEL: int = 1
const MAX_STAT_VALUE: int = 999
const MIN_STAT_VALUE: int = 1
const MAX_HP_VALUE: int = 99999
const MIN_HP_VALUE: int = 1

# Valid action types
const VALID_ACTIONS: Array[String] = ["attack", "defend", "skill", "item"]

# Stat names for validation
const STAT_NAMES: Array[String] = ["str", "dex", "int", "vit", "wis", "cha"]

# Dependencies (injected by CombatController)
var server_world: Node = null
var player_manager: Node = null

## ========== INITIALIZATION ==========

func initialize(world_ref: Node, player_mgr: Node) -> void:
	## Initialize validator with dependencies
	server_world = world_ref
	player_manager = player_mgr
	print("[CombatValidator] Initialized")


## ========== CHARACTER VALIDATION ==========

func validate_character_stats(character: Dictionary) -> bool:
	## Validate character stats before combat
	## Returns true if stats are valid, false otherwise
	## SECURITY: Prevents stat manipulation exploits

	# STRICT VALIDATION: Reject if stats missing
	if not character.has("stats") and not character.has("base_stats"):
		print("[CombatValidator-SECURITY] Character missing stats dictionary - REJECTED")
		return false

	# Get stats dictionary
	var stats = character.get("stats", character.get("base_stats", {}))
	var level = character.get("level", 1)

	# Validate level
	if not _validate_level(level):
		return false

	# Validate individual stats
	if not _validate_stats_values(stats):
		return false

	# Validate HP values
	if not _validate_hp(character):
		return false

	# All validations passed
	return true


func _validate_level(level: int) -> bool:
	## Validate character level is within acceptable range
	if level < MIN_LEVEL or level > MAX_LEVEL:
		print("[CombatValidator-SECURITY] Invalid level: %d (must be %d-%d)" % [level, MIN_LEVEL, MAX_LEVEL])
		return false
	return true


func _validate_stats_values(stats: Dictionary) -> bool:
	## Validate all stat values are within acceptable range
	for stat_name in STAT_NAMES:
		var stat_value = stats.get(stat_name, 10)
		if stat_value < MIN_STAT_VALUE or stat_value > MAX_STAT_VALUE:
			print("[CombatValidator-SECURITY] Invalid %s stat: %d (must be %d-%d)" % [
				stat_name, stat_value, MIN_STAT_VALUE, MAX_STAT_VALUE
			])
			return false

	return true


func _validate_hp(character: Dictionary) -> bool:
	## Validate HP values are logical and within bounds
	## SECURITY: Force integer values to prevent float exploits
	var current_hp = int(character.get("hp", 0))
	var max_hp = int(character.get("max_hp", 100))

	# Validate max_hp is within bounds
	if max_hp < MIN_HP_VALUE or max_hp > MAX_HP_VALUE:
		print("[CombatValidator-SECURITY] Invalid max_hp: %d (must be %d-%d)" % [
			max_hp, MIN_HP_VALUE, MAX_HP_VALUE
		])
		return false

	# Validate current_hp is not negative and doesn't exceed max
	if current_hp < 0 or current_hp > max_hp:
		print("[CombatValidator-SECURITY] Invalid HP: %d/%d" % [current_hp, max_hp])
		return false

	return true


## ========== ACTION VALIDATION ==========

func validate_action_type(action: String) -> bool:
	## Validate action type is one of the allowed actions
	## SECURITY: Prevents invalid action injection
	return action in VALID_ACTIONS


func sanitize_action_type(action: String, peer_id: int = -1) -> String:
	## Sanitize action type - return 'defend' if invalid
	## SECURITY: Safe fallback for invalid actions
	## Logs potential exploit attempts for monitoring
	if validate_action_type(action):
		return action
	else:
		if peer_id >= 0:
			print("[CombatValidator-SECURITY] Peer %d sent invalid action '%s' - forcing defend (potential exploit)" % [peer_id, action])
		else:
			print("[CombatValidator-SECURITY] Invalid action type '%s' - forcing defend" % action)
		return "defend"


func validate_target_index(target_index: int, squad_size: int) -> bool:
	## Validate target index is within squad bounds
	## SECURITY: Prevents out-of-bounds array access
	if target_index < 0 or target_index >= squad_size:
		print("[CombatValidator-SECURITY] Invalid target index: %d (squad size: %d)" % [target_index, squad_size])
		return false
	return true


func sanitize_target_index(target_index: int, squad_size: int, peer_id: int = -1) -> int:
	## Sanitize target index - clamp to valid range
	## SECURITY: Safe fallback for invalid targets
	## Logs potential exploit attempts for monitoring
	if target_index < 0:
		if peer_id >= 0:
			print("[CombatValidator-SECURITY] Peer %d sent negative target index %d - clamping to 0 (potential exploit)" % [peer_id, target_index])
		else:
			print("[CombatValidator] Negative target index %d - clamping to 0" % target_index)
		return 0
	elif target_index >= squad_size:
		if peer_id >= 0:
			print("[CombatValidator-SECURITY] Peer %d sent target index %d >= squad size %d - clamping (potential exploit)" % [
				peer_id, target_index, squad_size
			])
		else:
			print("[CombatValidator] Target index %d >= squad size %d - clamping to %d" % [
				target_index, squad_size, squad_size - 1
			])
		return squad_size - 1
	return target_index


## ========== PEER VALIDATION ==========

func validate_combat_ownership(combat: Dictionary, peer_id: int) -> bool:
	## Validate that peer owns this combat session
	## SECURITY: Prevents players from interfering with others' combats
	var owner_peer_id = combat.get("peer_id", -1)

	if owner_peer_id != peer_id:
		print("[CombatValidator-SECURITY] Peer %d attempted action in combat owned by peer %d - REJECTED" % [
			peer_id, owner_peer_id
		])
		return false

	return true


func validate_player_exists(peer_id: int) -> bool:
	## Validate that player with peer_id exists in player_manager
	## SECURITY: Prevents actions from disconnected/invalid players
	if not player_manager or not player_manager.connected_players.has(peer_id):
		print("[CombatValidator-SECURITY] Invalid peer_id: %d (player not connected)" % peer_id)
		return false

	return true


func validate_combat_exists(combat_id: int, combat_instances: Dictionary) -> bool:
	## Validate that combat session exists
	## SECURITY: Prevents actions on non-existent combats
	if not combat_instances.has(combat_id):
		print("[CombatValidator-SECURITY] Invalid combat_id: %d (combat doesn't exist)" % combat_id)
		return false

	return true


## ========== RATE LIMITING ==========

func check_rate_limit(peer_id: int) -> bool:
	## Check if player is rate limited (delegated to server_world)
	## SECURITY: Prevents action spam
	## FAIL CLOSED: Denies action if rate limiter unavailable
	if server_world and server_world.has_method("is_rate_limited"):
		return not server_world.is_rate_limited(peer_id)

	# SECURITY: Fail closed - deny if rate limiter unavailable
	print("[CombatValidator-SECURITY] Rate limiter unavailable - denying action from peer %d" % peer_id)
	return false


## ========== COMBAT STATE VALIDATION ==========

func validate_squad_not_empty(squad: Array) -> bool:
	## Validate that squad has at least one entity
	if squad.is_empty():
		print("[CombatValidator] ERROR: Squad is empty")
		return false
	return true


func validate_entity_alive(entity: Dictionary) -> bool:
	## Validate that entity has positive HP
	var hp = int(entity.get("hp", 0))
	return hp > 0


func get_alive_count(squad: Array) -> int:
	## Count number of alive entities in squad
	## Note: May be slow for large squads (>20 entities), consider caching
	var alive_count = 0
	for entity in squad:
		if validate_entity_alive(entity):
			alive_count += 1
	return alive_count


## ========== TIMEOUT MANAGEMENT ==========

func is_action_timeout(timer_start: float, current_time: float) -> bool:
	## Check if action has timed out
	var elapsed = current_time - timer_start
	return elapsed >= ACTION_TIMEOUT_SECONDS


func get_timeout_elapsed(timer_start: float, current_time: float) -> float:
	## Get elapsed time since timer started
	return current_time - timer_start
