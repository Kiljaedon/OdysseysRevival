## Stats Manager - Server Statistics and Admin Tools
## Handles server monitoring, diagnostics, and admin commands
extends Node
class_name StatsManager

var server_world: Node  # Reference to ServerWorld


func initialize(server_ref: Node):
	"""Initialize stats manager with server reference"""
	server_world = server_ref
	print("[StatsManager] Initialized")


# ========== ADMIN TOOL FUNCTIONS ==========

func print_stats():
	"""Print comprehensive server statistics"""
	server_world.log_message("========== SERVER STATISTICS ==========")

	# Player statistics
	var player_count = server_world.player_manager.connected_players.size() if server_world.player_manager else 0
	server_world.log_message("[PLAYERS] Connected: %d" % player_count)
	server_world.log_message("[PLAYERS] Authenticated: %d" % server_world.auth_manager.authenticated_peers.size())

	# Network statistics
	if server_world.network_sync:
		var stats = server_world.network_sync.get_stats_summary()
		server_world.log_message("[NETWORK] Packets/sec: %d" % stats.get("packets_sent_this_second", 0))
		server_world.log_message("[NETWORK] Bandwidth: %.2f KB/s" % (stats.get("bytes_sent_this_second", 0) / 1024.0))

	# Network manager statistics
	if server_world.network_manager:
		var compression_enabled = server_world.network_manager.delta_compression_enabled
		server_world.log_message("[NETWORK] Delta Compression: %s" % ("ENABLED" if compression_enabled else "DISABLED"))
		var compression_stats = server_world.network_manager.get_compression_stats()
		server_world.log_message("[NETWORK] Tracked positions: %d/%d" % [compression_stats.tracked_positions, compression_stats.total_players])

	# Anti-cheat statistics
	if server_world.anti_cheat:
		server_world.log_message("[ANTI_CHEAT] System active")
		# Print per-player violation counts
		var total_violations = 0
		if server_world.player_manager:
			for peer_id in server_world.player_manager.connected_players:
				var violations = server_world.anti_cheat.get_violation_count(peer_id)
				if violations > 0:
					var player_name = server_world.player_manager.connected_players[peer_id].get("character_name", "Unknown")
					server_world.log_message("[ANTI_CHEAT] Player %s (ID %d): %d violations" % [player_name, peer_id, violations])
					total_violations += violations
		server_world.log_message("[ANTI_CHEAT] Total violations: %d" % total_violations)

	# Spatial manager statistics
	if server_world.spatial_manager:
		server_world.log_message("[SPATIAL] Grid cell size: %d" % server_world.spatial_manager.grid_cell_size)
		server_world.log_message("[SPATIAL] Visibility radius: %d cells" % server_world.spatial_manager.visibility_radius)

	# NPC statistics
	var npc_count = server_world.npc_manager.server_npcs.size() if server_world.npc_manager else 0
	server_world.log_message("[NPCS] Active NPCs: %d" % npc_count)

	server_world.log_message("=======================================")


func list_players():
	"""List all connected players with details"""
	if not server_world.player_manager or server_world.player_manager.connected_players.is_empty():
		server_world.log_message("[PLAYERS] No players currently connected")
		return

	server_world.log_message("========== CONNECTED PLAYERS ==========")
	for peer_id in server_world.player_manager.connected_players:
		var player = server_world.player_manager.connected_players[peer_id]
		var username = player.get("username", "Unknown")
		var character_name = player.get("character_name", "No character")
		var player_class = player.get("class_name", "Unknown")
		var level = player.get("level", 1)
		var position = player.get("position", Vector2.ZERO)

		server_world.log_message("[Player ID %d]" % peer_id)
		server_world.log_message("  Account: %s" % username)
		server_world.log_message("  Character: %s (Lv.%d %s)" % [character_name, level, player_class])
		server_world.log_message("  Position: %s" % str(position))
		server_world.log_message("  ---")
	server_world.log_message("Total: %d player(s)" % server_world.player_manager.connected_players.size())
	server_world.log_message("=======================================")


func toggle_console():
	"""Toggle debug console visibility (F12)"""
	if server_world.debug_console:
		server_world.debug_console.visible = not server_world.debug_console.visible
		var status = "SHOWN" if server_world.debug_console.visible else "HIDDEN"
		server_world.log_message("[DEBUG] Console %s" % status)
	else:
		server_world.log_message("[DEBUG] ERROR: Debug console not available")
