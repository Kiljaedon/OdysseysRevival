class_name AntiCheat
extends Node
## Anti-cheat detection and tracking system
## Monitors player behavior and flags suspicious activity

# Cheat detection thresholds
const MAX_VIOLATIONS_BEFORE_FLAG = 100  # Increased for development
const MAX_VIOLATIONS_BEFORE_KICK = 1000  # Effectively disabled for development
const POSITION_HISTORY_SIZE = 20

# Player tracking data
var player_stats: Dictionary = {}  # peer_id -> stats dict

## ========== PLAYER TRACKING ==========

func register_player(peer_id: int):
	"""Register a new player for anti-cheat tracking"""
	player_stats[peer_id] = {
		"peer_id": peer_id,
		"violations": {
			"teleport": 0,
			"speed_hack": 0,
			"invalid_input": 0,
			"suspicious_movement": 0
		},
		"total_violations": 0,
		"position_history": [],
		"last_position": Vector2.ZERO,
		"join_time": Time.get_ticks_msec(),
		"flagged": false,
		"kicked": false
	}
	print("[ANTI_CHEAT] Registered player %d for monitoring" % peer_id)


func unregister_player(peer_id: int):
	"""Remove player from anti-cheat tracking"""
	if player_stats.has(peer_id):
		player_stats.erase(peer_id)
		print("[ANTI_CHEAT] Unregistered player %d" % peer_id)


## ========== VIOLATION TRACKING ==========

func log_violation(peer_id: int, violation_type: String, severity: int, details: Dictionary = {}):
	"""Log a cheat violation for a player"""
	if not player_stats.has(peer_id):
		register_player(peer_id)

	var stats = player_stats[peer_id]

	# Increment violation counter
	if stats.violations.has(violation_type):
		stats.violations[violation_type] += severity
	else:
		stats.violations[violation_type] = severity

	stats.total_violations += severity

	# Anti-cheat logging disabled - only log critical kicks
	# (Validation too strict for normal gameplay)

	# Check if should be flagged
	if stats.total_violations >= MAX_VIOLATIONS_BEFORE_FLAG and not stats.flagged:
		flag_player(peer_id, violation_type)

	# Check if should be kicked
	if stats.total_violations >= MAX_VIOLATIONS_BEFORE_KICK and not stats.kicked:
		return kick_player(peer_id, violation_type)

	return false  # Not kicked


func flag_player(peer_id: int, reason: String):
	"""Flag player for manual review"""
	if not player_stats.has(peer_id):
		return

	var stats = player_stats[peer_id]
	stats.flagged = true

	print("[ANTI_CHEAT] ⚠️ FLAGGED peer %d for manual review: %s" % [peer_id, reason])
	print("[ANTI_CHEAT] Violations: %s" % str(stats.violations))


func kick_player(peer_id: int, reason: String) -> bool:
	"""Mark player for kick (server will handle actual disconnect)"""
	if not player_stats.has(peer_id):
		return false

	var stats = player_stats[peer_id]
	stats.kicked = true

	print("[ANTI_CHEAT] 🔴 KICK peer %d: %s" % [peer_id, reason])
	print("[ANTI_CHEAT] Total violations: %d" % stats.total_violations)
	print("[ANTI_CHEAT] Breakdown: %s" % str(stats.violations))

	return true  # Signal to server to kick this player


## ========== POSITION TRACKING ==========

func update_position_history(peer_id: int, position: Vector2):
	"""Update player's position history for pattern analysis"""
	if not player_stats.has(peer_id):
		register_player(peer_id)

	var stats = player_stats[peer_id]
	stats.position_history.append(position)

	# Keep only recent positions
	if stats.position_history.size() > POSITION_HISTORY_SIZE:
		stats.position_history.pop_front()

	stats.last_position = position


func get_position_history(peer_id: int) -> Array:
	"""Get player's recent position history"""
	if not player_stats.has(peer_id):
		return []

	return player_stats[peer_id].position_history


## ========== STATISTICS ==========

func get_player_stats(peer_id: int) -> Dictionary:
	"""Get anti-cheat stats for a player"""
	if not player_stats.has(peer_id):
		return {}

	return player_stats[peer_id].duplicate()


func get_violation_count(peer_id: int) -> int:
	"""Get total violation count for a player"""
	if not player_stats.has(peer_id):
		return 0

	return player_stats[peer_id].total_violations


func get_flagged_players() -> Array:
	"""Get list of flagged player peer_ids"""
	var flagged = []
	for peer_id in player_stats.keys():
		if player_stats[peer_id].flagged:
			flagged.append(peer_id)
	return flagged


func get_stats_summary() -> Dictionary:
	"""Get overall anti-cheat statistics"""
	var total_players = player_stats.size()
	var flagged_count = 0
	var kicked_count = 0
	var total_violations = 0

	for peer_id in player_stats.keys():
		var stats = player_stats[peer_id]
		if stats.flagged:
			flagged_count += 1
		if stats.kicked:
			kicked_count += 1
		total_violations += stats.total_violations

	return {
		"total_players": total_players,
		"flagged_players": flagged_count,
		"kicked_players": kicked_count,
		"total_violations": total_violations
	}


func print_stats():
	"""Print anti-cheat statistics to console"""
	var summary = get_stats_summary()
	print("[ANTI_CHEAT] === Statistics ===")
	print("[ANTI_CHEAT] Total players monitored: %d" % summary.total_players)
	print("[ANTI_CHEAT] Flagged for review: %d" % summary.flagged_players)
	print("[ANTI_CHEAT] Kicked: %d" % summary.kicked_players)
	print("[ANTI_CHEAT] Total violations: %d" % summary.total_violations)


## ========== CLEANUP ==========

func reset_player_violations(peer_id: int):
	"""Reset violations for a player (e.g., after review)"""
	if not player_stats.has(peer_id):
		return

	player_stats[peer_id].violations = {
		"teleport": 0,
		"speed_hack": 0,
		"invalid_input": 0,
		"suspicious_movement": 0
	}
	player_stats[peer_id].total_violations = 0
	player_stats[peer_id].flagged = false

	print("[ANTI_CHEAT] Reset violations for peer %d" % peer_id)
