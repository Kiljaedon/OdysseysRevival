class_name RealtimeBattleController
extends Node
## Realtime Battle Controller - Handles player input and server communication
## Sends input to server, receives and applies state updates

## ========== SIGNALS ==========
signal battle_ready
signal battle_ended(result: String, rewards: Dictionary)

## ========== CONSTANTS ==========
const INPUT_SEND_RATE: float = 0.05  # 20 times per second

## ========== REFERENCES ==========
var battle_scene: RealtimeBattleScene
var network_service: Node  # RealtimeCombatNetworkService

## ========== STATE ==========
var in_battle: bool = false
var battle_id: int = -1
var input_timer: float = 0.0
var last_velocity: Vector2 = Vector2.ZERO
var current_target_id: String = ""
var movement_speed: float = 300.0  # Base walk speed (same as server)

## ========== LIFECYCLE ==========

func _ready():
	set_process(false)  # Disabled until battle starts

func initialize(scene: RealtimeBattleScene, net_service: Node) -> void:
	"""Set up controller with scene and network references"""
	battle_scene = scene
	network_service = net_service

	# Connect to scene signals
	if battle_scene:
		battle_scene.battle_ended.connect(_on_battle_ended)

	print("[RT_CONTROLLER] Initialized")

var _process_log_counter: int = 0

func _process(delta: float):
	_process_log_counter += 1
	if _process_log_counter == 1:
		print("[RT_CONTROLLER] _process FIRST CALL: in_battle=%s" % in_battle)

	if not in_battle:
		return

	# Handle input
	_process_movement_input(delta)
	_process_action_input()

	# Send input to server at fixed rate
	input_timer += delta
	if input_timer >= INPUT_SEND_RATE:
		input_timer = 0.0
		_send_movement_to_server()

func _unhandled_input(event: InputEvent):
	if not in_battle:
		return

	# Handle zoom input in battle
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_handle_zoom(0.1)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom(-0.1)
			get_viewport().set_input_as_handled()
			return

	# Mouse click for targeting
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click_target(event.position)

func _handle_zoom(delta: float) -> void:
	"""Handle camera zoom in battle"""
	if battle_scene and battle_scene.camera:
		var new_zoom = battle_scene.camera.zoom + Vector2(delta, delta)
		new_zoom = new_zoom.clamp(Vector2(0.25, 0.25), Vector2(2.0, 2.0))
		battle_scene.camera.zoom = new_zoom

## ========== BATTLE LIFECYCLE ==========

func on_battle_start(battle_data: Dictionary) -> void:
	"""Called when server sends battle start"""
	battle_id = battle_data.get("id", -1)
	movement_speed = battle_data.get("player_move_speed", 200.0)

	# Initialize scene
	if battle_scene:
		battle_scene.start_battle(battle_data)

	in_battle = true
	set_process(true)
	print("[RT_CONTROLLER] set_process(true) called, in_battle=%s" % in_battle)

	# Register with network service
	if network_service:
		var parent = network_service.get_parent()
		if parent:
			parent.set_meta("active_realtime_battle_controller", self)

	battle_ready.emit()
	print("[RT_CONTROLLER] Battle %d started, movement_speed=%s" % [battle_id, movement_speed])

func on_battle_end(battle_id_param: int, result: String, rewards: Dictionary) -> void:
	"""Called when server sends battle end"""
	in_battle = false
	set_process(false)

	if battle_scene:
		battle_scene.end_battle(result, rewards)

	# Unregister from network service
	if network_service:
		var parent = network_service.get_parent()
		if parent and parent.has_meta("active_realtime_battle_controller"):
			parent.remove_meta("active_realtime_battle_controller")

	battle_ended.emit(result, rewards)
	print("[RT_CONTROLLER] Battle %d ended: %s" % [battle_id_param, result])

func _on_battle_ended(result: String, rewards: Dictionary):
	"""Handle scene's battle ended signal"""
	in_battle = false
	set_process(false)

## ========== INPUT HANDLING ==========

var _debug_move_counter: int = 0

func _process_movement_input(delta: float) -> void:
	"""Read WASD input and calculate velocity"""
	var velocity = Vector2.ZERO

	if Input.is_action_pressed("up"):
		velocity.y -= 1
	if Input.is_action_pressed("down"):
		velocity.y += 1
	if Input.is_action_pressed("left"):
		velocity.x -= 1
	if Input.is_action_pressed("right"):
		velocity.x += 1

	if velocity.length() > 0:
		velocity = velocity.normalized() * movement_speed

	last_velocity = velocity

	# Debug: log every 60 frames when pressing move keys
	_debug_move_counter += 1
	if velocity.length() > 0 and _debug_move_counter % 60 == 0:
		print("[RT_CONTROLLER] Movement debug:")
		print("  - velocity: %s" % velocity)
		print("  - battle_scene: %s" % (battle_scene != null))
		if battle_scene:
			var player = battle_scene.get_player_unit()
			print("  - player unit: %s" % (player != null))
			if player:
				print("  - is_player_controlled: %s" % player.is_player_controlled)
				print("  - player position: %s" % player.position)
				print("  - arena size: %s" % battle_scene.get_arena_pixel_size())

	# Apply locally for prediction with collision
	if battle_scene:
		var player = battle_scene.get_player_unit()
		if player and player.is_player_controlled:
			# Set local velocity for animation
			player.set_local_velocity(velocity)

			if velocity.length() > 0:
				var new_pos = player.position + velocity * delta
				# Check collision with other units
				new_pos = _check_local_collision(player, new_pos)
				# Clamp to arena bounds
				new_pos = _clamp_to_arena(new_pos)
				player.position = new_pos

