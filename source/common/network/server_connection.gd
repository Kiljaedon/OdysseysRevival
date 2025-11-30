extends Node
## ServerConnection - Network Router/Facade
## Delegates to domain-specific services while maintaining RPC interface
##
## Services:
##   - AuthNetworkService: Account/login
##   - CharacterNetworkService: Character CRUD
##   - WorldNetworkService: Movement/presence
##   - CombatNetworkService: Battle system
##   - ChatNetworkService: Chat messages
##   - AdminNetworkService: Content uploads

const AuthNetworkService = preload("res://source/common/network/services/auth_network_service.gd")
const CharacterNetworkService = preload("res://source/common/network/services/character_network_service.gd")
const WorldNetworkService = preload("res://source/common/network/services/world_network_service.gd")
const CombatNetworkService = preload("res://source/common/network/services/combat_network_service.gd")
const RealtimeCombatNetworkService = preload("res://source/common/network/services/realtime_combat_network_service.gd")
const ChatNetworkService = preload("res://source/common/network/services/chat_network_service.gd")
const AdminNetworkService = preload("res://source/common/network/services/admin_network_service.gd")

# Service instances
var auth_service: Node
var character_service: Node
var world_service: Node
var combat_service: Node
var rt_combat_service: Node
var chat_service: Node
var admin_service: Node

# Reference to server_world (server-side only)
var server_world: Node = null


func _ready():
	_init_services()
	set_process(true)

	if not multiplayer.has_multiplayer_peer():
		await get_tree().process_frame

	# Server-side: find ServerWorld
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		for child in get_tree().root.get_children():
			if child.name == "ServerWorld":
				server_world = child
				_propagate_server_world()
				if server_world.has_method("set_network_handler"):
					server_world.set_network_handler(self)
				print("[ServerConnection] Found ServerWorld: ", server_world)
				break
		if not server_world:
			print("[ServerConnection] WARNING: ServerWorld not found")
	else:
		print("[ServerConnection] Client mode - ready for RPC calls")


func _init_services():
	auth_service = AuthNetworkService.new()
	auth_service.name = "AuthService"
	add_child(auth_service)

	character_service = CharacterNetworkService.new()
	character_service.name = "CharacterService"
	add_child(character_service)

	world_service = WorldNetworkService.new()
	world_service.name = "WorldService"
	add_child(world_service)

	combat_service = CombatNetworkService.new()
	combat_service.name = "CombatService"
	add_child(combat_service)

	rt_combat_service = RealtimeCombatNetworkService.new()
	rt_combat_service.name = "RealtimeCombatService"
	add_child(rt_combat_service)

	chat_service = ChatNetworkService.new()
	chat_service.name = "ChatService"
	add_child(chat_service)

	admin_service = AdminNetworkService.new()
	admin_service.name = "AdminService"
	add_child(admin_service)


func _propagate_server_world():
	auth_service.server_world = server_world
	character_service.server_world = server_world
	world_service.server_world = server_world
	combat_service.server_world = server_world
	rt_combat_service.server_world = server_world
	chat_service.server_world = server_world
	admin_service.server_world = server_world


func _process(_delta):
	pass


# ==================== AUTH RPCs ====================

@rpc("any_peer")
func ping_server():
	auth_service.handle_ping()

@rpc("any_peer")
func request_create_account(username: String, password: String):
	auth_service.handle_create_account(username, password)

@rpc("any_peer")
func request_login(username: String, password: String):
	auth_service.handle_login(username, password)

@rpc
func account_creation_response(success: bool, message: String):
	auth_service.on_account_creation_response(success, message)

@rpc
func login_response(success: bool, message: String, data: Dictionary):
	auth_service.on_login_response(success, message, data)


# ==================== CHARACTER RPCs ====================

@rpc("any_peer")
func request_create_character(username: String, character_data: Dictionary):
	character_service.handle_create_character(username, character_data)

@rpc("any_peer")
func request_delete_character(username: String, character_id: String):
	character_service.handle_delete_character(username, character_id)

@rpc("any_peer")
func request_spawn_character(username: String, character_id: String):
	character_service.handle_spawn_character(username, character_id)

@rpc
func character_creation_response(success: bool, message: String, character_data: Dictionary):
	character_service.on_character_creation_response(success, message, character_data)

