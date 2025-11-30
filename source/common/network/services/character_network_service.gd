class_name CharacterNetworkService
extends Node
## Handles character CRUD operations

var server_world: Node  # Set by ServerConnection


## ========== CLIENT → SERVER HANDLERS ==========

func handle_create_character(username: String, character_data: Dictionary):
	if multiplayer.is_server() and server_world:
		var peer_id = multiplayer.get_remote_sender_id()
		server_world.request_create_character(peer_id, username, character_data)


func handle_delete_character(username: String, character_id: String):
	if multiplayer.is_server() and server_world:
		server_world.request_delete_character(username, character_id)


func handle_spawn_character(username: String, character_id: String):
	if multiplayer.is_server() and server_world:
		server_world.request_spawn_character(username, character_id)


## ========== SERVER → CLIENT SENDERS ==========

func send_character_creation_response(peer_id: int, success: bool, message: String, character_data: Dictionary):
	get_parent().character_creation_response.rpc_id(peer_id, success, message, character_data)


func send_character_deletion_response(peer_id: int, success: bool, message: String):
	get_parent().character_deletion_response.rpc_id(peer_id, success, message)


func send_spawn_accepted(peer_id: int, player_data: Dictionary):
	get_parent().spawn_accepted.rpc_id(peer_id, player_data)


func send_spawn_rejected(peer_id: int, reason: String):
	get_parent().spawn_rejected.rpc_id(peer_id, reason)


## ========== CLIENT-SIDE RESPONSE HANDLERS ==========

func on_character_creation_response(success: bool, message: String, character_data: Dictionary):
	var creator = get_parent()._find_node_with_script("character_creator.gd")
	if creator:
		creator.character_creation_response(success, message, character_data)


func on_character_deletion_response(success: bool, message: String):
	var select_screen = get_parent()._find_node_with_script("character_select_screen.gd")
	if select_screen:
		select_screen.character_deletion_response(success, message)


func on_spawn_accepted(player_data: Dictionary):
	var controller = get_parent()._find_node_with_script("dev_client_controller.gd")
	if controller:
		controller.handle_spawn_accepted(player_data)


func on_spawn_rejected(reason: String):
	var controller = get_parent()._find_node_with_script("dev_client_controller.gd")
	if controller:
		controller.handle_spawn_rejected(reason)
