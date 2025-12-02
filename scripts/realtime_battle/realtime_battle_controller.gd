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

## ========== ATTACK COOLDOWN ==========
const ATTACK_COOLDOWN: float = 0.8  # Must match server's total attack duration
const ATTACK_FREEZE_TIME: float = 0.4  # Time player can't move during attack wind-up
var attack_cooldown_timer: float = 0.0  # Prevents spamming attacks to server
var attack_freeze_timer: float = 0.0  # Prevents movement during attack

## ========== TAB TARGETING ==========
const SPELL_TARGET_RANGE: float = 350.0  # Max range for spell targeting
var targetable_enemies: Array = []  # Array of unit_ids in range
var target_index: int = -1  # Current index in targetable_enemies

## ========== LIFECYCLE ==========

func _ready():
	set_process(false)  # Disabled until battle starts

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

	# Handle input
	_process_movement_input(delta)
	_process_action_input()

	# Send input to server at fixed rate
	input_timer += delta
	if input_timer >= INPUT_SEND_RATE:
		input_timer = 0.0
		_send_movement_to_server()

func _input(event: InputEvent):
	"""Use _input instead of _unhandled_input to receive events before GUI elements"""
	if not in_battle:
		return

	# Handle key inputs for combat actions (check these first)
	if event is InputEventKey and event.pressed and not event.echo:
		# Space for attack
		if event.keycode == KEY_SPACE:
			print("[RT_CONTROLLER] SPACE pressed! Attacking...")
			_try_attack()
			get_viewport().set_input_as_handled()
			return

		# Shift for dodge roll
		if event.keycode == KEY_SHIFT:
			print("[RT_CONTROLLER] SHIFT pressed! Dodge rolling...")
			_try_dodge_roll()
			get_viewport().set_input_as_handled()
			return

	# Handle Action Map inputs (if not handled by keycode above)
	if event.is_action_pressed("defend"):
		print("[RT_CONTROLLER] Defend Action pressed! Dodge rolling...")
		_try_dodge_roll()
		get_viewport().set_input_as_handled()
		return

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

	# Handle key inputs for combat actions
	if event is InputEventKey and event.pressed and not event.echo:
		# T or Tab for cycling targets
		if event.keycode == KEY_T or event.keycode == KEY_TAB:
			if event.shift_pressed:
				_cycle_target(-1)  # Shift+T/Tab = previous target
			else:
				_cycle_target(1)   # T/Tab = next target
			get_viewport().set_input_as_handled()
			return

		# Space or action key for attack
		if event.keycode == KEY_SPACE or event.is_action_pressed("action"):
			print("[RT_CONTROLLER] SPACE/ACTION key pressed via _unhandled_input!")
			_try_attack()
			get_viewport().set_input_as_handled()
			return

		# Shift for dodge roll
		if event.keycode == KEY_SHIFT or event.is_action_pressed("defend"):
			print("[RT_CONTROLLER] SHIFT/DEFEND key pressed via _unhandled_input - dodge roll!")
			_try_dodge_roll()
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

## ========== INPUT HANDLING ==========

var _debug_move_counter: int = 0

func _process_movement_input(delta: float) -> void:
	"""Read WASD input and calculate velocity"""
	# Freeze movement during attack animation
	if attack_freeze_timer > 0:
		last_velocity = Vector2.ZERO
		# Also freeze local animation
		if battle_scene:
			var player = battle_scene.get_player_unit()
			if player and player.is_player_controlled:
				player.set_local_velocity(Vector2.ZERO)
		return

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
				# Unit collision DISABLED - will be used as spell later
				# new_pos = _check_unit_collision(player, new_pos)
				# Clamp to arena bounds
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
	var margin = 60.0  # Keep units away from edges (matches server ARENA_EDGE_PADDING)

	pos.x = clamp(pos.x, margin, arena_size.x - margin)
	pos.y = clamp(pos.y, margin, arena_size.y - margin)
	return pos

func _process_action_input() -> void:
	"""Check for attack/defend inputs"""
	# Attack with spacebar (held) - auto-attacks at cooldown pace
	if Input.is_action_pressed("action") or Input.is_key_pressed(KEY_SPACE):
		_try_attack()

	# Dodge roll with shift or dedicated key
	if Input.is_action_just_pressed("defend"):
		_try_dodge_roll()

	# Tab to cycle through targets in range (handled in _unhandled_input)

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
	"""Attempt to attack current target - validates locally before sending to server"""
	# Check attack cooldown - prevents spamming the server
	if attack_cooldown_timer > 0:
		return

	if current_target_id.is_empty():
		# Auto-target closest enemy if none selected
		_auto_select_target()

	if current_target_id.is_empty():
		# No valid target found - don't spam server
		return

	# Validate target exists and is alive before sending
	if not battle_scene:
		return

	var target = battle_scene.get_unit(current_target_id)
	if not target or target.unit_state == "dead":
		# Target invalid or dead - clear it and don't send
		current_target_id = ""
		return

	# Check if in attack range (basic melee range check)
	var player = battle_scene.get_player_unit()
	if not player:
		return

	var distance = player.position.distance_to(target.position)
	const ATTACK_RANGE: float = 120.0  # Melee attack range
	if distance > ATTACK_RANGE:
		# Too far - don't send attack, let player move closer
		return

	# Valid target in range - send attack to server and start cooldown
	attack_cooldown_timer = ATTACK_COOLDOWN
	attack_freeze_timer = ATTACK_FREEZE_TIME  # Freeze movement during attack
	_send_attack_to_server(current_target_id)