@rpc
func character_deletion_response(success: bool, message: String):
	character_service.on_character_deletion_response(success, message)

@rpc
func spawn_accepted(player_data: Dictionary):
	character_service.on_spawn_accepted(player_data)

@rpc
func spawn_rejected(reason: String):
	character_service.on_spawn_rejected(reason)


# ==================== WORLD RPCs ====================

@rpc("any_peer", "unreliable")
func binary_input(packet: PackedByteArray):
	world_service.handle_binary_input(packet)

@rpc
func player_spawned(spawned_peer_id: int, player_data: Dictionary):
	world_service.on_player_spawned(spawned_peer_id, player_data)

@rpc
func player_despawned(despawned_peer_id: int):
	world_service.on_player_despawned(despawned_peer_id)

@rpc
func sync_positions(positions: Dictionary):
	world_service.on_sync_positions(positions)

@rpc("authority", "unreliable")
func binary_positions(packet: PackedByteArray):
	world_service.on_binary_positions(packet)

@rpc
func npc_spawned(npc_id: int, npc_data: Dictionary):
	world_service.on_npc_spawned(npc_id, npc_data)

@rpc
func sync_npc_positions(npc_positions: Dictionary):
	world_service.on_sync_npc_positions(npc_positions)

@rpc("any_peer")
func request_map_change(map_name: String, x: float, y: float):
	var peer_id = multiplayer.get_remote_sender_id()
	world_service.handle_map_change_request(peer_id, map_name, x, y)

@rpc
func map_changed(map_name: String, spawn_x: float, spawn_y: float):
	world_service.on_map_changed(map_name, spawn_x, spawn_y)


# ==================== COMBAT RPCs ====================

@rpc("any_peer")
func request_npc_attack(npc_id: int):
	combat_service.handle_npc_attack(npc_id)

@rpc("any_peer")
func send_player_battle_action(combat_id: int, action_type: String, target_id: int):
	combat_service.handle_player_battle_action(combat_id, action_type, target_id)

@rpc("any_peer")
func handle_player_action(combat_id: int, action: String, target_id: int):
	combat_service.handle_player_action(combat_id, action, target_id)

@rpc("any_peer")
func send_battle_end(combat_id: int, victory: bool):
	combat_service.handle_battle_end(combat_id, victory)

@rpc
func binary_combat_start(packet: PackedByteArray):
	combat_service.on_binary_combat_start(packet)

@rpc
func combat_round_results(combat_id: int, results: Dictionary):
	combat_service.on_combat_round_results(combat_id, results)

@rpc("any_peer")
func receive_action_result(result: Dictionary):
	combat_service.on_receive_action_result(result)

@rpc("any_peer")
func receive_battle_end(combat_id: int, result: Dictionary):
	combat_service.on_receive_battle_end(combat_id, result)

@rpc("any_peer")
func start_action_selection(round_number: int):
	combat_service.on_start_action_selection(round_number)

@rpc("any_peer")
func round_complete_request_ready(round_number: int):
	combat_service.on_round_complete_request_ready(round_number)


# ==================== REALTIME COMBAT RPCs ====================

@rpc("any_peer")
func rt_start_battle(npc_id: int):
	rt_combat_service.handle_rt_start_battle(npc_id)

@rpc("any_peer", "unreliable")
func rt_player_move(velocity_x: float, velocity_y: float):
	rt_combat_service.handle_rt_player_move(velocity_x, velocity_y)

@rpc("any_peer")
func rt_player_attack(target_id: String):
	rt_combat_service.handle_rt_player_attack(target_id)

@rpc("any_peer")
func rt_player_defend():
	rt_combat_service.handle_rt_player_defend()

@rpc
func rt_battle_start(battle_data: Dictionary):
	rt_combat_service.on_rt_battle_start(battle_data)

@rpc("unreliable")
func rt_state_update(units_state: Array):
	rt_combat_service.on_rt_state_update(units_state)

@rpc
func rt_damage_event(attacker_id: String, target_id: String, damage: int, flank_type: String):
	rt_combat_service.on_rt_damage_event(attacker_id, target_id, damage, flank_type)

@rpc
func rt_unit_death(unit_id: String):
	rt_combat_service.on_rt_unit_death(unit_id)

