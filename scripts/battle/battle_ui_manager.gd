class_name BattleUIManager
extends Node
## Battle UI Manager - Handles panels, buttons, HP bars, target selection
## Extracted from battle_window.gd for modularity

# Signals
signal action_button_pressed(action: String)
signal target_selected(target_index: int)
signal target_confirmed(target_index: int)

# UI Node references (set by battle_window_v2)
var enemy_sprites: Array = []
var enemy_names: Array = []
var enemy_hp_bars: Array = []
var enemy_hp_labels: Array = []
var enemy_mp_bars: Array = []
var enemy_mp_labels: Array = []
var enemy_energy_bars: Array = []
var enemy_energy_labels: Array = []
var enemy_panels: Array = []

var ally_sprites: Array = []
var ally_names: Array = []
var ally_hp_bars: Array = []
var ally_hp_labels: Array = []
var ally_mp_bars: Array = []
var ally_mp_labels: Array = []
var ally_energy_bars: Array = []
var ally_energy_labels: Array = []
var ally_panels: Array = []

var action_buttons: Array = []
var attack_button: Button
var defend_button: Button
var skills_button: Button
var items_button: Button

var turn_info: Label
var target_cursor: Panel

# Button selection state
var selected_button_index: int = 0

# Target selection state
var selected_target_index: int = -1
var is_selecting_target: bool = false

# Squad data references (from combat controller)
var enemy_squad: Array = []
var ally_squad: Array = []

# Combat controller reference
var combat_controller = null

## ========== INITIALIZATION ==========

func initialize_ui_references(refs: Dictionary):
	"""Set all UI node references from parent scene"""
	enemy_sprites = refs.get("enemy_sprites", [])
	enemy_names = refs.get("enemy_names", [])
	enemy_hp_bars = refs.get("enemy_hp_bars", [])
	enemy_hp_labels = refs.get("enemy_hp_labels", [])
	enemy_mp_bars = refs.get("enemy_mp_bars", [])
	enemy_mp_labels = refs.get("enemy_mp_labels", [])
	enemy_energy_bars = refs.get("enemy_energy_bars", [])
	enemy_energy_labels = refs.get("enemy_energy_labels", [])
	enemy_panels = refs.get("enemy_panels", [])

	ally_sprites = refs.get("ally_sprites", [])
	ally_names = refs.get("ally_names", [])
	ally_hp_bars = refs.get("ally_hp_bars", [])
	ally_hp_labels = refs.get("ally_hp_labels", [])
	ally_mp_bars = refs.get("ally_mp_bars", [])
	ally_mp_labels = refs.get("ally_mp_labels", [])
	ally_energy_bars = refs.get("ally_energy_bars", [])
	ally_energy_labels = refs.get("ally_energy_labels", [])
	ally_panels = refs.get("ally_panels", [])

	action_buttons = refs.get("action_buttons", [])
	attack_button = refs.get("attack_button")
	defend_button = refs.get("defend_button")
	skills_button = refs.get("skills_button")
	items_button = refs.get("items_button")

	turn_info = refs.get("turn_info")
	target_cursor = refs.get("target_cursor")

func set_squad_references(enemies: Array, allies: Array):
	"""Set squad data references"""
	enemy_squad = enemies
	ally_squad = allies

## ========== ENEMY UI UPDATES ==========

