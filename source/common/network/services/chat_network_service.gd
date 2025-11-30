class_name ChatNetworkService
extends Node
## Handles chat messages

var server_world: Node  # Set by ServerConnection


## ========== CLIENT → SERVER HANDLERS ==========

func handle_send_chat_message(message: String):
	if multiplayer.is_server() and server_world:
		server_world.send_chat_message(message)


## ========== SERVER → CLIENT SENDERS ==========

func broadcast_chat_to_peer(peer_id: int, player_name: String, message: String):
	get_parent().receive_chat_message.rpc_id(peer_id, player_name, message)


## ========== CLIENT-SIDE RESPONSE HANDLERS ==========

func on_receive_chat_message(player_name: String, message: String):
	print("[ChatService] Chat from %s: %s" % [player_name, message])
	var controller = get_parent()._find_node_with_script("dev_client_controller.gd")
	if controller and controller.has_method("receive_chat_message"):
		controller.receive_chat_message(player_name, message)