const COLLISION_RADIUS: float = 40.0  # Match server

func _check_local_collision(player_unit: Node2D, new_pos: Vector2) -> Vector2:
	"""Client-side collision prediction"""
	if not battle_scene:
		return new_pos

	var min_distance = COLLISION_RADIUS * 2

	for unit_id in battle_scene.units:
		var other = battle_scene.units[unit_id]
		if other == player_unit or other.unit_state == "dead":
			continue

		var dist = new_pos.distance_to(other.position)
		if dist < min_distance:
			# Push away from collision
			var push_dir = (new_pos - other.position).normalized()
			if push_dir.length() < 0.1:
				push_dir = Vector2(1, 0)
			new_pos = other.position + push_dir * min_distance

	return new_pos

func _clamp_to_arena(pos: Vector2) -> Vector2:
	"""Keep position within arena boundaries"""
	if not battle_scene:
		return pos

	var arena_size = battle_scene.get_arena_pixel_size()
	var margin = 60.0  # Keep units away from edges (matches server ARENA_EDGE_PADDING)

	pos.x = clamp(pos.x, margin, arena_size.x - margin)
	pos.y = clamp(pos.y, margin, arena_size.y - margin)
	return pos

func _process_action_input() -> void:
	"""Check for attack/defend inputs"""
	# Attack with spacebar or left click
	if Input.is_action_just_pressed("action"):
		_try_attack()

	# Defend with shift or dedicated key
	if Input.is_action_just_pressed("defend"):
		_try_defend()

func _handle_click_target(screen_pos: Vector2) -> void:
	"""Handle click to select target"""
	if not battle_scene:
		return

	# Convert screen position to world position
	var world_pos = battle_scene.camera.get_global_mouse_position() if battle_scene.camera else screen_pos

	# Find closest enemy unit
	var closest_enemy: Node2D = null
	var closest_dist: float = 100.0  # Click radius

	for unit_id in battle_scene.units:
		var unit = battle_scene.units[unit_id]
		if unit.team == "enemy" and unit.unit_state != "dead":
			var dist = world_pos.distance_to(unit.position)
			if dist < closest_dist:
				closest_dist = dist
				closest_enemy = unit
				current_target_id = unit_id

	if closest_enemy:
		_set_target(current_target_id)
		_try_attack()

func _set_target(target_id: String) -> void:
	"""Set current target and update indicators"""
	var old_target_id = current_target_id

	# Clear old target indicator (only if different)
	if old_target_id != target_id and not old_target_id.is_empty() and battle_scene:
		var old_target = battle_scene.get_unit(old_target_id)
		if old_target and old_target.has_method("set_targeted"):
			old_target.set_targeted(false)

	current_target_id = target_id

	# Show new target indicator
	if not current_target_id.is_empty() and battle_scene:
		var new_target = battle_scene.get_unit(current_target_id)
		if new_target and new_target.has_method("set_targeted"):
			new_target.set_targeted(true)
		if old_target_id != target_id:
			print("[RT_CONTROLLER] Target set: %s" % current_target_id)

func _try_attack() -> void:
	"""Attempt to attack current target"""
	if current_target_id.is_empty():
		# Auto-target closest enemy if none selected
		_auto_select_target()

	if current_target_id.is_empty():
		return

	# Send attack to server
	_send_attack_to_server(current_target_id)

func _try_defend() -> void:
	"""Attempt to activate defend mode"""
	_send_defend_to_server()

func _auto_select_target() -> void:
	"""Select closest enemy as target"""
	if not battle_scene:
		return

	var player = battle_scene.get_player_unit()
	if not player:
		return

	var closest_dist: float = 999999.0

	for unit_id in battle_scene.units:
		var unit = battle_scene.units[unit_id]
		if unit.team == "enemy" and unit.unit_state != "dead":
			var dist = player.position.distance_to(unit.position)
			if dist < closest_dist:
				closest_dist = dist
				current_target_id = unit_id

## ========== NETWORK - OUTGOING ==========

func _send_movement_to_server() -> void:
	"""Send current velocity to server via RPC"""
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if not server_conn:
		return

	# Send velocity to server via RPC
	server_conn.rt_player_move.rpc_id(1, last_velocity.x, last_velocity.y)

func _send_attack_to_server(target_id: String) -> void:
	"""Send attack command to server via RPC"""
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if not server_conn:
		return

	server_conn.rt_player_attack.rpc_id(1, target_id)
	print("[RT_CONTROLLER] Attack sent: target=%s" % target_id)

func _send_defend_to_server() -> void:
	"""Send defend command to server via RPC"""
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if not server_conn:
		return

	server_conn.rt_player_defend.rpc_id(1)
	print("[RT_CONTROLLER] Defend sent")

## ========== NETWORK - INCOMING ==========

func on_state_update(units_state: Array) -> void:
	"""Apply server state update"""
	if battle_scene:
		battle_scene.on_state_update(units_state)

func on_damage_event(attacker_id: String, target_id: String, damage: int, flank_type: String) -> void:
	"""Handle damage event from server"""
	if battle_scene:
		battle_scene.on_damage_event(attacker_id, target_id, damage, flank_type)

func on_unit_death(unit_id: String) -> void:
	"""Handle unit death from server"""
	if battle_scene:
		battle_scene.on_unit_death(unit_id)

	# Clear target if it died
	if unit_id == current_target_id:
		_set_target("")

func on_defend_event(unit_id: String) -> void:
	"""Handle defend event from server"""
	if battle_scene:
		battle_scene.on_defend_event(unit_id)
