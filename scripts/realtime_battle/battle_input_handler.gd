class_name BattleInputHandler
extends RefCounted
## Battle Input Handler - Combat Input Processing with Buffering
## EXTRACTED FROM: realtime_battle_controller.gd (lines 207-540)
## PURPOSE: Handle all combat input (movement, attack, dodge, targeting)
## DEPENDENCIES: CombatInputBuffer
##
## This class manages all player input during battle, including:
## - Movement input (WASD)
## - Attack input (Space/Click)
## - Dodge roll input (Shift)
## - Targeting (Tab/T, mouse click)
## - Input buffering for responsive feel

## ========== IMPORTS ==========
const CombatInputBuffer = preload("res://source/server/managers/combat/combat_input_buffer.gd")

## ========== CONSTANTS ==========
const ATTACK_RANGE: float = 120.0  # Melee attack range
const SPELL_TARGET_RANGE: float = 350.0  # Max range for spell targeting

## ========== STATE ==========
var controller_ref: WeakRef  # Reference to parent controller
var input_buffer: CombatInputBuffer = CombatInputBuffer.new()

## Cached values
var last_velocity: Vector2 = Vector2.ZERO
var current_target_id: String = ""
var targetable_enemies: Array = []
var target_index: int = -1

## ========== INITIALIZATION ==========

func initialize(controller: Object) -> void:
	"""Initialize with reference to parent controller"""
	controller_ref = weakref(controller)
	print("[BattleInputHandler] Initialized with input buffering")

## ========== INPUT PROCESSING (MAIN LOOP) ==========

func process_input(delta: float) -> Dictionary:
	"""
	Process all input and return movement data.
	Called every frame from controller._process()

	Returns: {velocity: Vector2, any_input: bool}
	"""
	var controller = controller_ref.get_ref()
	if not controller or not controller.in_battle:
		return {"velocity": Vector2.ZERO, "any_input": false}

	# Process movement input
	var velocity = _read_movement_input(controller)
	last_velocity = velocity

	# Process action input (attack, dodge)
	_process_action_input(controller)

	# Process buffered inputs
	_process_buffer(controller)

	return {
		"velocity": velocity,
		"any_input": velocity.length() > 0 or Input.is_anything_pressed()
	}

## ========== MOVEMENT INPUT ==========

func _read_movement_input(controller: Object) -> Vector2:
	"""Read WASD input and calculate velocity"""
	# Check if movement is frozen (during attack)
	if controller.attack_freeze_timer > 0:
		return Vector2.ZERO

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
		velocity = velocity.normalized() * controller.movement_speed

	return velocity

## ========== ACTION INPUT ==========

func _process_action_input(controller: Object) -> void:
	"""Check for attack/dodge inputs (continuous polling)"""
	# Attack with spacebar (held) - auto-attacks at cooldown pace
	if Input.is_action_pressed("action") or Input.is_key_pressed(KEY_SPACE):
		try_attack(controller)

	# Dodge roll - handled in _input() for just_pressed

## ========== ATTACK INPUT ==========

func try_attack(controller: Object) -> void:
	"""
	Attempt to attack current target.
	Buffers input if on cooldown within buffer window.
	"""
	# Check attack cooldown
	if controller.attack_cooldown_timer <= 0:
		# Ready to attack now
		_execute_attack(controller)
	elif controller.attack_cooldown_timer <= input_buffer.BUFFER_WINDOW:
		# Within buffer window - queue the attack
		if input_buffer.buffer_action("attack", current_target_id):
			print("[InputBuffer] Attack buffered (%.3fs until ready)" % controller.attack_cooldown_timer)

func _execute_attack(controller: Object) -> void:
	"""Execute attack immediately (called by buffer or direct input)"""
	# Auto-target if no target selected
	if current_target_id.is_empty():
		_auto_select_target(controller)

	# Still no target? Can't attack
	if current_target_id.is_empty():
		return

	# Validate target exists and is alive
	if not controller.battle_scene:
		return

	var target = controller.battle_scene.get_unit(current_target_id)
	if not target or target.unit_state == "dead":
		current_target_id = ""
		return

	# Check range using player's actual attack range (role-specific)
	var player = controller.battle_scene.get_player_unit()
	if not player:
		return

	# Get player's attack range from their combat role (caster=280, melee=120, etc)
	var player_attack_range = player.get("attack_range")
	if player_attack_range == null:
		player_attack_range = ATTACK_RANGE  # Fallback to default

	var distance = player.position.distance_to(target.position)
	if distance > player_attack_range:
		return  # Too far - let player move closer

	# Valid target in range - execute attack
	controller.attack_cooldown_timer = controller.ATTACK_COOLDOWN
	controller.attack_freeze_timer = controller.ATTACK_FREEZE_TIME
	_send_attack_to_server(controller, current_target_id)