@rpc
func rt_defend_event(unit_id: String):
	rt_combat_service.on_rt_defend_event(unit_id)

@rpc
func rt_battle_end(battle_id: int, result: String, rewards: Dictionary):
	rt_combat_service.on_rt_battle_end(battle_id, result, rewards)


# ==================== CHAT RPCs ====================

@rpc("any_peer")
func send_chat_message(message: String):
	chat_service.handle_send_chat_message(message)

@rpc
func receive_chat_message(player_name: String, message: String):
	chat_service.on_receive_chat_message(player_name, message)


# ==================== ADMIN RPCs ====================

@rpc("any_peer")
func upload_class(player_class: String, class_data: Dictionary):
	admin_service.handle_upload_class(player_class, class_data)

@rpc("any_peer")
func upload_npc(npc_name: String, npc_data: Dictionary):
	admin_service.handle_upload_npc(npc_name, npc_data)

@rpc("any_peer")
func upload_map(map_name: String, map_data: String):
	admin_service.handle_upload_map(map_name, map_data)

@rpc
func upload_response(success: bool, message: String):
	admin_service.on_upload_response(success, message)


# ==================== SERVER-SIDE SEND METHODS ====================
# These delegate to services but keep the same interface for callers

func send_account_creation_response(peer_id: int, success: bool, message: String):
	auth_service.send_account_creation_response(peer_id, success, message)

func send_login_response(peer_id: int, success: bool, message: String, data: Dictionary):
	auth_service.send_login_response(peer_id, success, message, data)

func send_character_creation_response(peer_id: int, success: bool, message: String, character_data: Dictionary):
	character_service.send_character_creation_response(peer_id, success, message, character_data)

func send_character_deletion_response(peer_id: int, success: bool, message: String):
	character_service.send_character_deletion_response(peer_id, success, message)

func send_spawn_accepted(peer_id: int, player_data: Dictionary):
	character_service.send_spawn_accepted(peer_id, player_data)

func send_spawn_rejected(peer_id: int, reason: String):
	character_service.send_spawn_rejected(peer_id, reason)

func send_player_spawned(peer_id: int, spawned_peer_id: int, player_data: Dictionary):
	world_service.send_player_spawned(peer_id, spawned_peer_id, player_data)

func send_player_despawned(peer_id: int, despawned_peer_id: int):
	world_service.send_player_despawned(peer_id, despawned_peer_id)

func send_sync_positions(peer_id: int, positions: Dictionary):
	world_service.send_sync_positions(peer_id, positions)

func broadcast_chat_to_peer(peer_id: int, player_name: String, message: String):
	chat_service.broadcast_chat_to_peer(peer_id, player_name, message)

func send_npc_spawn(peer_id: int, npc_id: int, npc_data: Dictionary):
	world_service.send_npc_spawn(peer_id, npc_id, npc_data)

func send_sync_npc_positions(peer_id: int, npc_positions: Dictionary):
	world_service.send_sync_npc_positions(peer_id, npc_positions)

func send_binary_combat_start(peer_id: int, packet: PackedByteArray):
	combat_service.send_binary_combat_start(peer_id, packet)

func send_combat_round_results(peer_id: int, combat_id: int, results: Dictionary):
	combat_service.send_combat_round_results(peer_id, combat_id, results)

func send_upload_response(peer_id: int, success: bool, message: String):
	admin_service.send_upload_response(peer_id, success, message)


# ==================== HELPER METHODS ====================

func _find_world_client() -> Node:
	"""Find WorldClient using groups (robust, doesn't depend on script paths)"""
	var nodes = get_tree().get_nodes_in_group("world_client")
	if nodes.size() > 0:
		return nodes[0]
	return null

func _find_node_with_script(script_name: String) -> Node:
	return _search_tree(get_tree().root, script_name)

func _search_tree(node: Node, script_name: String) -> Node:
	var script = node.get_script()
	if script:
		var script_path = script.resource_path if script.resource_path else ""
		if script_path.ends_with(script_name):
			return node

	for child in node.get_children():
		var found = _search_tree(child, script_name)
		if found:
			return found

	return null


# Notification constant for account creation
const NOTIFICATION_ACCOUNT_CREATION_RESPONSE = 10000