func update_all_enemies_ui():
	"""Update all enemy UI displays"""
	# Update active enemies
	for i in range(min(6, enemy_squad.size())):
		update_enemy_ui(i)
		# Show the panel for active enemies
		if i < enemy_panels.size() and enemy_panels[i]:
			enemy_panels[i].visible = true

	# Hide unused enemy panels and their bars
	for i in range(enemy_squad.size(), min(6, enemy_panels.size())):
		if enemy_panels[i]:
			enemy_panels[i].visible = false
		# Hide HP bars
		if i < enemy_hp_bars.size() and enemy_hp_bars[i]:
			enemy_hp_bars[i].visible = false
		if i < enemy_hp_labels.size() and enemy_hp_labels[i]:
			enemy_hp_labels[i].visible = false
		# Hide MP bars
		if i < enemy_mp_bars.size() and enemy_mp_bars[i]:
			enemy_mp_bars[i].visible = false
		if i < enemy_mp_labels.size() and enemy_mp_labels[i]:
			enemy_mp_labels[i].visible = false
		# Hide Energy bars
		if i < enemy_energy_bars.size() and enemy_energy_bars[i]:
			enemy_energy_bars[i].visible = false
		if i < enemy_energy_labels.size() and enemy_energy_labels[i]:
			enemy_energy_labels[i].visible = false

func update_enemy_ui(index: int):
	"""Update specific enemy UI"""
	if index >= enemy_squad.size():
		return

	var enemy = enemy_squad[index]

	# Name
	if index < enemy_names.size() and enemy_names[index]:
		enemy_names[index].text = enemy.get("character_name", "Enemy")

	# HP Bar
	var max_hp = enemy.get("max_hp", 100)
	var current_hp = enemy.get("hp", max_hp)
	if index < enemy_hp_bars.size() and enemy_hp_bars[index]:
		print("   [UI] Enemy %d HP bar update: %d/%d" % [index, current_hp, max_hp])
		enemy_hp_bars[index].max_value = max_hp
		enemy_hp_bars[index].value = current_hp
		enemy_hp_bars[index].queue_redraw()  # Force visual refresh
	if index < enemy_hp_labels.size() and enemy_hp_labels[index]:
		enemy_hp_labels[index].text = "HP: %d / %d" % [current_hp, max_hp]

	# MP Bar
	var max_mp = enemy.get("max_mp", 50)
	var current_mp = enemy.get("mp", max_mp)
	if index < enemy_mp_bars.size() and enemy_mp_bars[index]:
		enemy_mp_bars[index].max_value = max_mp
		enemy_mp_bars[index].value = current_mp
	if index < enemy_mp_labels.size() and enemy_mp_labels[index]:
		enemy_mp_labels[index].text = "MP: %d / %d" % [current_mp, max_mp]

	# Energy Bar
	var max_energy = enemy.get("max_energy", 100)
	var current_energy = enemy.get("energy", max_energy)
	if index < enemy_energy_bars.size() and enemy_energy_bars[index]:
		enemy_energy_bars[index].max_value = max_energy
		enemy_energy_bars[index].value = current_energy
	if index < enemy_energy_labels.size() and enemy_energy_labels[index]:
		enemy_energy_labels[index].text = "Energy: %d / %d" % [current_energy, max_energy]

	# Load sprite
	if index < enemy_sprites.size() and enemy_sprites[index]:
		BattleDataLoader.load_character_sprite(enemy, enemy_sprites[index])

## ========== ALLY UI UPDATES ==========

func update_all_allies_ui():
	"""Update all ally UI displays"""
	for i in range(min(6, ally_squad.size())):
		update_ally_ui(i)

