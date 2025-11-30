class_name AdminNetworkService
extends Node
## Handles content uploads, admin operations

var server_world: Node  # Set by ServerConnection


## ========== CLIENT → SERVER HANDLERS ==========

func handle_upload_class(player_class: String, class_data: Dictionary):
	if multiplayer.is_server() and server_world:
		server_world.upload_class(player_class, class_data)


func handle_upload_npc(npc_name: String, npc_data: Dictionary):
	if multiplayer.is_server() and server_world:
		server_world.upload_npc(npc_name, npc_data)


func handle_upload_map(map_name: String, map_data: String):
	if multiplayer.is_server() and server_world:
		server_world.upload_map(map_name, map_data)


## ========== SERVER → CLIENT SENDERS ==========

func send_upload_response(peer_id: int, success: bool, message: String):
	get_parent().upload_response.rpc_id(peer_id, success, message)


## ========== CLIENT-SIDE RESPONSE HANDLERS ==========

func on_upload_response(success: bool, message: String):
	print("[AdminService] Upload response: success=%s, message=%s" % [success, message])
	var handler = get_parent()._find_node_with_script("admin_panel.gd")
	if handler and handler.has_method("on_upload_response"):
		handler.on_upload_response(success, message)
