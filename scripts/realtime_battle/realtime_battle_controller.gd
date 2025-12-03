class_name RealtimeBattleController
extends Node
## Realtime Battle Controller - Battle lifecycle and network coordination
## REFACTORED: Input handling extracted to BattleInputHandler
## PURPOSE: Manage battle state, network sync, and coordinate input/state systems

## ========== SIGNALS ==========
signal battle_ready
signal battle_ended(result: String, rewards: Dictionary)

## ========== IMPORTS ==========
const BattleInputHandler = preload("res://scripts/realtime_battle/battle_input_handler.gd")

## ========== CONSTANTS ==========
const INPUT_SEND_RATE: float = 0.05  # 20 times per second
const ATTACK_COOLDOWN: float = 0.8  # Must match server's total attack duration
const ATTACK_FREEZE_TIME: float = 0.4  # Time player can't move during attack wind-up
const DODGE_ROLL_COOLDOWN: float = 1.0  # Must match server

## ========== REFERENCES ==========
var battle_scene: RealtimeBattleScene
var network_service: Node  # RealtimeCombatNetworkService
var input_handler: BattleInputHandler  # Handles all input processing

## ========== STATE ==========
var in_battle: bool = false
var battle_id: int = -1
var input_timer: float = 0.0
var movement_speed: float = 300.0  # Base walk speed (same as server)

## Attack/dodge cooldowns (read by input_handler)
var attack_cooldown_timer: float = 0.0  # Prevents spamming attacks to server
var attack_freeze_timer: float = 0.0  # Prevents movement during attack
var dodge_roll_cooldown_timer: float = 0.0

## ========== LIFECYCLE ==========

func _ready():
	set_process(false)  # Disabled until battle starts
	input_handler = BattleInputHandler.new()
	input_handler.initialize(self)

func initialize(scene: RealtimeBattleScene, net_service: Node) -> void:
	"""Set up controller with scene and network references"""
	battle_scene = scene
	network_service = net_service

	# Connect to scene signals
	if battle_scene:
		if not battle_scene.battle_ended.is_connected(_on_battle_ended):
			battle_scene.battle_ended.connect(_on_battle_ended)

	print("[RT_CONTROLLER] Initialized")

var _process_log_counter: int = 0

func _process(delta: float):
	_process_log_counter += 1
	if _process_log_counter == 1:
		print("[RT_CONTROLLER] _process FIRST CALL: in_battle=%s" % in_battle)

	if not in_battle:
		return

	# Update attack cooldown and freeze timer
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if attack_freeze_timer > 0:
		attack_freeze_timer -= delta
	if dodge_roll_cooldown_timer > 0:
		dodge_roll_cooldown_timer -= delta

	# Process input via handler
	var input_result = input_handler.process_input(delta)
	var velocity = input_result.velocity

	# Apply local prediction with collision
	_apply_local_movement(velocity, delta)

	# Send input to server at fixed rate
	input_timer += delta
	if input_timer >= INPUT_SEND_RATE:
		input_timer = 0.0
		_send_movement_to_server(velocity)

func _input(event: InputEvent):
	"""Handle high-priority input events (before GUI)"""
	if not in_battle:
		return

	# Delegate dodge roll to input handler (just-pressed events)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SHIFT:
			input_handler.try_dodge_roll(self)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("defend"):
		input_handler.try_dodge_roll(self)
		get_viewport().set_input_as_handled()
		return

func _unhandled_input(event: InputEvent):
	"""Handle lower-priority input events (after GUI)"""
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

	# Mouse click for targeting (delegate to handler)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			input_handler.handle_click_target(self, event.position)
			get_viewport().set_input_as_handled()
			return

	# Handle key inputs (delegate to handler)
	if event is InputEventKey and event.pressed and not event.echo:
		# T or Tab for cycling targets
		if event.keycode == KEY_T or event.keycode == KEY_TAB:
			var direction = -1 if event.shift_pressed else 1
			input_handler.cycle_target(self, direction)
			get_viewport().set_input_as_handled()
			return

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

## ========== LOCAL MOVEMENT (CLIENT-SIDE PREDICTION) ==========

var _debug_move_counter: int = 0