func update_ally_ui(index: int):
	"""Update specific ally UI"""
	if index >= ally_squad.size():
		return

	var ally = ally_squad[index]

	# Name
	if index < ally_names.size() and ally_names[index]:
		ally_names[index].text = ally.get("character_name", "Ally")

	# HP Bar
	var max_hp = ally.get("max_hp", 100)
	if not max_hp and ally.has("derived_stats"):
		max_hp = ally.derived_stats.get("max_hp", 100)
	var current_hp = ally.get("hp", max_hp)

	if index < ally_hp_bars.size() and ally_hp_bars[index]:
		print("   [UI] Ally %d HP bar update: %d/%d" % [index, current_hp, max_hp])
		ally_hp_bars[index].max_value = max_hp
		ally_hp_bars[index].value = current_hp
		ally_hp_bars[index].queue_redraw()  # Force visual refresh
	if index < ally_hp_labels.size() and ally_hp_labels[index]:
		ally_hp_labels[index].text = "HP: %d / %d" % [current_hp, max_hp]

	# MP Bar
	var max_mp = ally.get("max_mp", 50)
	if not max_mp and ally.has("derived_stats"):
		max_mp = ally.derived_stats.get("max_mp", 50)
	var current_mp = ally.get("mp", max_mp)

	if index < ally_mp_bars.size() and ally_mp_bars[index]:
		ally_mp_bars[index].max_value = max_mp
		ally_mp_bars[index].value = current_mp
	if index < ally_mp_labels.size() and ally_mp_labels[index]:
		ally_mp_labels[index].text = "MP: %d / %d" % [current_mp, max_mp]

	# Energy Bar
	var max_energy = ally.get("max_energy", 100)
	if not max_energy and ally.has("derived_stats"):
		max_energy = ally.derived_stats.get("max_ep", 100)
	var current_energy = ally.get("energy", max_energy)

	if index < ally_energy_bars.size() and ally_energy_bars[index]:
		ally_energy_bars[index].max_value = max_energy
		ally_energy_bars[index].value = current_energy
	if index < ally_energy_labels.size() and ally_energy_labels[index]:
		ally_energy_labels[index].text = "Energy: %d / %d" % [current_energy, max_energy]

	# Load sprite
	if index < ally_sprites.size() and ally_sprites[index]:
		BattleDataLoader.load_character_sprite(ally, ally_sprites[index])

## ========== BUTTON SELECTION ==========

func update_button_selection():
	"""Update visual feedback for selected button"""
	for i in range(action_buttons.size()):
		if action_buttons[i]:
			if i == selected_button_index:
				action_buttons[i].grab_focus()
				action_buttons[i].modulate = Color(1.5, 1.5, 0.5)  # Yellow highlight
			else:
				action_buttons[i].release_focus()
				action_buttons[i].modulate = Color(1, 1, 1)

func enable_action_buttons():
	"""Enable all action buttons for player selection"""
	if attack_button:
		attack_button.disabled = false
	if defend_button:
		defend_button.disabled = false
	if skills_button:
		skills_button.disabled = false
	if items_button:
		items_button.disabled = false

	selected_button_index = 0
	update_button_selection()

func disable_action_buttons():
	"""Disable all action buttons during enemy turns"""
	if attack_button:
		attack_button.disabled = true
	if defend_button:
		defend_button.disabled = true
	if skills_button:
		skills_button.disabled = true
	if items_button:
		items_button.disabled = true

	# Clear focus
	for button in action_buttons:
		if button:
			button.release_focus()

func navigate_button_selection(direction: int):
	"""Navigate between action buttons (A/D keys)"""
	selected_button_index += direction

	# Wrap around
	if selected_button_index < 0:
		selected_button_index = action_buttons.size() - 1
	elif selected_button_index >= action_buttons.size():
		selected_button_index = 0

	update_button_selection()

## ========== TARGET SELECTION ==========

func start_target_selection():
	"""Enter target selection mode"""
	print("🎯 start_target_selection() called")
	is_selecting_target = true

	# Update combat controller battle state
	if combat_controller:
		combat_controller.enter_target_selection()
	else:
		print("⚠️ WARNING: combat_controller is null!")

	# Find first alive enemy
	print("   Searching for alive enemies in squad of size: %d" % enemy_squad.size())
	for i in range(enemy_squad.size()):
		if enemy_squad[i].get("hp", 0) > 0:
			selected_target_index = i
			print("   Found alive enemy at index: %d" % i)
			break

	print("   selected_target_index = %d" % selected_target_index)

	if selected_target_index >= 0:
		show_target_cursor(selected_target_index)
		update_turn_info("Select target (WASD to move, ENTER to confirm, ESC to cancel)")
	else:
		print("⚠️ ERROR: No alive enemies found!")

func navigate_target_selection(direction: int):
	"""Navigate between enemy targets linearly (legacy method)"""
	navigate_target_direction("down" if direction > 0 else "up")

