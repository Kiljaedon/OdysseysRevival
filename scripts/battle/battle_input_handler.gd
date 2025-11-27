class_name BattleInputHandler
extends Node
## Battle Input Handler - Keyboard and mouse input for battle
## Extracted from battle_window_v2.gd for modularity

# Signals for input events
signal attack_requested
signal defend_requested
signal skills_requested
signal items_requested
signal target_navigation(direction: String)
signal target_confirmed
signal target_cancelled
signal continue_pressed
signal button_navigation(delta: int)  # -1 = prev, +1 = next
signal button_activated(index: int)

# References (set by battle_window)
var combat_controller = null
var ui_manager = null
var action_buttons: Array = []
var result_popup: Control = null

# State
var selected_button_index: int = 0


func initialize(p_combat_controller, p_ui_manager, p_action_buttons: Array, p_result_popup: Control = null):
	"""Initialize with required references"""
	combat_controller = p_combat_controller
	ui_manager = p_ui_manager
	action_buttons = p_action_buttons
	result_popup = p_result_popup
	selected_button_index = 0
	update_button_selection()


func _input(event: InputEvent):
	"""Handle keyboard input for battle"""
	if not event is InputEventKey or not event.pressed:
		return

	# BLOCK ESCAPE KEY - Don't allow exiting battle mid-fight
	if event.keycode == KEY_ESCAPE:
		var battle_state = combat_controller.get_battle_state() if combat_controller else -1
		if battle_state == 1:  # TARGET_SELECTION - allow cancel
			target_cancelled.emit()
		# Block Escape during all other battle phases
		get_viewport().set_input_as_handled()
		return

	# Allow SPACE to close victory/defeat popup
	if event.keycode == KEY_SPACE:
		if result_popup and result_popup.visible:
			get_viewport().set_input_as_handled()
			continue_pressed.emit()
			return

	# Get battle state from combat controller
	var battle_state = combat_controller.get_battle_state() if combat_controller else -1

	# SELECTION_PHASE: Navigate action buttons (Attack/Defend/Skills/Items)
	if battle_state == 0:  # SELECTION_PHASE state
		match event.keycode:
			KEY_W, KEY_UP, KEY_A, KEY_LEFT:
				selected_button_index = (selected_button_index - 1 + action_buttons.size()) % action_buttons.size()
				update_button_selection()
				get_viewport().set_input_as_handled()
			KEY_S, KEY_DOWN, KEY_D, KEY_RIGHT:
				selected_button_index = (selected_button_index + 1) % action_buttons.size()
				update_button_selection()
				get_viewport().set_input_as_handled()
			KEY_SPACE, KEY_ENTER:
				if selected_button_index < action_buttons.size() and action_buttons[selected_button_index]:
					if not action_buttons[selected_button_index].disabled:
						_activate_button(selected_button_index)
						get_viewport().set_input_as_handled()
			KEY_1:
				if action_buttons.size() > 0 and action_buttons[0] and not action_buttons[0].disabled:
					attack_requested.emit()
					get_viewport().set_input_as_handled()
			KEY_2:
				if action_buttons.size() > 1 and action_buttons[1] and not action_buttons[1].disabled:
					defend_requested.emit()
					get_viewport().set_input_as_handled()
			KEY_3:
				if action_buttons.size() > 2 and action_buttons[2] and not action_buttons[2].disabled:
					skills_requested.emit()
					get_viewport().set_input_as_handled()
			KEY_4:
				if action_buttons.size() > 3 and action_buttons[3] and not action_buttons[3].disabled:
					items_requested.emit()
					get_viewport().set_input_as_handled()

	# TARGET_SELECTION: Navigate enemy targets
	elif battle_state == 1:  # TARGET_SELECTION state
		match event.keycode:
			KEY_W, KEY_UP:
				target_navigation.emit("up")
				get_viewport().set_input_as_handled()
			KEY_S, KEY_DOWN:
				target_navigation.emit("down")
				get_viewport().set_input_as_handled()
			KEY_A, KEY_LEFT:
				target_navigation.emit("left")
				get_viewport().set_input_as_handled()
			KEY_D, KEY_RIGHT:
				target_navigation.emit("right")
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				target_confirmed.emit()
				get_viewport().set_input_as_handled()
		return  # IMPORTANT: Prevent other input processing


func _activate_button(index: int):
	"""Activate button at index by emitting appropriate signal"""
	match index:
		0: attack_requested.emit()
		1: defend_requested.emit()
		2: skills_requested.emit()
		3: items_requested.emit()


func update_button_selection():
	"""Update visual feedback for selected action button"""
	for i in range(action_buttons.size()):
		if action_buttons[i]:
			if i == selected_button_index:
				action_buttons[i].grab_focus()
				# Yellow highlight for selected button
				action_buttons[i].modulate = Color(1.5, 1.5, 0.5)
			else:
				action_buttons[i].release_focus()
				# Normal color
				action_buttons[i].modulate = Color(1, 1, 1)


func handle_enemy_panel_click(event: InputEvent, enemy_index: int):
	"""Handle mouse clicks on enemy panels during target selection"""
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	# Only process during TARGET_SELECTION state
	var battle_state = combat_controller.get_battle_state() if combat_controller else -1
	if battle_state != 1:  # 1 = TARGET_SELECTION
		return

	# Check if enemy is alive
	var enemy_squad = combat_controller.get_enemy_squad() if combat_controller else []
	if enemy_index >= enemy_squad.size():
		return
	if enemy_squad[enemy_index].get("hp", 0) <= 0:
		return

	# Select and auto-confirm target via ui_manager
	if ui_manager:
		ui_manager.selected_target_index = enemy_index
		ui_manager.show_target_cursor(enemy_index)
		ui_manager.confirm_target_selection()