## ========== DODGE ROLL INPUT ==========

func try_dodge_roll(controller: Object) -> void:
	"""
	Attempt to dodge roll.
	Buffers input if on cooldown within buffer window.
	"""
	print("[BattleInputHandler] Attempting dodge roll... Cooldown: %.2f" % controller.dodge_roll_cooldown_timer)

	# Check cooldown
	if controller.dodge_roll_cooldown_timer <= 0:
		# Ready to dodge now
		_execute_dodge_roll(controller)
	elif controller.dodge_roll_cooldown_timer <= input_buffer.BUFFER_WINDOW:
		# Within buffer window - queue the dodge
		var direction = last_velocity.normalized()
		if direction.length() < 0.1:
			direction = _get_fallback_dodge_direction(controller)

		if input_buffer.buffer_action("dodge_roll", direction):
			print("[InputBuffer] Dodge buffered (%.3fs until ready)" % controller.dodge_roll_cooldown_timer)

func _execute_dodge_roll(controller: Object) -> void:
	"""Execute dodge roll immediately (called by buffer or direct input)"""
	# Get roll direction from current movement, or backward if stationary
	var direction = last_velocity.normalized()
	if direction.length() < 0.1:
		direction = _get_fallback_dodge_direction(controller)

	# Start cooldown
	controller.dodge_roll_cooldown_timer = controller.DODGE_ROLL_COOLDOWN

	# Send to server
	_send_dodge_roll_to_server(controller, direction)

func _get_fallback_dodge_direction(controller: Object) -> Vector2:
	"""Get fallback dodge direction based on player facing"""
	var player = controller.battle_scene.get_player_unit() if controller.battle_scene else null
	if not player:
		return Vector2.DOWN

	var facing = player.get("facing") if player.has_method("get") else "down"
	match facing:
		"up": return Vector2.DOWN  # Roll backward
		"down": return Vector2.UP
		"left": return Vector2.RIGHT
		"right": return Vector2.LEFT
		_: return Vector2.DOWN

## ========== INPUT BUFFER PROCESSING ==========

func _process_buffer(controller: Object) -> void:
	"""Process buffered inputs and execute if ready"""
	var ready_states = {
		"attack_ready": controller.attack_cooldown_timer <= 0,
		"dodge_roll_ready": controller.dodge_roll_cooldown_timer <= 0
	}

	# Create executor wrapper
	var executor = BufferExecutor.new(self, controller)
	input_buffer.process_queue(ready_states, executor)

## Executor wrapper for input buffer
class BufferExecutor:
	var handler: BattleInputHandler
	var controller: Object

	func _init(h: BattleInputHandler, c: Object):
		handler = h
		controller = c

	func execute_attack(target_id: String) -> void:
		handler.current_target_id = target_id
		handler._execute_attack(controller)
		print("[InputBuffer] ✅ Buffered attack executed!")

	func execute_dodge_roll(direction: Vector2) -> void:
		handler._execute_dodge_roll(controller)
		print("[InputBuffer] ✅ Buffered dodge executed!")

## ========== TARGETING SYSTEM ==========

func cycle_target(controller: Object, direction: int) -> void:
	"""Cycle through targetable enemies. direction: 1 for next, -1 for previous"""
	_update_targetable_enemies(controller)

	if targetable_enemies.is_empty():
		print("[BattleInputHandler] No targets in range")
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
	set_target(controller, new_target_id)

	print("[BattleInputHandler] Tab target: %s (%d/%d)" % [
		new_target_id,
		target_index + 1,
		targetable_enemies.size()
	])