## ========== DODGE ROLL ==========
const DODGE_ROLL_COOLDOWN: float = 1.0  # Must match server
var dodge_roll_cooldown_timer: float = 0.0

func _try_dodge_roll() -> void:
	"""Attempt to perform a dodge roll"""
	print("[RT_CONTROLLER] Attempting Dodge Roll... Cooldown: %.2f" % dodge_roll_cooldown_timer)
	
	# Check cooldown locally to prevent spamming server
	if dodge_roll_cooldown_timer > 0:
		return

	# Get roll direction from current movement, or backward if stationary
	var direction = last_velocity.normalized()
	if direction.length() < 0.1:
		# Roll backward based on player facing
		var player = battle_scene.get_player_unit() if battle_scene else null
		if player:
			var facing = player.get("facing") if player.has_method("get") else "down"
			match facing:
				"up": direction = Vector2.DOWN
				"down": direction = Vector2.UP
				"left": direction = Vector2.RIGHT
				"right": direction = Vector2.LEFT
				_: direction = Vector2.DOWN
		else:
			direction = Vector2.DOWN

	# Start local cooldown
	dodge_roll_cooldown_timer = DODGE_ROLL_COOLDOWN

	# Send to server
	_send_dodge_roll_to_server(direction)

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


## ========== TAB TARGETING SYSTEM ==========

func _update_targetable_enemies() -> void:
	"""Update list of enemies within spell range"""
	targetable_enemies.clear()

	if not battle_scene:
		return

	var player = battle_scene.get_player_unit()
	if not player:
		return

	# Build list of enemies within range, sorted by distance
	var enemies_with_dist: Array = []

	for unit_id in battle_scene.units:
		var unit = battle_scene.units[unit_id]
		if unit.team == "enemy" and unit.unit_state != "dead":
			var dist = player.position.distance_to(unit.position)
			if dist <= SPELL_TARGET_RANGE:
				enemies_with_dist.append({"id": unit_id, "dist": dist})

	# Sort by distance
	enemies_with_dist.sort_custom(func(a, b): return a.dist < b.dist)

	# Extract just the IDs
	for enemy in enemies_with_dist:
		targetable_enemies.append(enemy.id)


func _cycle_target(direction: int) -> void:
	"""Cycle through targetable enemies. direction: 1 for next, -1 for previous"""
	_update_targetable_enemies()

	if targetable_enemies.is_empty():
		print("[RT_CONTROLLER] No targets in range")
		return

	# Find current target's index in the list
	if current_target_id in targetable_enemies:
		target_index = targetable_enemies.find(current_target_id)
	else:
		target_index = -1

	# Move to next/previous
	target_index += direction

	# Wrap around
	if target_index >= targetable_enemies.size():
		target_index = 0
	elif target_index < 0:
		target_index = targetable_enemies.size() - 1

	# Set new target
	var new_target_id = targetable_enemies[target_index]
	_set_target(new_target_id)

	print("[RT_CONTROLLER] Tab target: %s (%d/%d)" % [
		new_target_id,
		target_index + 1,
		targetable_enemies.size()
	])


func get_targets_in_range() -> Array:
	"""Get list of enemy unit IDs within spell range"""
	_update_targetable_enemies()
	return targetable_enemies


func has_target_in_range() -> bool:
	"""Check if current target is within spell range"""
	if current_target_id.is_empty():
		return false

	if not battle_scene:
		return false

	var player = battle_scene.get_player_unit()
	var target = battle_scene.get_unit(current_target_id)

	if not player or not target:
		return false

	return player.position.distance_to(target.position) <= SPELL_TARGET_RANGE

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

func _send_dodge_roll_to_server(direction: Vector2) -> void:
	"""Send dodge roll command to server via RPC"""
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if not server_conn:
		return

	server_conn.rt_player_dodge_roll.rpc_id(1, direction.x, direction.y)
	print("[RT_CONTROLLER] Dodge roll sent: direction=%s" % direction)

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

func on_dodge_roll_event(unit_id: String, direction: Vector2) -> void:
	"""Handle dodge roll event from server"""
	if battle_scene:
		battle_scene.on_dodge_roll_event(unit_id, direction)