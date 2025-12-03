class_name ContentManager
extends Node

## Content Manager
## Handles content upload and management for the server.
## Extracted from ServerWorld to isolate administrative tasks.

var server_world: Node
var network_handler: Node
var auth_manager: Node

func initialize(p_server_world: Node, p_network_handler: Node, p_auth_manager: Node) -> void:
	server_world = p_server_world
	network_handler = p_network_handler
	auth_manager = p_auth_manager
	print("[CONTENT] Content manager initialized")

func _is_localhost_connection(peer_id: int) -> bool:
	"""Check if the peer is connecting from localhost"""
	var peer = server_world.multiplayer.multiplayer_peer
	if peer and peer is ENetMultiplayerPeer:
		var enet_peer = peer.get_peer(peer_id)
		if enet_peer:
			var address = enet_peer.get_remote_address()
			return address == "127.0.0.1" or address == "::1" or address == "localhost"
	return false

func upload_class(class_name_str: String, class_data: Dictionary):
	"""Handle class upload from admin tool - LOCALHOST ONLY"""
	var peer_id = server_world.multiplayer.get_remote_sender_id()

	if not _is_localhost_connection(peer_id):
		server_world.log_message("[SECURITY] Rejected class upload from non-localhost peer %d" % peer_id)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Upload rejected: Only localhost uploads allowed")
		return

	var admin_level = auth_manager.get_admin_level(peer_id) if auth_manager else 0
	if admin_level < 1:
		server_world.log_message("[SECURITY] Rejected class upload from non-admin peer %d" % peer_id)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Upload rejected: Admin privileges required")
		return

	var save_dir = "res://characters/classes/"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.open("res://").make_dir_recursive("characters/classes")

	var save_path = save_dir + class_name_str + ".json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(class_data, "\t"))
		file.close()
		server_world.log_message("[UPLOAD] Class '%s' saved by admin (peer %d)" % [class_name_str, peer_id])
		if network_handler:
			network_handler.send_upload_response(peer_id, true, "Class '%s' uploaded successfully" % class_name_str)
	else:
		server_world.log_message("[UPLOAD] ERROR: Failed to save class '%s'" % class_name_str)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Failed to save class file")

func upload_npc(npc_name: String, npc_data: Dictionary):
	"""Handle NPC upload from admin tool - LOCALHOST ONLY"""
	var peer_id = server_world.multiplayer.get_remote_sender_id()

	if not _is_localhost_connection(peer_id):
		server_world.log_message("[SECURITY] Rejected NPC upload from non-localhost peer %d" % peer_id)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Upload rejected: Only localhost uploads allowed")
		return

	var admin_level = auth_manager.get_admin_level(peer_id) if auth_manager else 0
	if admin_level < 1:
		server_world.log_message("[SECURITY] Rejected NPC upload from non-admin peer %d" % peer_id)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Upload rejected: Admin privileges required")
		return

	var save_dir = "res://characters/npcs/"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.open("res://").make_dir_recursive("characters/npcs")

	var save_path = save_dir + npc_name + ".json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(npc_data, "\t"))
		file.close()
		server_world.log_message("[UPLOAD] NPC '%s' saved by admin (peer %d)" % [npc_name, peer_id])
		if network_handler:
			network_handler.send_upload_response(peer_id, true, "NPC '%s' uploaded successfully" % npc_name)
	else:
		server_world.log_message("[UPLOAD] ERROR: Failed to save NPC '%s'" % npc_name)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Failed to save NPC file")

func upload_map(map_name: String, map_data: String):
	"""Handle map upload from admin tool - LOCALHOST ONLY"""
	var peer_id = server_world.multiplayer.get_remote_sender_id()

	if not _is_localhost_connection(peer_id):
		server_world.log_message("[SECURITY] Rejected map upload from non-localhost peer %d" % peer_id)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Upload rejected: Only localhost uploads allowed")
		return

	var admin_level = auth_manager.get_admin_level(peer_id) if auth_manager else 0
	if admin_level < 1:
		server_world.log_message("[SECURITY] Rejected map upload from non-admin peer %d" % peer_id)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Upload rejected: Admin privileges required")
		return

	var save_dir = "res://maps/"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.open("res://").make_dir("maps")

	var save_path = save_dir + map_name + ".tmx"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(map_data)
		file.close()
		server_world.log_message("[UPLOAD] Map '%s' saved by admin (peer %d)" % [map_name, peer_id])
		if network_handler:
			network_handler.send_upload_response(peer_id, true, "Map '%s' uploaded successfully" % map_name)
	else:
		server_world.log_message("[UPLOAD] ERROR: Failed to save map '%s'" % map_name)
		if network_handler:
			network_handler.send_upload_response(peer_id, false, "Failed to save map file")
