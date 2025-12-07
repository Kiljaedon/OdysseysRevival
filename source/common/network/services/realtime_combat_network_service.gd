class_name RealtimeCombatNetworkService
extends Node
## Real-time Combat Network Service
## Handles all real-time battle RPCs (separate from turn-based combat)

var server_world: Node  # Set by ServerConnection

## ========== CLIENT → SERVER HANDLERS ==========

func handle_rt_start_battle(npc_id: int):
	"""Client requests to start real-time battle with NPC"""
	var peer_id = multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and server_world:
		server_world.handle_realtime_battle_request(peer_id, npc_id)

func handle_rt_player_move(velocity_x: float, velocity_y: float):
	"""Client sends movement input"""
	var peer_id = multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and server_world:
		server_world.handle_realtime_player_move(peer_id, Vector2(velocity_x, velocity_y))

func handle_rt_player_attack(target_id: String):
	"""Client sends attack input"""
	var peer_id = multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and server_world:
		server_world.handle_realtime_player_attack(peer_id, target_id)

func handle_rt_player_dodge_roll(direction_x: float, direction_y: float):
	"""Client performs dodge roll"""
	var peer_id = multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and server_world:
		server_world.handle_realtime_player_dodge_roll(peer_id, direction_x, direction_y)

## ========== CLIENT-SIDE RESPONSE HANDLERS ==========

func on_rt_battle_start(battle_data: Dictionary):
	"""Handle battle start on client"""
	print("[RT_NET_SERVICE] Received battle start RPC with data: ", battle_data.keys())

	# First check if launcher exists and use it
	var launcher = _find_battle_launcher()
	if launcher:
		print("[RT_NET_SERVICE] Found launcher, starting battle...")
		launcher.start_battle(battle_data)
		return

	print("[RT_NET_SERVICE] WARNING: No launcher found!")

	# Fallback to existing controller
	var controller = _find_realtime_battle_controller()
	if controller and controller.has_method("on_battle_start"):
		print("[RT_NET_SERVICE] Using fallback controller")
		controller.on_battle_start(battle_data)
	else:
		print("[RT_NET_SERVICE] ERROR: No controller found either!")

func on_rt_state_update(units_state: Array):
	"""Handle state update on client"""
	var controller = _find_realtime_battle_controller()
	if controller and controller.has_method("on_state_update"):
		controller.on_state_update(units_state)

func on_rt_damage_event(attacker_id: String, target_id: String, damage: int, flank_type: String):
	"""Handle damage event on client"""
	var controller = _find_realtime_battle_controller()
	if controller and controller.has_method("on_damage_event"):
		controller.on_damage_event(attacker_id, target_id, damage, flank_type)

func on_rt_unit_death(unit_id: String):
	"""Handle unit death on client"""
	var controller = _find_realtime_battle_controller()
	if controller and controller.has_method("on_unit_death"):
		controller.on_unit_death(unit_id)

func on_rt_dodge_roll_event(unit_id: String, direction_x: float, direction_y: float):
	"""Handle dodge roll on client"""
	var controller = _find_realtime_battle_controller()
	if controller and controller.has_method("on_dodge_roll_event"):
		controller.on_dodge_roll_event(unit_id, Vector2(direction_x, direction_y))

func on_rt_battle_end(battle_id: int, result: String, rewards: Dictionary):
	"""Handle battle end on client"""
	print("[RT_NET_SERVICE] Received battle_end for battle %d, result=%s" % [battle_id, result])
	var controller = _find_realtime_battle_controller()
	if controller and controller.has_method("on_battle_end"):
		controller.on_battle_end(battle_id, result, rewards)
	else:
		print("[RT_NET_SERVICE] WARNING: No controller to handle battle_end")

func on_rt_projectile_spawn(proj_data: Dictionary):
	"""Handle projectile spawn on client"""
	var controller = _find_realtime_battle_controller()
	if controller and controller.has_method("on_projectile_spawn"):
		controller.on_projectile_spawn(proj_data)

func on_rt_projectile_hit(projectile_id: String, target_id: String, hit_position: Vector2):
	"""Handle projectile hit on client"""
	var controller = _find_realtime_battle_controller()
	if controller and controller.has_method("on_projectile_hit"):
		controller.on_projectile_hit(projectile_id, target_id, hit_position)

func on_rt_projectile_miss(projectile_id: String, final_position: Vector2):
	"""Handle projectile miss on client"""
	var controller = _find_realtime_battle_controller()
	if controller and controller.has_method("on_projectile_miss"):
		controller.on_projectile_miss(projectile_id, final_position)

## ========== UTILITY ==========

func _find_realtime_battle_controller() -> Node:
	"""Find the active realtime battle controller"""
	var parent = get_parent()
	if parent.has_meta("active_realtime_battle_controller"):
		var controller = parent.get_meta("active_realtime_battle_controller")
		if is_instance_valid(controller):
			return controller
	return null

func _find_battle_launcher() -> Node:
	"""Find the battle launcher"""
	var parent = get_parent()
	if parent.has_meta("realtime_battle_launcher"):
		var launcher = parent.get_meta("realtime_battle_launcher")
		if is_instance_valid(launcher):
			return launcher
	return null