func navigate_target_direction(direction: String):
	"""Navigate between enemy targets using directional input (W/A/S/D)
	Enemy layout: Front row (0,1,2) | Back row (3,4,5)
	- up/down: Move within column (row 0→1→2)
	- left: Move to front row (same row position)
	- right: Move to back row (same row position)
	"""
	if not is_selecting_target:
		return

	# Find all alive enemies
	var alive_enemies: Array = []
	for i in range(enemy_squad.size()):
		if enemy_squad[i].get("hp", 0) > 0:
			alive_enemies.append(i)

	if alive_enemies.is_empty():
		return

	# If no target selected, start at first alive enemy
	if selected_target_index < 0 or not alive_enemies.has(selected_target_index):
		selected_target_index = alive_enemies[0]
		show_target_cursor(selected_target_index)
		var enemy_name = enemy_squad[selected_target_index].get("character_name", "Enemy %d" % (selected_target_index + 1))
		update_turn_info("Target: %s (W/A/S/D to change, ENTER to confirm)" % enemy_name)
		return

	# Current position: front row (0-2) or back row (3-5)
	var current_row = selected_target_index % 3  # 0=top, 1=middle, 2=bottom
	var current_column = 0 if selected_target_index < 3 else 1  # 0=front, 1=back

	var new_index = selected_target_index

	match direction:
		"up":
			# Move up in same column
			new_index = (current_column * 3) + ((current_row - 1 + 3) % 3)
		"down":
			# Move down in same column
			new_index = (current_column * 3) + ((current_row + 1) % 3)
		"left":
			# Move to front row (column 0), same row
			new_index = current_row  # Front row: 0,1,2
		"right":
			# Move to back row (column 1), same row
			new_index = 3 + current_row  # Back row: 3,4,5

	# If target enemy is dead, find nearest alive enemy in that direction
	if not alive_enemies.has(new_index):
		var attempts = 6
		while attempts > 0 and not alive_enemies.has(new_index):
			match direction:
				"up", "down":
					# Keep moving in same direction
					if direction == "up":
						new_index = (current_column * 3) + ((new_index % 3 - 1 + 3) % 3)
					else:
						new_index = (current_column * 3) + ((new_index % 3 + 1) % 3)
				"left", "right":
					# If no alive in target row, try adjacent rows
					var target_column = 0 if direction == "left" else 1
					new_index = target_column * 3 + ((new_index % 3 + 1) % 3)
			attempts -= 1

		# If still no valid target found, stay on current target
		if not alive_enemies.has(new_index):
			new_index = selected_target_index

	# Update selected target
	selected_target_index = new_index
	show_target_cursor(selected_target_index)

	# Update UI feedback
	var enemy_name = enemy_squad[selected_target_index].get("character_name", "Enemy %d" % (selected_target_index + 1))
	var row_name = ["Top", "Middle", "Bottom"][selected_target_index % 3]
	var column_name = "Front" if selected_target_index < 3 else "Back"
	update_turn_info("Target: %s (%s row, %s) - W/A/S/D to change, ENTER to confirm" % [enemy_name, column_name, row_name])

	target_selected.emit(selected_target_index)

func confirm_target():
	"""Confirm selected target"""
	print("🎯 confirm_target() called - selected_target_index: %d" % selected_target_index)
	if selected_target_index >= 0:
		is_selecting_target = false
		hide_target_cursor()
		print("✅ Emitting target_confirmed signal for index: %d" % selected_target_index)
		target_confirmed.emit(selected_target_index)
	else:
		print("⚠️ Cannot confirm - no target selected")

func confirm_target_selection():
	"""Alias for confirm_target() for consistency"""
	confirm_target()

func cancel_target_selection():
	"""Cancel target selection"""
	is_selecting_target = false
	hide_target_cursor()
	selected_target_index = -1

	# Update combat controller battle state
	if combat_controller:
		combat_controller.cancel_target_selection()

	update_turn_info("Select your action")