func _apply_local_movement(velocity: Vector2, delta: float) -> void:
	"""Apply velocity locally for client-side prediction"""
	if not battle_scene:
		return

	var player = battle_scene.get_player_unit()
	if not player or not player.is_player_controlled:
		return

	# Set local velocity for animation
	player.set_local_velocity(velocity)

	# Debug logging
	_debug_move_counter += 1
	if velocity.length() > 0 and _debug_move_counter % 60 == 0:
		print("[RT_CONTROLLER] Movement: velocity=%s, pos=%s" % [velocity, player.position])

	# Apply movement with collision
	if velocity.length() > 0:
		var new_pos = player.position + velocity * delta
		# Unit collision DISABLED - will be used as spell later
		# new_pos = _check_unit_collision(player, new_pos)
		new_pos = _clamp_to_arena(new_pos)
		player.position = new_pos

## ========== UNIT COLLISION ==========
const COLLISION_RADIUS: float = 40.0  # Unit collision radius

func _check_unit_collision(player_unit: RealtimeBattleUnit, new_pos: Vector2) -> Vector2:
	"""Check collision with other units - block when moving closer, allow moving away"""
	if not battle_scene:
		return new_pos

	var min_distance = COLLISION_RADIUS * 2
	var old_pos = player_unit.position

	for unit_id in battle_scene.units:
		var other = battle_scene.units[unit_id]
		if other == player_unit or other.unit_state == "dead":
			continue

		var dist_to_new = new_pos.distance_to(other.position)
		var dist_to_old = old_pos.distance_to(other.position)

		# ALWAYS allow moving AWAY from the unit (dist increasing)
		if dist_to_new >= dist_to_old:
			continue

		# Only block if we'd end up too close AND we're moving closer
		if dist_to_new < min_distance:
			# Sliding collision - allow movement parallel to obstacle
			var to_other = (other.position - old_pos).normalized()
			var move_dir = (new_pos - old_pos).normalized()
			var perp = Vector2(-to_other.y, to_other.x)
			var slide_amount = move_dir.dot(perp)
			var slide_velocity = perp * slide_amount * (new_pos - old_pos).length()
			new_pos = old_pos + slide_velocity

			# If still too close, push out
			var final_dist = new_pos.distance_to(other.position)
			if final_dist < min_distance:
				var push_dir = (old_pos - other.position).normalized()
				if push_dir.length() < 0.1:
					push_dir = Vector2.UP  # Fallback
				new_pos = other.position + push_dir * min_distance

	return new_pos

func _clamp_to_arena(pos: Vector2) -> Vector2:
	"""Keep position within arena boundaries"""
	if not battle_scene:
		return pos

	var arena_size = battle_scene.get_arena_pixel_size()
	var margin = 128.0  # Keep units away from edges (matches server MAP_EDGE_PADDING)

	pos.x = clamp(pos.x, margin, arena_size.x - margin)
	pos.y = clamp(pos.y, margin, arena_size.y - margin)
	return pos

## ========== PUBLIC API FOR SPELL TARGETING (FUTURE) ==========

func get_targets_in_range() -> Array:
	"""Get list of enemy unit IDs within spell range (for spell UI)"""
	# Delegate to input handler for future spell targeting UI
	if input_handler:
		input_handler.cycle_target(self, 0)  # Updates targetable_enemies
		return input_handler.targetable_enemies
	return []

func has_target_in_range() -> bool:
	"""Check if current target is within spell range (for spell UI)"""
	return input_handler and input_handler.has_target()

func get_current_target() -> String:
	"""Get current target ID (for spell UI)"""
	return input_handler.get_current_target() if input_handler else ""

## ========== NETWORK - OUTGOING ==========

func _send_movement_to_server(velocity: Vector2) -> void:
	"""Send current velocity to server via RPC"""
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if not server_conn:
		return

	# Send velocity to server via RPC
	server_conn.rt_player_move.rpc_id(1, velocity.x, velocity.y)

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
	if input_handler and unit_id == input_handler.get_current_target():
		input_handler.set_target(self, "")

func on_dodge_roll_event(unit_id: String, direction: Vector2) -> void:
	"""Handle dodge roll event from server"""
	if battle_scene:
		battle_scene.on_dodge_roll_event(unit_id, direction)

func on_projectile_spawn(proj_data: Dictionary) -> void:
	"""Handle projectile spawn from server"""
	if battle_scene:
		battle_scene.on_projectile_spawn(proj_data)

func on_projectile_hit(projectile_id: String, target_id: String, hit_position: Vector2) -> void:
	"""Handle projectile hit from server"""
	if battle_scene:
		battle_scene.on_projectile_hit(projectile_id, target_id, hit_position)

func on_projectile_miss(projectile_id: String, final_position: Vector2) -> void:
	"""Handle projectile miss from server"""
	if battle_scene:
		battle_scene.on_projectile_miss(projectile_id, final_position)