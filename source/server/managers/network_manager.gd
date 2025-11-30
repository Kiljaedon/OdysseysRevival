## Network Manager - Network Position Broadcasting and Delta Compression
## Handles efficient player position updates with interest management
extends Node
class_name NetworkManager

var server_world: Node  # Reference to ServerWorld
var delta_compression_enabled: bool = true  # Only send position updates when changed
var last_broadcast_positions: Dictionary = {}  # Track last sent positions for delta


func initialize(server_ref: Node):
	"""Initialize network manager with server reference"""
	server_world = server_ref
	print("[NetworkManager] Initialized")


# ========== NETWORK POSITION BROADCASTING ==========

func broadcast_player_positions():
	"""Send player positions using binary packets with interest management"""
	if not server_world.player_manager or server_world.player_manager.player_positions.is_empty() or not server_world.network_sync:
		return

	# Delta compression: only send positions that changed
	if delta_compression_enabled:
		var changed_positions = {}
		for peer_id in server_world.player_manager.player_positions:
			var current_pos = server_world.player_manager.player_positions[peer_id]
			var last_pos = last_broadcast_positions.get(peer_id, Vector2.ZERO)

			# Only send if position changed (>1 pixel difference to avoid float precision issues)
			if current_pos.distance_to(last_pos) > 1.0:
				changed_positions[peer_id] = current_pos
				last_broadcast_positions[peer_id] = current_pos

		# Only broadcast if there are changes
		if not changed_positions.is_empty():
			server_world.network_sync.broadcast_player_positions(changed_positions)
	else:
		# Send all positions without delta compression
		server_world.network_sync.broadcast_player_positions(server_world.player_manager.player_positions)
		# Still track for stats
		last_broadcast_positions = server_world.player_manager.player_positions.duplicate()


func set_delta_compression(enabled: bool):
	"""Enable or disable delta compression for position updates"""
	delta_compression_enabled = enabled
	var status = "ENABLED" if enabled else "DISABLED"
	server_world.log_message("[NETWORK] Delta compression %s" % status)

	# Clear tracking when disabled to start fresh
	if not enabled:
		last_broadcast_positions.clear()


func get_compression_stats() -> Dictionary:
	"""Get statistics about delta compression efficiency"""
	var total_players = server_world.player_manager.player_positions.size() if server_world.player_manager else 0
	var tracked_positions = last_broadcast_positions.size()

	return {
		"enabled": delta_compression_enabled,
		"total_players": total_players,
		"tracked_positions": tracked_positions
	}


func clear_position_tracking():
	"""Clear all tracked positions (useful when players disconnect)"""
	last_broadcast_positions.clear()


func remove_player_tracking(peer_id: int):
	"""Remove a specific player from position tracking"""
	last_broadcast_positions.erase(peer_id)
