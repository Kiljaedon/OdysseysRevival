class_name CombatNetworkService
extends Node
## Handles all battle/combat RPCs

var server_world: Node  # Set by ServerConnection


## ========== CLIENT → SERVER HANDLERS ==========

func handle_npc_attack(npc_id: int):
	print("[CombatService] NPC attack request for NPC %d" % npc_id)
	var peer_id = multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and server_world:
		server_world.handle_npc_attack_request(peer_id, npc_id)


func handle_player_battle_action(combat_id: int, action_type: String, target_id: int):
	if multiplayer.is_server() and server_world:
		var peer_id = multiplayer.get_remote_sender_id()
		server_world.receive_player_battle_action(peer_id, combat_id, action_type, target_id)


func handle_player_action(combat_id: int, action: String, target_id: int):
	if multiplayer.is_server() and server_world:
		var peer_id = multiplayer.get_remote_sender_id()
		server_world.handle_player_action(peer_id, combat_id, action, target_id)


func handle_battle_end(combat_id: int, victory: bool):
	if multiplayer.is_server() and server_world:
		var peer_id = multiplayer.get_remote_sender_id()
		server_world.handle_battle_end(peer_id, combat_id, victory)


## ========== SERVER → CLIENT SENDERS ==========

func send_binary_combat_start(peer_id: int, packet: PackedByteArray):
	get_parent().binary_combat_start.rpc_id(peer_id, packet)


func send_combat_round_results(peer_id: int, combat_id: int, results: Dictionary):
	get_parent().combat_round_results.rpc_id(peer_id, combat_id, results)


## ========== CLIENT-SIDE RESPONSE HANDLERS ==========

func on_binary_combat_start(packet: PackedByteArray):
	print("[CombatService] Combat start received, packet size: %d" % packet.size())
	var controller = get_parent()._find_node_with_script("dev_client_controller.gd")
	if controller:
		controller.handle_binary_combat_start(packet)


func on_combat_round_results(combat_id: int, results: Dictionary):
	print("[CombatService] Combat round results for combat %d" % combat_id)

	# Try registered battle network client first (FIX 12)
	var network_client = null
	var parent = get_parent()
	if parent.has_meta("active_battle_network_client"):
		network_client = parent.get_meta("active_battle_network_client")
		if network_client and is_instance_valid(network_client):
			if network_client.has_method("receive_action_result"):
				network_client.receive_action_result(results)
				return

	# Fallback to search
	network_client = parent._find_node_with_script("battle_network_client.gd")
	if network_client and network_client.has_method("receive_action_result"):
		network_client.receive_action_result(results)
		return

	# Try dev_client_controller
	var controller = parent._find_node_with_script("dev_client_controller.gd")
	if controller:
		controller.handle_combat_round_results(combat_id, results)
		return

	# Try battle_window_v2 directly
	var battle_window = parent._find_node_with_script("battle_window_v2.gd")
	if battle_window and battle_window.has_method("_on_server_result_received"):
		battle_window._on_server_result_received(results)


func on_receive_action_result(result: Dictionary):
	print("[CombatService] Action result received")
	var network_client = get_parent()._find_node_with_script("battle_network_client.gd")
	if network_client and network_client.has_method("receive_action_result"):
		network_client.receive_action_result(result)


func on_receive_battle_end(combat_id: int, result: Dictionary):
	print("[CombatService] Battle %d ended" % combat_id)

	# Try registered client first
	var network_client = null
	var parent = get_parent()
	if parent.has_meta("active_battle_network_client"):
		network_client = parent.get_meta("active_battle_network_client")

	if not network_client or not is_instance_valid(network_client):
		network_client = parent._find_node_with_script("battle_network_client.gd")

	# Try BattleWindow directly
	var battle_window = get_tree().root.find_child("BattleWindowV2", true, false)
	if battle_window and battle_window.has_method("handle_battle_end"):
		battle_window.handle_battle_end(combat_id, result)


func on_start_action_selection(round_number: int):
	print("[CombatService] Starting action selection for round %d" % round_number)
	var battle_window = get_tree().root.find_child("BattleWindowV2", true, false)
	if battle_window and battle_window.has_method("show_action_selection"):
		battle_window.show_action_selection(round_number)


func on_round_complete_request_ready(round_number: int):
	print("[CombatService] Round %d complete - requesting ready confirmation" % round_number)
	var battle_window = get_tree().root.find_child("BattleWindowV2", true, false)
	if battle_window:
		var network_client = battle_window.get_node_or_null("BattleNetworkClient")
		if network_client and network_client.has_method("send_client_ready"):
			network_client.send_client_ready()
