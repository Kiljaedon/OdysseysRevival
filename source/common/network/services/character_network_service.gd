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
	# Try direct routing first
	var manager = get_parent().get_meta("multiplayer_manager", null)
	if manager and manager.has_method("handle_spawn_accepted"):
		# Need to pass the callback provided by dev_client...
		# Wait, dev_client passes `Callable(self, "setup_character_sprite")`
		# If we route directly, we lose this callback context?
		# Actually, MultiplayerManager stores the callback? No, it takes it as arg.
		
		# ISSUE: handle_spawn_accepted requires `on_character_loaded` callback.
		# We can't provide that easily from here without the controller.
		# So for this SPECIFIC method, we might need to keep the controller routing
		# OR refactor MultiplayerManager to trigger a signal instead of callback.
		
		# Let's look at dev_client_controller.gd:
		# func handle_spawn_accepted(player_data: Dictionary):
		#     if multiplayer_manager:
		#         multiplayer_manager.handle_spawn_accepted(player_data, Callable(self, "setup_character_sprite"))
		
		# Since `setup_character_sprite` is on the controller, we still need the controller.
		# UNLESS we move `setup_character_sprite` to CharacterSetupManager and MultiplayerManager uses that.
		
		pass

	# Fallback/Current logic (Required for callback context)
	var controller = get_parent()._find_node_with_script("dev_client_controller.gd")
	if controller:
		controller.handle_spawn_accepted(player_data)


func on_spawn_rejected(reason: String):
	# Try direct routing
	var manager = get_parent().get_meta("multiplayer_manager", null)
	if manager and manager.has_method("handle_spawn_rejected"):
		manager.handle_spawn_rejected(reason)
		return

	var controller = get_parent()._find_node_with_script("dev_client_controller.gd")
	if controller:
		controller.handle_spawn_rejected(reason)