func _update_targetable_enemies(controller: Object) -> void:
	"""Update list of enemies within spell range"""
	targetable_enemies.clear()

	if not controller.battle_scene:
		return

	var player = controller.battle_scene.get_player_unit()
	if not player:
		return

	# Build list of enemies within range, sorted by distance
	var enemies_with_dist: Array = []

	for unit_id in controller.battle_scene.units:
		var unit = controller.battle_scene.units[unit_id]
		if unit.team == "enemy" and unit.unit_state != "dead":
			var dist = player.position.distance_to(unit.position)
			if dist <= SPELL_TARGET_RANGE:
				enemies_with_dist.append({"id": unit_id, "dist": dist})

	# Sort by distance
	enemies_with_dist.sort_custom(func(a, b): return a.dist < b.dist)

	# Extract just the IDs
	for enemy in enemies_with_dist:
		targetable_enemies.append(enemy.id)

func _auto_select_target(controller: Object) -> void:
	"""Select closest enemy as target"""
	if not controller.battle_scene:
		return

	var player = controller.battle_scene.get_player_unit()
	if not player:
		return

	var closest_dist: float = 999999.0

	for unit_id in controller.battle_scene.units:
		var unit = controller.battle_scene.units[unit_id]
		if unit.team == "enemy" and unit.unit_state != "dead":
			var dist = player.position.distance_to(unit.position)
			if dist < closest_dist:
				closest_dist = dist
				current_target_id = unit_id

func set_target(controller: Object, target_id: String) -> void:
	"""Set current target and update indicators"""
	var old_target_id = current_target_id

	# Clear old target indicator
	if old_target_id != target_id and not old_target_id.is_empty() and controller.battle_scene:
		var old_target = controller.battle_scene.get_unit(old_target_id)
		if old_target and old_target.has_method("set_targeted"):
			old_target.set_targeted(false)

	current_target_id = target_id

	# Show new target indicator
	if not current_target_id.is_empty() and controller.battle_scene:
		var new_target = controller.battle_scene.get_unit(current_target_id)
		if new_target and new_target.has_method("set_targeted"):
			new_target.set_targeted(true)
		if old_target_id != target_id:
			print("[BattleInputHandler] Target set: %s" % current_target_id)

func handle_click_target(controller: Object, screen_pos: Vector2) -> void:
	"""Handle click to select target"""
	if not controller.battle_scene:
		return

	# Convert screen position to world position
	var world_pos = controller.battle_scene.camera.get_global_mouse_position() if controller.battle_scene.camera else screen_pos

	# Find closest enemy unit
	var closest_enemy: Node2D = null
	var closest_dist: float = 100.0  # Click radius

	for unit_id in controller.battle_scene.units:
		var unit = controller.battle_scene.units[unit_id]
		if unit.team == "enemy" and unit.unit_state != "dead":
			var dist = world_pos.distance_to(unit.position)
			if dist < closest_dist:
				closest_dist = dist
				closest_enemy = unit
				current_target_id = unit_id

	if closest_enemy:
		set_target(controller, current_target_id)
		try_attack(controller)

## ========== NETWORK - OUTGOING ==========

func _send_attack_to_server(controller: Object, target_id: String) -> void:
	"""Send attack command to server via RPC"""
	var server_conn = controller.get_tree().root.get_node_or_null("ServerConnection")
	if not server_conn:
		return

	server_conn.rt_player_attack.rpc_id(1, target_id)
	print("[BattleInputHandler] Attack sent: target=%s" % target_id)

func _send_dodge_roll_to_server(controller: Object, direction: Vector2) -> void:
	"""Send dodge roll command to server via RPC"""
	var server_conn = controller.get_tree().root.get_node_or_null("ServerConnection")
	if not server_conn:
		return

	server_conn.rt_player_dodge_roll.rpc_id(1, direction.x, direction.y)
	print("[BattleInputHandler] Dodge roll sent: direction=%s" % direction)

## ========== INFO / DEBUG ==========

func get_buffer_info() -> Dictionary:
	"""Get input buffer state for UI/debugging"""
	return input_buffer.get_buffer_state()

func print_buffer_state() -> void:
	"""Print buffer state for debugging"""
	input_buffer.print_buffer_state()

func clear_buffer() -> void:
	"""Clear all buffered inputs (e.g., on death, battle end)"""
	input_buffer.clear()

func has_target() -> bool:
	"""Check if a target is selected"""
	return not current_target_id.is_empty()

func get_current_target() -> String:
	"""Get current target ID"""
	return current_target_id