## ========== TARGET CURSOR ==========

func show_target_cursor(target_index: int):
	"""Show target cursor on enemy panel"""
	print("🎯 show_target_cursor() called - target_index: %d" % target_index)

	if not target_cursor:
		print("⚠️ ERROR: target_cursor is null!")
		return

	if target_index >= enemy_panels.size():
		print("⚠️ ERROR: target_index %d >= enemy_panels.size() %d" % [target_index, enemy_panels.size()])
		return

	var target_panel = enemy_panels[target_index]
	if not target_panel:
		print("⚠️ ERROR: enemy_panels[%d] is null!" % target_index)
		return

	# Safety check: ensure target_panel is actually a Control node
	if not target_panel is Control:
		print("⚠ ERROR: target_panel is not a Control node, type: ", target_panel.get_class())
		return

	print("✓ Setting cursor on panel %d at position %s" % [target_index, target_panel.global_position])

	# Get sprite node
	var sprite_node = target_panel.get("sprite_node")
	if sprite_node and sprite_node is TextureRect:
		var sprite_rect = sprite_node.get_global_rect()
		target_cursor.global_position = sprite_rect.position
		target_cursor.size = sprite_rect.size
		target_cursor.visible = true
		update_cursor_borders()
		print("✓ Cursor shown on sprite at %s" % sprite_rect.position)
	else:
		# Fallback to panel
		target_cursor.global_position = target_panel.global_position
		target_cursor.size = target_panel.size
		target_cursor.visible = true
		update_cursor_borders()
		print("✓ Cursor shown on panel at %s" % target_panel.global_position)

func hide_target_cursor():
	"""Hide target cursor"""
	if target_cursor:
		target_cursor.visible = false

func update_cursor_borders():
	"""Update the four border ColorRects to match cursor size"""
	if not target_cursor:
		return

	var cursor_width = target_cursor.size.x
	var cursor_height = target_cursor.size.y
	var border_thickness = 4.0

	var top_border = target_cursor.get_node_or_null("TopBorder")
	if top_border:
		top_border.offset_right = cursor_width
		top_border.offset_bottom = border_thickness

	var bottom_border = target_cursor.get_node_or_null("BottomBorder")
	if bottom_border:
		bottom_border.offset_top = cursor_height - border_thickness
		bottom_border.offset_right = cursor_width
		bottom_border.offset_bottom = cursor_height

	var left_border = target_cursor.get_node_or_null("LeftBorder")
	if left_border:
		left_border.offset_right = border_thickness
		left_border.offset_bottom = cursor_height

	var right_border = target_cursor.get_node_or_null("RightBorder")
	if right_border:
		right_border.offset_left = cursor_width - border_thickness
		right_border.offset_right = cursor_width
		right_border.offset_bottom = cursor_height

## ========== DISPLAY UPDATES ==========

func update_turn_info(text: String):
	"""Update turn info label"""
	if turn_info:
		turn_info.text = text

func update_selection_phase_display(timer: float, action_confirmed: bool):
	"""Update UI with selection phase countdown"""
	var time_remaining = max(0.0, timer)
	if action_confirmed:
		update_turn_info("Action confirmed! Starting round...")
	else:
		update_turn_info("Choose your action: %.1f seconds remaining" % time_remaining)

## ========== GETTERS ==========

func get_enemy_sprites() -> Array:
	"""Get array of enemy sprite nodes"""
	return enemy_sprites

func get_ally_sprites() -> Array:
	"""Get array of ally sprite nodes"""
	return ally_sprites

func get_enemy_panels() -> Array:
	"""Get array of enemy panel nodes"""
	return enemy_panels

func get_ally_panels() -> Array:
	"""Get array of ally panel nodes"""
	return ally_panels

func get_enemy_hp_bars() -> Array:
	"""Get array of enemy HP bar nodes"""
	return enemy_hp_bars

func get_ally_hp_bars() -> Array:
	"""Get array of ally HP bar nodes"""
	return ally_hp_bars
